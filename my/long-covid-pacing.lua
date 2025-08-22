-- name = "Long Covid Pacing (Refactored)"
-- description = "Daily capacity level selection and plan display - using core module"
-- type = "widget"
-- author = "Paul Sztajer"
-- version = "2.0"
-- foldable = "true"

local prefs = require "prefs"
local core = require "long_covid_core"

-- Initialize preferences
if not prefs.selected_level then
    prefs.selected_level = 0  -- Default to no selection
end

if not prefs.last_selection_date then
    prefs.last_selection_date = ""
end

if not prefs.daily_logs then
    prefs.daily_logs = {}
end

if not prefs.daily_capacity_log then
    prefs.daily_capacity_log = {}
end

-- Cache for parsed data
local cached_plans = {}
local cached_criteria = nil
local cached_symptoms = nil
local cached_activities = nil
local cached_interventions = nil
local cached_required_activities = nil
local cached_required_interventions = nil
local current_dialog_type = nil

-- Global variables to store prefs data
local selected_level = 0
local last_selection_date = ""
local daily_capacity_log = {}
local daily_logs = {}

function load_prefs_data()
    selected_level = prefs.selected_level or 0
    last_selection_date = prefs.last_selection_date or ""
    daily_capacity_log = prefs.daily_capacity_log or {}
    daily_logs = prefs.daily_logs or {}
    
    -- Purge old daily logs on every load for performance
    local today = os.date("%Y-%m-%d")
    daily_logs = core.purge_old_daily_logs(daily_logs, today)
end

function save_prefs_data()
    prefs.selected_level = selected_level
    prefs.last_selection_date = last_selection_date
    prefs.daily_capacity_log = daily_capacity_log
    prefs.daily_logs = daily_logs
end

function on_resume()
    local success, error_msg = pcall(function()
        load_prefs_data()
        check_daily_reset()
        load_data()
        render_widget()
    end)
    
    if not success then
        ui:show_text("Error loading widget: " .. tostring(error_msg))
    end
end

function check_daily_reset()
    local changes = core.check_daily_reset(last_selection_date, selected_level, daily_capacity_log, daily_logs)
    
    if changes.selected_level ~= nil then
        selected_level = changes.selected_level
    end
    if changes.last_selection_date then
        last_selection_date = changes.last_selection_date
    end
    if changes.daily_logs then
        daily_logs = changes.daily_logs
    end
    
    -- Check if we have a stored selection for today
    if changes.selected_level == 0 then
        local today = os.date("%Y-%m-%d")
        if daily_capacity_log and daily_capacity_log[today] then
            selected_level = daily_capacity_log[today].capacity
        end
    end
    
    save_prefs_data()
end

function on_click(idx)
    if not my_gui then return end
    
    local element = my_gui.ui[idx]
    if not element then return end
    
    local elem_type = element[1]
    local elem_text = element[2]
    
    if elem_type == "button" then
        if elem_text:find("bed") then
            -- Capacity level 1 (Recovering)
            if selected_level == 0 or 1 <= selected_level then
                selected_level = 1
                daily_capacity_log = core.save_daily_choice(daily_capacity_log, 1)
                save_daily_choice_to_tasker(1)
                save_prefs_data()
                render_widget()
            else
                ui:show_toast("Can only downgrade capacity level")
            end
        elseif elem_text:find("walking") then
            -- Capacity level 2 (Maintaining)
            if selected_level == 0 or 2 <= selected_level then
                selected_level = 2
                daily_capacity_log = core.save_daily_choice(daily_capacity_log, 2)
                save_daily_choice_to_tasker(2)
                save_prefs_data()
                render_widget()
            else
                ui:show_toast("Can only downgrade capacity level")
            end
        elseif elem_text:find("rocket%-launch") then
            -- Capacity level 3 (Engaging)
            if selected_level == 0 or 3 <= selected_level then
                selected_level = 3
                daily_capacity_log = core.save_daily_choice(daily_capacity_log, 3)
                save_daily_choice_to_tasker(3)
                save_prefs_data()
                render_widget()
            else
                ui:show_toast("Can only downgrade capacity level")
            end
        elseif elem_text:find("rotate%-right") or elem_text:find("Reset") then
            -- Reset selection button
            selected_level = 0
            local today = os.date("%Y-%m-%d")
            if daily_capacity_log and daily_capacity_log[today] then
                daily_capacity_log[today] = nil
            end
            save_prefs_data()
            ui:show_toast("Selection reset")
            render_widget()
        elseif elem_text:find("sync") then
            sync_plan_files()
        elseif elem_text:find("heart%-pulse") then
            show_symptom_dialog()
        elseif elem_text:find("bolt%-lightning") then
            show_energy_dialog()
        elseif elem_text:find("running") then
            show_activity_dialog()
        elseif elem_text:find("pills") then
            show_intervention_dialog()
        elseif elem_text == "Back" then
            render_widget()
        end
    end
