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
local todo_parser = require "core.todo_parser"

local dialog_manager = dialog_flow.create_dialog_flow()

-- Colors for monochrome display
local COLOR_PRIMARY = "#333333"    -- Darkest
local COLOR_SECONDARY = "#666666"  -- Middle
local COLOR_TERTIARY = "#BBBBBB"   -- Lightest

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
                logger.log_to_spreadsheet("Capacity", button.name)
                render_widget()
                morph:run_with_delay(1000, function()
                    logger.log_to_spreadsheet("Relative Capacity", results[#results].value)
                end)
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
                        logger.log_to_spreadsheet("Energy", results[#results].index)
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
                        logger.log_to_spreadsheet("Note", results[#results])
                    end
                }
            }
        },
        log_symptoms = {
            label = "fa:heart-pulse",
            dialogs = {
                main = {
                    type = "radio",
                    title = "Log Symptom",
                    get_options = function()
                        local parsed_symptoms = markdown_parser.get_list_items(DATA_PREFIX.."Symptoms.md")
                        local options = util.map(parsed_symptoms, function(symptom) return symptom.text end)
                        table.insert(options, OTHER_TEXT)
                        return options
                    end,
                    handle_result = function(results, dialogs)
                        if results[1].value == OTHER_TEXT then
                            return dialogs.custom_input
                        end
                        return dialogs.severity
                    end
                },

                custom_input = {
                    type = "edit",
                    title = "Custom Symptom",
                    prompt = "Enter symptom name:",
                    default_text = "",
                    handle_result = function(results, dialogs)
                        return dialogs.severity
                    end
                },

                severity = {
                    type = "radio",
                    title = "Symptom Severity",
                    get_options = function()
                        return {
                            "1 - Minimal", "2 - Mild", "3 - Mild-Moderate", "4 - Moderate", "5 - Moderate-High",
                            "6 - High", "7 - High-Severe", "8 - Severe", "9 - Very Severe", "10 - Extreme"
                        }
                    end,
                    handle_result = function(results)
                        if #results == 2 then
                            logger.log_to_spreadsheet("Symptom", results[1].value, results[2].index)
                        elseif #results == 3 then
                            logger.log_to_spreadsheet("Symptom", results[2], results[3].index)
                        end
                    end
                }
            }
        },

        log_activity = {
            label = "fa:running",
            dialogs = {
                main = {
                    type = "radio",
                    title = "Log Activity",
                    get_options = function()
                        local options = util.map(prefs.activity_items, function(i) return get_modified_item_text(ACTIVITY, i) end)
                        table.insert(options, OTHER_TEXT)
                        local metas = util.map(prefs.activity_items, function(i) return i.meta end)
                        table.insert(metas, {})
                        return options, metas
                    end,
                    handle_result = function(results, dialogs)
                        if results[1].value == OTHER_TEXT then
                            return dialogs.custom_input
                        end
                        if results[1].meta.specifiers.Options then
                            return dialogs.options
                        end
                        logger.log_to_spreadsheet(ACTIVITY, results[1].meta.text)
                    end
                },

                custom_input = {
                    type = "edit",
                    title = "Custom Activity",
                    prompt = "Enter activity name:",
                    default_text = "",
                    handle_result = function(results, dialogs)
                        logger.log_to_spreadsheet(ACTIVITY, results[#results])
                    end
                },

                options = {
                    type = "radio",
                    title = "Choose Option",
                    get_options = function(results)
                        return results[1].meta.specifiers.Options
                    end,
                    handle_result = function(results, dialogs)
                        logger.log_to_spreadsheet(ACTIVITY, results[1].meta.text, results[2].value)
                    end
                }
            }
        },

        log_intervention = {
            label = "fa:pills",
            dialogs = {
                main = {
                    type = "radio",
                    title = "Log Intervention",
                    get_options = function()
                        local options = util.map(prefs.intervention_items, function(i) return get_modified_item_text(INTERVENTION, i) end)
                        table.insert(options, OTHER_TEXT)
                        local metas = util.map(prefs.intervention_items, function(i) return i.meta end)
                        table.insert(metas, {})
                        return options, metas
                    end,
                    handle_result = function(results, dialogs)
                        if results[1].value == OTHER_TEXT then
                            return dialogs.custom_input
                        end
                        if results[1].meta.specifiers.Options then
                            return dialogs.options
                        end
                        if results[1].meta.is_link then
                            return dialogs.todo
                        end
                        logger.log_to_spreadsheet(INTERVENTION, results[1].meta.text)
                    end
                },

                custom_input = {
                    type = "edit",
                    title = "Custom Intervention",
                    prompt = "Enter intervention name:",
                    default_text = "",
                    handle_result = function(results, dialogs)
                        logger.log_to_spreadsheet(INTERVENTION, results[#results])
                    end
                },

                options = {
                    type = "radio",
                    title = "Choose Option",
                    get_options = function(results)
                        return results[1].meta.specifiers.Options
                    end,
                    handle_result = function(results, dialogs)
                        logger.log_to_spreadsheet(INTERVENTION, results[1].meta.text, results[2].value)
                    end
                },

                todo = {
                    type = "checkbox",
                    title = "Todos",
                    get_options = function(results)
                        local item_name = results[1].meta.text
                        local parsed_todos = markdown_parser.get_list_items(DATA_PREFIX..item_name..".md")
                        local completions = logger.log_count(INTERVENTION, item_name)
                        return todo_parser.parse_todo_list(parsed_todos, completions, get_current_capacity())
                    end,
                    handle_result = function(results, dialogs)
                        logger.log_to_spreadsheet(INTERVENTION, results[1].meta.text, string.format("%.0f%%", (#results[2].indices / #results[2].options) * 100))
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

------- SETUP ACTIVITIES/INTERVENTIONS

local REQUIRED_ITEM = "‼️"
local COMPLETED_ITEM = "✓"

function setup_loggables()
    prefs.activity_items = get_loggable_items("Activities")
    prefs.intervention_items = get_loggable_items("Interventions")
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
    local text = item.text
    if is_item_required(event, item) then
        text = REQUIRED_ITEM .. text
    end

    local last_logged = logger.last_logged(event, item.meta.text)
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
    local last_logged = logger.last_logged(event, item.meta.text)
    
    if util.contains(requiredParams, "daily") or time_utils.is_day_of_week(now, requiredParams) then
        return not time_utils.is_same_calendar_day(last_logged, now)
    end

    if util.contains(requiredParams, "weekly") then
        return not time_utils.is_same_week(last_logged, now)
    end

    return false
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
            {"spacer", 10},
            {"button", dialog_buttons.log_energy.label, {color = get_energy_button_color(), gravity="center_h"}},
            {"button", dialog_buttons.log_note.label, {color = COLOR_TERTIARY, gravity="anchor_prev"}},
            {"button", dialog_buttons.log_symptoms.label, {color = COLOR_TERTIARY, gravity="anchor_prev"}},
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

    ui_core.handle_button_long_click(element, capacity_buttons)
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