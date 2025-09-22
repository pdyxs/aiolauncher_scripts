-- name = "Long Covid"
-- description = "Long Covid management widget"
-- type = "widget"
-- author = "Paul Sztajer"
-- version = "0.1"
-- icon = "shield-virus"

local prefs = require "prefs"
local ui_core = require "core.ui"
local logger = require "core.log-via-tasker"
local dialog_flow = require "core.dialog-flow"
local util = require "core.util"
local time_utils = require "core.time-utils"
local markdown_parser = require "core.markdown_parser"
local item_parser = require "core.item-parser"
local plan_parser = require "core.plan_parser"
local todo_parser = require "core.todo_parser"
local obsidian = require "core.obsidian"

local dialog_manager = dialog_flow.create_dialog_flow(function() render_widget() end)

-- Colors for monochrome display
local COLOR_PRIMARY = "#333333"    -- Darkest
local COLOR_SECONDARY = "#666666"  -- Middle
local COLOR_TERTIARY = "#BBBBBB"   -- Lightest

local OBSIDIAN_FILEPATH = "Long Covid/Data/"

------- COMMANDS

local COMMAND_DELIM = ":"
local DATA_PREFIX = "long-covid-data-"

local commands = {
    copy_data = function(parts)
        local filename = parts[2]
        local content = table.concat(parts, COMMAND_DELIM, 3)

        files:write(DATA_PREFIX .. filename, content)
    end,
    copy_finished = function()
        setup_loggables()
        render_widget()
    end
}

------- CAPACITY LOGGING