end

function load_data()
    if not cached_criteria then
        local content = files:read("decision_criteria.md")
        cached_criteria = core.parse_decision_criteria(content)
    end
    
    local today = core.get_current_day()
    if not cached_plans[today] then
        local content = files:read(today .. ".md")
        cached_plans[today] = core.parse_day_file(content)
    end
end

function save_daily_choice_to_tasker(level_idx)
    local timestamp = os.date("%Y-%m-%d %H:%M:%S")
    local level_name = core.levels[level_idx].name
    
    if tasker then
        tasker:run_task("LongCovid_LogEvent", {
            timestamp = timestamp,
            event_type = "Capacity",
            value = level_name
        })
        ui:show_toast("✓ Logged to spreadsheet")
    else
        ui:show_toast("Tasker not available")
    end
end

function render_widget()
    local today = core.get_current_day()
    local day_display = today:gsub("^%l", string.upper)
    
    ui:set_title("Long Covid Pacing - " .. day_display)
    
    local ui_elements = {}
    
    -- Add capacity level buttons
    for i, level in ipairs(core.levels) do
        local color
        local button_text
        local gravity = nil
        
        if i == selected_level then
            color = level.color
            button_text = "%%fa:" .. level.icon .. "%% " .. level.name
        elseif selected_level == 0 then
            color = level.color
            button_text = "%%fa:" .. level.icon .. "%% " .. level.name
        else
            color = "#888888"
            button_text = "fa:" .. level.icon
        end
        
        if i == 1 then
            gravity = "center_h"
        else
            gravity = "anchor_prev"
        end
        
        local button_props = {color = color}
        if gravity then
            button_props.gravity = gravity
        end
        
        table.insert(ui_elements, {"button", button_text, button_props})
        if i < #core.levels then
            table.insert(ui_elements, {"spacer", 1})
        end
    end
    
    table.insert(ui_elements, {"new_line", 1})
    
    -- Determine button colors
    local activity_color = "#dc3545" -- Default red
    local intervention_color = "#dc3545" -- Default red
    
    if cached_required_activities then
        activity_color = core.are_all_required_activities_completed(daily_logs, cached_required_activities) and "#28a745" or "#dc3545"
    end
    
    if cached_required_interventions then
        intervention_color = core.are_all_required_interventions_completed(daily_logs, cached_required_interventions) and "#007bff" or "#dc3545"
    end
    
    local energy_color = core.get_energy_button_color(daily_logs)
    
    -- Health tracking buttons
    table.insert(ui_elements, {"button", "fa:heart-pulse", {color = "#6c757d", gravity = "center_h"}})
    table.insert(ui_elements, {"button", "fa:bolt-lightning", {color = energy_color, gravity = "anchor_prev"}})
    table.insert(ui_elements, {"spacer", 3})
    table.insert(ui_elements, {"button", "fa:running", {color = activity_color, gravity = "anchor_prev"}})
    table.insert(ui_elements, {"button", "fa:pills", {color = intervention_color, gravity = "anchor_prev"}})

    ui:set_expandable(true)
    
    if ui:is_expanded() then
        table.insert(ui_elements, {"new_line", 2})
        
        if selected_level == 0 then
            table.insert(ui_elements, {"text", "<b>Select your capacity level:</b>", {size = 18}})
            table.insert(ui_elements, {"new_line", 1})
            table.insert(ui_elements, {"text", "%%fa:bed%% <b>Recovering</b> - Low energy, prioritize rest", {color = "#FF4444"}})
            table.insert(ui_elements, {"new_line", 1})
            table.insert(ui_elements, {"text", "%%fa:walking%% <b>Maintaining</b> - Moderate energy, standard routine", {color = "#FFAA00"}})
            table.insert(ui_elements, {"new_line", 1})
            table.insert(ui_elements, {"text", "%%fa:rocket-launch%% <b>Engaging</b> - High energy, can handle challenges", {color = "#44AA44"}})
            table.insert(ui_elements, {"new_line", 2})
            table.insert(ui_elements, {"button", "%%fa:sync%% Sync Files", {color = "#4CAF50", gravity = "center_h"}})
            table.insert(ui_elements, {"spacer", 2})
            table.insert(ui_elements, {"button", "%%fa:rotate-right%% Reset", {color = "#666666", gravity = "anchor_prev"}})
        else
            local success, error_msg = pcall(function()
                add_plan_details(ui_elements, today)
            end)
            
            if not success then
                table.insert(ui_elements, {"text", "<b>Selected:</b> " .. core.levels[selected_level].name, {size = 18}})
                table.insert(ui_elements, {"new_line", 1})
                table.insert(ui_elements, {"text", "%%fa:exclamation-triangle%% <b>Can't load plan data</b>", {color = "#ff6b6b"}})
                table.insert(ui_elements, {"new_line", 2})
                table.insert(ui_elements, {"button", "%%fa:sync%% Sync Files", {color = "#4CAF50", gravity = "center_h"}})
                table.insert(ui_elements, {"spacer", 2})
                table.insert(ui_elements, {"button", "%%fa:rotate-right%% Reset", {color = "#666666", gravity = "anchor_prev"}})
            end
        end
    end
    
    my_gui = gui(ui_elements)
    my_gui.render()
end

function add_plan_details(ui_elements, day)
    local plan = cached_plans[day]
    if not plan then
        table.insert(ui_elements, {"text", "No plan available for " .. day, {color = "#ff6b6b"}})
        return
    end
    
    local level_key = core.levels[selected_level].key
    local level_plan = plan[level_key]
    
    if not level_plan then
        table.insert(ui_elements, {"text", "No plan available for selected level", {color = "#ff6b6b"}})
        return
    end
    
    if level_plan.overview and #level_plan.overview > 0 then
        table.insert(ui_elements, {"text", "<b>Today's Overview:</b>", {size = 18}})
        table.insert(ui_elements, {"new_line", 1})
        for _, overview_line in ipairs(level_plan.overview) do
            local formatted_line = overview_line:gsub("%*%*([^%*]+)%*%*", "<b>%1</b>")
            table.insert(ui_elements, {"text", formatted_line, {size = 16}})
            table.insert(ui_elements, {"new_line", 1})
        end
        table.insert(ui_elements, {"new_line", 1})
    end
    
    for category, items in pairs(level_plan) do
        if category ~= "overview" and #items > 0 then
            table.insert(ui_elements, {"text", "<b>" .. category .. ":</b>", {size = 16}})
            table.insert(ui_elements, {"new_line", 1})
            for _, item in ipairs(items) do
                table.insert(ui_elements, {"text", "• " .. item})
                table.insert(ui_elements, {"new_line", 1})
            end
            table.insert(ui_elements, {"new_line", 1})
        end
    end
    
    table.insert(ui_elements, {"button", "%%fa:sync%% Sync Files", {color = "#4CAF50", gravity = "center_h"}})
    table.insert(ui_elements, {"spacer", 2})
    table.insert(ui_elements, {"button", "%%fa:rotate-right%% Reset", {color = "#666666", gravity = "anchor_prev"}})
end

function on_long_click(idx)
    if not my_gui then return end
    
    local element = my_gui.ui[idx]
    if not element then return end
    
    local elem_type = element[1]
    local elem_text = element[2]
    
    if elem_type == "button" then
        if elem_text:find("bed") then
            show_decision_criteria(1)
        elseif elem_text:find("walking") then
            show_decision_criteria(2)
        elseif elem_text:find("rocket%-launch") then
            show_decision_criteria(3)
        elseif elem_text:find("rotate%-right") or elem_text:find("Reset") then
            ui:show_toast("Reset button - tap to clear selection")
        elseif elem_text:find("sync") then
            ui:show_toast("Syncing plan files with Tasker...")
            sync_plan_files()
        end
    end
end

function sync_plan_files()
    if tasker then
        ui:show_toast("Loading plan data...")
        tasker:run_task("LongCovid_SendData")
    else
        ui:show_toast("Tasker not available")
    end
end

function on_tasker_result(success)
    if success then
        ui:show_toast("✓ Tasker task completed")
    else
        ui:show_toast("✗ Tasker task failed")
    end
end

function on_command(data)
    local parts = data:split(":")
    if #parts < 3 then
        return
    end
    
    local data_type = parts[1]
    local filename = parts[2]
    local content = table.concat(parts, ":", 3)
    
    if data_type == "plan_data" then
        files:write(filename, content)
        
        -- Clear cache to reload data
        cached_plans = {}
        cached_criteria = nil
        cached_symptoms = nil
        cached_activities = nil
        cached_interventions = nil
        cached_required_activities = nil
        cached_required_interventions = nil
        
        load_data()
        render_widget()
        
        ui:show_toast("✓ Plan data updated")
    end