function handle_capacity_click(button)
    -- Don't allow setting capacity if one is already set today
    if get_current_capacity() then
        return
    end

    dialog_manager:start({
        main = {
            type = "radio",
            title = "Capacity compared to yesterday",
            get_options = function()
                return {
                    "25%", "50%", "75%", "90%", "100%", "110%", "125%", "150%", "200%"
                }
            end,
            handle_result = function(results)
                logger.log_events_to_spreadsheet({
                    {"Capacity", button.name},
                    {"Relative Capacity", results[#results].option}
                })
                render_widget()
            end
        }
    })
end

local capacity_buttons = {
    recovering = {
        label = "fa:bed",
        name = "Recovering",
        callback = handle_capacity_click,
        long_callback = function(button) reset_capacity() end
    },
    maintaining = {
        label = "fa:balance-scale",
        name = "Maintaining",
        callback = handle_capacity_click,
        long_callback = function(button) reset_capacity() end
    },
    engaging = {
        label = "fa:rocket-launch",
        name = "Engaging",
        callback = handle_capacity_click,
        long_callback = function(button) reset_capacity() end
    }
}

function reset_capacity()
    logger.store_log("Capacity", "reset")
    render_widget()
end

function get_current_capacity()
    local today = time_utils.get_current_timestamp()
    if time_utils.is_same_calendar_day(today, logger.last_logged("Capacity")) then
        local last = logger.last_value("Capacity")
        if last == "reset" then
            return nil
        end
        return last
    end
    return nil
end

------- OTHER LOGGING

local OTHER_TEXT = "Other..."
local ACTIVITY = "Activity"
local INTERVENTION = "Intervention"
local SYMPTOM = "Symptom"

function create_dialogs_for_items(name, get_items, override_log)
    local do_log = function(loggables, new_loggable)
        if override_log then
            return override_log(new_loggable)
        end
        logger.log_to_spreadsheet(
            util.concat_arrays({name}, loggables, {new_loggable})
        )
    end
    return {
        main = {
            type = "radio",
            title = "Log "..name,
            get_options = function()
                local items = get_items()
                local options = util.map(items, function(i) return get_modified_item_text(name, i) end)
                table.insert(options, OTHER_TEXT)
                local values = util.map(items, function(i) return i.value end)
                table.insert(values, OTHER_TEXT)
                local metas = util.map(items, function(i) return i.meta end)
                table.insert(metas, {})
                return options, values, metas
            end,
            handle_result = function(results, dialogs, loggables)
                local result = results[#results]
                if result.value == OTHER_TEXT then
                    return dialogs.custom_input
                end
                if result.meta.specifiers.Options then
                    return dialogs.options, result.value
                end
                if result.meta.is_link then
                    return dialogs.todo, result.value
                end
                return do_log(loggables, result.value)
            end
        },

        custom_input = {
            type = "edit",
            title = "Custom "..name,
            prompt = "Enter "..name:lower().." name:",
            default_text = "",
            handle_result = function(results, dialogs, loggables)
                return do_log(loggables, results[#results])
            end
        },

        options = {
            type = "radio",
            title = "Choose Option",
            get_options = function(results)
                return results[#results].meta.specifiers.Options
            end,
            handle_result = function(results, dialogs, loggables)
                return do_log(loggables, results[#results].option)
            end
        },

        todo = {
            type = "checkbox",
            title = "Todos",
            get_options = function(results)
                local item_name = results[#results].value
                local parsed_todos = markdown_parser.get_list_items(DATA_PREFIX..item_name..".md")
                local completions = logger.log_count(name, item_name)
                return todo_parser.parse_todo_list(parsed_todos, completions, get_current_capacity())
            end,
            handle_result = function(results, dialogs, loggables)
                local perc = string.format("%.0f%%", (#results[#results].indices / #results[#results].all_options) * 100)
                return do_log(loggables, perc)
            end
        }
    }
end

local dialog_buttons = util.map(
    {
        log_energy = {
            label = "fa:bolt",
            dialogs = {
                main = {
                    type = "radio",
                    title = "Log Energy Level",
                    get_options = function()
                        return {
                            "1 - Completely drained", "2 - Very low", "3 - Low", "4 - Below average", 
                            "5 - Average", "6 - Above average", "7 - Good", "8 - Very good", 
                            "9 - Excellent", "10 - Peak energy"
                        }
                    end,
                    handle_result = function(results)
                        logger.log_to_spreadsheet({"Energy", results[#results].index})
                        render_widget()
                    end
                }
            }
        },
        log_note = {
            label = "fa:note-sticky",
            dialogs = {
                main = {
                    type = "edit",
                    title = "Log note",
                    prompt = "Enter note:",
                    default_text = "",
                    handle_result = function(results)
                        logger.log_to_spreadsheet({"Note", results[#results]})
                    end
                }
            }
        },
        log_symptoms = {
            label = "fa:heart-pulse",
            long_callback = function() obsidian.open_file(OBSIDIAN_FILEPATH.."Symptoms.md") end,
            dialogs = create_dialogs_for_items(
                SYMPTOM, 
                function() return prefs.symptom_items end,
                function(loggable)
                    local dialog = {
                        type = "radio",
                        title = "Symptom Severity",
                        get_options = function(results, loggables)
                            local options = {
                                "1 - Minimal", "2 - Mild", "3 - Mild-Moderate", "4 - Moderate", "5 - Moderate-High",
                                "6 - High", "7 - High-Severe", "8 - Severe", "9 - Very Severe", "10 - Extreme"
                            }
                            if is_symptom_unresolved(loggables[1]) then
                                table.insert(options, 1, "0 - Resolved")
                            end
                            return options
                        end,
                        handle_result = function(results, dialogs, loggables)
                            local severity = results[#results].index
                            if is_symptom_unresolved(loggables[1]) then
                                severity = severity - 1
                            end
                            logger.log_to_spreadsheet(
                                util.concat_arrays({SYMPTOM}, loggables, {severity})
                            )
                            setup_symptoms()
                        end
                    }
                    return dialog, loggable
                end
            ),
        },

        log_activity = {
            label = "fa:running",
            long_callback = function() obsidian.open_file(OBSIDIAN_FILEPATH.."Activities.md") end,
            dialogs = create_dialogs_for_items(ACTIVITY, function() return prefs.activity_items end)
        },

        log_intervention = {
            label = "fa:pills",
            long_callback = function() obsidian.open_file(OBSIDIAN_FILEPATH.."Interventions.md") end,
            dialogs = create_dialogs_for_items(INTERVENTION, function() return prefs.intervention_items end),
        },

        plans = {
            label = "fa:calendar",
            long_callback = function() obsidian.open_file(OBSIDIAN_FILEPATH.."Plans.md") end,
            dialogs = {
                main = {
                    type="list",
                    title="Plans",
                    get_lines = function()
                        return prefs.plans.list
                    end,
                    handle_result = function()
                    end
                }
            }
        }
    }, 
    function(btn) 
        btn.callback = function(button) dialog_manager:start(button.dialogs) end
        return btn
    end
)

------- SETUP LISTS FOR DIALOGS

local REQUIRED_ITEM = "‼️"
local COMPLETED_ITEM = "✓"
local LINKED_ITEM = "♾️"
local OPTIONS = "⚟"

function setup_loggables()
    prefs.activity_items = get_loggable_items("Activities")
    prefs.intervention_items = get_loggable_items("Interventions")
    setup_symptoms()
    prefs.plans = get_plans_info()
end

function setup_symptoms()
    prefs.symptom_items = get_loggable_symptom_items()
end

function get_plans_info()
    local parsed_plans = markdown_parser.get_list_items(DATA_PREFIX.."Plans.md")
    local incomplete = util.filter(parsed_plans, function(plan)
        return not string.match(plan.text, "^✔")
    end)
    local any_overdue = false
    local list = util.map(incomplete, function(p)
        local item, overdue = plan_parser.parse_plan(p.text)
        if overdue then
            any_overdue = true
        end
        return item
    end)
    return { list = list, any_overdue = any_overdue }
end

function get_loggable_symptom_items()
    local items = get_loggable_items("Symptoms")

    local tracking_symptoms = get_tracking_symptoms()
    for _,symptom in pairs(tracking_symptoms) do
        local found = false
        -- try to find each tracking symptom
        for _,item in pairs(items) do
            if item.value == symptom then
                found = true
                item.meta.specifiers.Required = {"now"}
            end
        end

        --custom symptom
        if not found then
            table.insert(items, {value=symptom, meta={ specifiers={Required={"now"}} }})
        end
    end

    return items
end

function get_loggable_items(filename)
    local parsed = markdown_parser.get_list_items(DATA_PREFIX..filename..".md")
    return util.map(parsed, item_parser.parse_item)
end

function are_any_required(event, items)
    for _,item in ipairs(items) do
        if is_item_required(event, item) then
            return true
        end
    end
    return false
end

function get_modified_item_text(event, item)
    local text = item.value
    if is_item_required(event, item) then
        text = REQUIRED_ITEM .. text
    end

    if item.meta.is_link then
        text = text .. " " .. LINKED_ITEM
    end

    if item.meta.specifiers.Options then
        text = text .. " " .. OPTIONS
    end

    local last_logged = logger.last_logged(event, item.value)
    local now = time_utils.get_current_timestamp()
    if time_utils.is_same_calendar_day(last_logged, now) then
        text = text .. " " .. COMPLETED_ITEM
    end

    return text
end

function is_item_required(event, item)
    if not item.meta.specifiers.Required then
        return false
    end

    local requiredParams = util.map(item.meta.specifiers.Required, function(i) return i:lower() end)
    local now = time_utils.get_current_timestamp()
    local last_logged = logger.last_logged(event, item.value)

    if util.contains(requiredParams, "now") then
        return true
    end
    
    if util.contains(requiredParams, "daily") or time_utils.is_day_of_week(now, requiredParams) then
        return not time_utils.is_same_calendar_day(last_logged, now)
    end

    if util.contains(requiredParams, "weekly") then
        return not time_utils.is_same_week(last_logged, now)
    end

    return false
end

function get_tracking_symptoms()
    local tracking_symptoms = {}
    for value,data in pairs(prefs.logs["Symptom"].values) do
        if is_symptom_tracking(value) then
            table.insert(tracking_symptoms, value)
        end
    end
    return tracking_symptoms
end

function get_tracking_custom_symptoms(default_symptoms)
    local tracking_symptoms = {}
    for value,data in pairs(prefs.logs["Symptom"].values) do
        if not util.contains(default_symptoms, value) and is_symptom_tracking(value) then
            table.insert(tracking_symptoms, value)
        end
    end
    return tracking_symptoms
end

function is_symptom_tracking(value)
    if not is_symptom_unresolved(value) then
        return false
    end
    local data = prefs.logs["Symptom"].values[value]
    if not time_utils.is_today(data.last_logged) then
        return true
    end
end

function is_symptom_unresolved(value)
    local data = prefs.logs["Symptom"].values[value]
    if not data then
        return false
    end
    if data.last_detail ~= "0" then
        return true
    end
end

------- RENDERING HELPERS

function get_activity_button_color()
    if are_any_required(ACTIVITY, prefs.activity_items) then
        return COLOR_PRIMARY
    end
    return COLOR_TERTIARY
end

function get_interventions_button_color()
    if are_any_required(INTERVENTION, prefs.intervention_items) then
        return COLOR_PRIMARY
    end
    return COLOR_TERTIARY
end

function get_plans_button_color()
    if prefs.plans.any_overdue then
        return COLOR_PRIMARY
    end
    return COLOR_TERTIARY
end

function get_symptoms_color()
    if #get_tracking_symptoms() > 0 then
        return COLOR_PRIMARY
    end
    return COLOR_TERTIARY
end

function get_energy_button_color()
    local last_time = logger.last_logged("Energy")
    local current_time = time_utils.get_current_timestamp()

    if not time_utils.is_same_calendar_day(last_time, current_time) then
        -- Different calendar day - PRIMARY
        return COLOR_PRIMARY
    end

    local hours_since_last = time_utils.hours_between(last_time, current_time)

    if hours_since_last >= 4 then
        -- 4+ hours since last log - SECONDARY
        return COLOR_SECONDARY
    else
        -- Logged within 4 hours - TERTIARY
        return COLOR_TERTIARY
    end
end

function get_capacity_button_display(button)
    local current_capacity = get_current_capacity()

    -- Show name if no selection made OR this button is selected
    if not current_capacity or current_capacity == button.name then
        return "%%" .. button.label .. "%% " .. button.name
    else
        return button.label
    end
end

------- RENDERING

function render_widget()
    local current_capacity = get_current_capacity()

    if current_capacity then
        render_capacity_selected()
    else
        render_select_capacity()
    end
end

function render_select_capacity()
    -- Show all buttons when no capacity is set
    my_gui = gui{
        {"button", get_capacity_button_display(capacity_buttons.recovering), {color = COLOR_PRIMARY, gravity = "center_h"}},
        {"spacer", 1},
        {"button", get_capacity_button_display(capacity_buttons.maintaining), {color = COLOR_PRIMARY, gravity = "anchor_prev"}},
        {"spacer", 1},
        {"button", get_capacity_button_display(capacity_buttons.engaging), {color = COLOR_PRIMARY, gravity = "anchor_prev"}}
    }
    my_gui.render()
end

function render_capacity_selected()
    local current_capacity = get_current_capacity()

    -- Find and show only the selected capacity button
    local selected_button
    for _, button in pairs(capacity_buttons) do
        if button.name == current_capacity then
            selected_button = button
            break
        end
    end

    if selected_button then
        my_gui = gui{
            {"button", selected_button.label, {color = COLOR_TERTIARY}},
            {"button", dialog_buttons.log_energy.label, {color = get_energy_button_color()}},
            {"button", dialog_buttons.plans.label, {color = get_plans_button_color()}},
            {"spacer", 6},
            {"button", dialog_buttons.log_note.label, {color = COLOR_TERTIARY, gravity="center_h"}},
            {"button", dialog_buttons.log_symptoms.label, {color = get_symptoms_color(), gravity="anchor_prev"}},
            {"button", dialog_buttons.log_activity.label, {color = get_activity_button_color(), gravity="right"}},
            {"button", dialog_buttons.log_intervention.label, {color = get_interventions_button_color()}},
        }
        my_gui.render()
    end
end

------ AIO Functions

function on_resume()
    setup_loggables()
    tasker:run_task("LongCovid_CopyData", {})
    render_widget()
end

function on_click(idx)
    if not my_gui then return end

    local element = my_gui.ui[idx]
    if not element then return end

    ui_core.handle_button_click(element, util.tables_to_array(capacity_buttons, dialog_buttons))
end

function on_dialog_action(result)
    dialog_manager:handle_result(result)
end

function on_long_click(idx)
    if not my_gui then return end

    local element = my_gui.ui[idx]
    if not element then return end

    ui_core.handle_button_long_click(element, util.tables_to_array(capacity_buttons, dialog_buttons))
end

function on_command(data)
    local parts = data:split(COMMAND_DELIM)
    if #parts < 1 then
        return
    end

    if commands[parts[1]] ~= nil then
        commands[parts[1]](parts)
    end
end