end

function show_decision_criteria(level_idx)
    local level_key = core.levels[level_idx].key
    local criteria = cached_criteria[level_key]
    
    if not criteria or #criteria == 0 then
        ui:show_toast("No criteria available")
        return
    end
    
    local ui_elements = {}
    table.insert(ui_elements, {"text", "<b>" .. core.levels[level_idx].name .. " - Decision Criteria:</b>", {size = 18, color = core.levels[level_idx].color}})
    table.insert(ui_elements, {"new_line", 2})
    
    for _, criterion in ipairs(criteria) do
        table.insert(ui_elements, {"text", "• " .. criterion})
        table.insert(ui_elements, {"new_line", 1})
    end
    
    table.insert(ui_elements, {"new_line", 1})
    table.insert(ui_elements, {"button", "Back", {color = "#666666"}})
    
    my_gui = gui(ui_elements)
    my_gui.render()
end

function show_symptom_dialog()
    current_dialog_type = "symptom"
    if not cached_symptoms then
        local content = files:read("symptoms.md")
        cached_symptoms = core.parse_symptoms_file(content)
    end
    local formatted_symptoms = core.format_list_items(cached_symptoms, "symptom", daily_logs, {}, {})
    dialogs:show_list_dialog({
        title = "Log Symptom",
        lines = formatted_symptoms,
        search = true,
        zebra = true
    })
end

function show_activity_dialog()
    current_dialog_type = "activity"
    if not cached_activities then
        local content = files:read("activities.md")
        cached_activities = core.parse_activities_file(content)
    end
    if not cached_required_activities then
        local content = files:read("activities.md")
        cached_required_activities = core.parse_required_activities(content)
    end
    local formatted_activities = core.format_list_items(cached_activities, "activity", daily_logs, cached_required_activities, {})
    dialogs:show_list_dialog({
        title = "Log Activity",
        lines = formatted_activities,
        search = true,
        zebra = true
    })
end

function show_intervention_dialog()
    current_dialog_type = "intervention"
    if not cached_interventions then
        local content = files:read("interventions.md")
        cached_interventions = core.parse_interventions_file(content)
    end
    if not cached_required_interventions then
        local content = files:read("interventions.md")
        cached_required_interventions = core.parse_required_interventions(content)
    end
    local formatted_interventions = core.format_list_items(cached_interventions, "intervention", daily_logs, {}, cached_required_interventions)
    dialogs:show_list_dialog({
        title = "Log Intervention",
        lines = formatted_interventions,
        search = true,
        zebra = true
    })
end

function show_energy_dialog()
    current_dialog_type = "energy"
    local energy_levels = {"1 - Completely drained", "2 - Very low", "3 - Low", "4 - Below average", 
                           "5 - Average", "6 - Above average", "7 - Good", "8 - Very good", 
                           "9 - Excellent", "10 - Peak energy"}
    dialogs:show_radio_dialog("Log Energy Level", energy_levels, 0)
end

function log_symptom(symptom_name)
    local timestamp = os.date("%Y-%m-%d %H:%M:%S")
    
    core.log_item(daily_logs, "symptom", symptom_name)
    save_prefs_data()
    
    if tasker then
        tasker:run_task("LongCovid_LogEvent", {
            timestamp = timestamp,
            event_type = "Symptom",
            value = symptom_name
        })
        ui:show_toast("✓ Symptom logged: " .. symptom_name)
    else
        ui:show_toast("✓ Symptom logged: " .. symptom_name)
    end
    
    if current_dialog_type == "symptom" or current_dialog_type == "symptom_edit" then
        show_symptom_dialog()
    end
end

function log_activity(activity_name)
    local timestamp = os.date("%Y-%m-%d %H:%M:%S")
    
    core.log_item(daily_logs, "activity", activity_name)
    save_prefs_data()
    
    if tasker then
        tasker:run_task("LongCovid_LogEvent", {
            timestamp = timestamp,
            event_type = "Activity",
            value = activity_name
        })
        ui:show_toast("✓ Activity logged: " .. activity_name)
    else
        ui:show_toast("✓ Activity logged: " .. activity_name)
    end
    
    if current_dialog_type == "activity" or current_dialog_type == "activity_edit" then
        show_activity_dialog()
    end
    
    -- Re-render widget to update button colors
    render_widget()
end

function log_intervention(intervention_name)
    local timestamp = os.date("%Y-%m-%d %H:%M:%S")
    
    core.log_item(daily_logs, "intervention", intervention_name)
    save_prefs_data()
    
    if tasker then
        tasker:run_task("LongCovid_LogEvent", {
            timestamp = timestamp,
            event_type = "Intervention",
            value = intervention_name
        })
        ui:show_toast("✓ Intervention logged: " .. intervention_name)
    else
        ui:show_toast("✓ Intervention logged: " .. intervention_name)
    end
    
    if current_dialog_type == "intervention" or current_dialog_type == "intervention_edit" then
        show_intervention_dialog()
    end
    
    -- Re-render widget to update button colors
    render_widget()
end

function log_energy(energy_level)
    local timestamp = os.date("%Y-%m-%d %H:%M:%S")
    
    core.log_energy(daily_logs, energy_level)
    save_prefs_data()
    
    if tasker then
        tasker:run_task("LongCovid_LogEvent", {
            timestamp = timestamp,
            event_type = "Energy",
            value = tostring(energy_level)
        })
        ui:show_toast("✓ Energy level " .. energy_level .. " logged")
    else
        ui:show_toast("✓ Energy level " .. energy_level .. " logged")
    end
    
    render_widget()
end

function on_dialog_action(result)
    if result == -1 then
        if current_dialog_type == "symptom" or current_dialog_type == "activity" or current_dialog_type == "intervention" or current_dialog_type == "energy" then
            current_dialog_type = nil
        end
        return true
    end
    
    if type(result) == "number" then
        if current_dialog_type == "symptom" then
            local formatted_symptoms = core.format_list_items(cached_symptoms, "symptom", daily_logs, {}, {})
            local selected_formatted = formatted_symptoms[result]
            local selected_item = core.extract_item_name(selected_formatted)
            
            if selected_item == "Other..." then
                current_dialog_type = "symptom_edit"
                dialogs:show_edit_dialog("Custom Symptom", "Enter symptom name:", "")
                return true
            else
                log_symptom(selected_item)
                return true
            end
        elseif current_dialog_type == "activity" then
            local formatted_activities = core.format_list_items(cached_activities, "activity", daily_logs, cached_required_activities, {})
            local selected_formatted = formatted_activities[result]
            local selected_item = core.extract_item_name(selected_formatted)
            
            if selected_item == "Other..." then
                current_dialog_type = "activity_edit"
                dialogs:show_edit_dialog("Custom Activity", "Enter activity name:", "")
                return true
            else
                log_activity(selected_item)
                return true
            end
        elseif current_dialog_type == "intervention" then
            local formatted_interventions = core.format_list_items(cached_interventions, "intervention", daily_logs, {}, cached_required_interventions)
            local selected_formatted = formatted_interventions[result]
            local selected_item = core.extract_item_name(selected_formatted)
            
            if selected_item == "Other..." then
                current_dialog_type = "intervention_edit"
                dialogs:show_edit_dialog("Custom Intervention", "Enter intervention name:", "")
                return true
            else
                log_intervention(selected_item)
                return true
            end
        elseif current_dialog_type == "energy" then
            local energy_levels = {"1 - Completely drained", "2 - Very low", "3 - Low", "4 - Below average", 
                                   "5 - Average", "6 - Above average", "7 - Good", "8 - Very good", 
                                   "9 - Excellent", "10 - Peak energy"}
            local selected_text = energy_levels[result]
            if selected_text then
                local energy_level = tonumber(selected_text:match("^(%d+)"))
                if energy_level then
                    log_energy(energy_level)
                end
            end
            return true
        end
    elseif type(result) == "string" then
        if result ~= "" then
            if current_dialog_type == "symptom_edit" then
                current_dialog_type = "symptom"
                log_symptom(result)
            elseif current_dialog_type == "activity_edit" then
                current_dialog_type = "activity"
                log_activity(result)
            elseif current_dialog_type == "intervention_edit" then
                current_dialog_type = "intervention"
                log_intervention(result)
            end
        else
            if current_dialog_type == "symptom_edit" then
                current_dialog_type = "symptom"
                show_symptom_dialog()
            elseif current_dialog_type == "activity_edit" then
                current_dialog_type = "activity"
                show_activity_dialog()
            elseif current_dialog_type == "intervention_edit" then
                current_dialog_type = "intervention"
                show_intervention_dialog()
            end
        end
        return true
    end
end