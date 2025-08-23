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

-- Create managers
local dialog_manager = core.create_dialog_manager()

-- Check core module version and function availability
local core_version = core.VERSION or "unknown"
local has_dialog_flow_function = core.create_dialog_flow_manager ~= nil

prefs.debug_core_info = "Core version: " .. core_version .. 
                       " | Has dialog flow function: " .. tostring(has_dialog_flow_function) ..
                       " | parse_symptoms_file: " .. tostring(core.parse_symptoms_file ~= nil)

-- Create dialog flow manager with error handling
local dialog_flow_manager = nil
if has_dialog_flow_function then
    local success, result = pcall(function() return core.create_dialog_flow_manager() end)
    if success then
        dialog_flow_manager = result
        prefs.debug_flow_manager = "created successfully"
    else
        prefs.debug_flow_manager = "ERROR calling function: " .. tostring(result)
    end
else
    prefs.debug_flow_manager = "ERROR: Function does not exist - module cache issue"
end

local cache_manager = core.create_cache_manager()
local button_mapper = core.create_button_mapper()
local ui_generator = core.create_ui_generator()

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
    
    -- Initialize dialog flow manager
    if dialog_flow_manager then
        dialog_flow_manager:set_data_manager(dialog_manager)
        dialog_flow_manager:set_daily_logs(daily_logs)
        prefs.debug_init = "Dialog flow manager initialized successfully"
    else
        prefs.debug_init = "ERROR: dialog_flow_manager is nil - " .. (prefs.debug_flow_manager or "unknown error")
    end
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
        local action_type, level = button_mapper:identify_button_action(elem_text)
        
        if action_type == "capacity_level" then
            if button_mapper:can_select_level(selected_level, level) then
                selected_level = level
                daily_capacity_log = core.save_daily_choice(daily_capacity_log, level)
                save_daily_choice_to_tasker(level)
                save_prefs_data()
                render_widget()
            else
                ui:show_toast("Can only downgrade capacity level")
            end
        elseif action_type == "reset" then
            selected_level = 0
            local today = os.date("%Y-%m-%d")
            if daily_capacity_log and daily_capacity_log[today] then
                daily_capacity_log[today] = nil
            end
            save_prefs_data()
            ui:show_toast("Selection reset")
            render_widget()
        elseif action_type == "sync" then
            sync_plan_files()
        elseif action_type == "symptom_dialog" then
            show_symptom_dialog()
        elseif action_type == "energy_dialog" then
            show_energy_dialog()
        elseif action_type == "activity_dialog" then
            show_activity_dialog()
        elseif action_type == "intervention_dialog" then
            show_intervention_dialog()
        elseif action_type == "back" then
            render_widget()
        end
    end
end

function load_data()
    cache_manager:load_decision_criteria(function(filename) return files:read(filename) end)
    
    local today = core.get_current_day()
    cache_manager:load_day_plan(today, function(filename) return files:read(filename) end)
    
    -- Pre-load required activities and interventions for button colors
    cache_manager:load_activities(function(filename) return files:read(filename) end)
    cache_manager:load_interventions(function(filename) return files:read(filename) end)
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
    local capacity_buttons = ui_generator:create_capacity_buttons(selected_level)
    for _, element in ipairs(capacity_buttons) do
        table.insert(ui_elements, element)
    end
    
    -- Add health tracking buttons
    local required_activities = cache_manager:get_required_activities()
    local required_interventions = cache_manager:get_required_interventions()
    local health_buttons = ui_generator:create_health_tracking_buttons(daily_logs, required_activities, required_interventions)
    for _, element in ipairs(health_buttons) do
        table.insert(ui_elements, element)
    end

    ui:set_expandable(true)
    
    if ui:is_expanded() then
        if selected_level == 0 then
            local no_selection_content = ui_generator:create_no_selection_content()
            for _, element in ipairs(no_selection_content) do
                table.insert(ui_elements, element)
            end
        else
            local success, content = pcall(function()
                local day_plan = cache_manager:load_day_plan(today, function(filename) return files:read(filename) end)
                return ui_generator:create_plan_details(day_plan, selected_level)
            end)
            
            if not success then
                local error_content = ui_generator:create_error_content("Can't load plan data")
                for _, element in ipairs(error_content) do
                    table.insert(ui_elements, element)
                end
            else
                for _, element in ipairs(content) do
                    table.insert(ui_elements, element)
                end
            end
        end
    end
    
    my_gui = gui(ui_elements)
    my_gui.render()
end

function on_long_click(idx)
    if not my_gui then return end
    
    local element = my_gui.ui[idx]
    if not element then return end
    
    local elem_type = element[1]
    local elem_text = element[2]
    
    if elem_type == "button" then
        local action_type, level = button_mapper:identify_button_action(elem_text)
        
        if action_type == "capacity_level" then
            show_decision_criteria(level)
        elseif action_type == "reset" then
            ui:show_toast("Reset button - tap to clear selection")
        elseif action_type == "sync" then
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
        if cache_manager then
            cache_manager:clear_cache()
        end
        if dialog_manager then
            dialog_manager.cached_symptoms = nil
            dialog_manager.cached_activities = nil
            dialog_manager.cached_interventions = nil
            dialog_manager.cached_required_activities = nil
            dialog_manager.cached_required_interventions = nil
        end
        
        load_data()
        render_widget()
        
        ui:show_toast("✓ Plan data updated")
    end
end

function show_decision_criteria(level_idx)
    local all_criteria = cache_manager:load_decision_criteria(function(filename) return files:read(filename) end)
    local level_key = core.levels[level_idx].key
    local criteria = all_criteria[level_key]
    
    local ui_elements = ui_generator:create_decision_criteria_ui(level_idx, criteria)
    
    my_gui = gui(ui_elements)
    my_gui.render()
end

function show_symptom_dialog()
    -- Check if dialog flow manager exists
    if not dialog_flow_manager then
        ui:show_text("ERROR: Dialog flow manager not available")
        return
    end
    
    local status, dialog_config = dialog_flow_manager:start_flow("symptom")
    
    if status == "show_dialog" then
        show_aio_dialog(dialog_config)
    elseif status == "error" then
        ui:show_text("Error starting symptom flow: " .. tostring(dialog_config))
    else
        ui:show_text("Unexpected status: " .. tostring(status))
    end
end

function show_aio_dialog(dialog_config)
    if dialog_config.type == "list" then
        dialogs:show_list_dialog({
            title = dialog_config.title,
            lines = dialog_config.data.items,
            search = true,
            zebra = true
        })
    elseif dialog_config.type == "radio" then
        dialogs:show_radio_dialog(dialog_config.title, dialog_config.data.options, 0)
    elseif dialog_config.type == "edit" then
        dialogs:show_edit_dialog(dialog_config.title, dialog_config.data.prompt, dialog_config.data.default_text or "")
    end
end

function show_activity_dialog()
    dialog_manager:set_dialog_type("activity")
    local activities, required_activities = dialog_manager:load_activities(function(filename) return files:read(filename) end)
    local formatted_activities = core.format_list_items(activities, "activity", daily_logs, required_activities, {})
    dialogs:show_list_dialog({
        title = "Log Activity",
        lines = formatted_activities,
        search = true,
        zebra = true
    })
end

function show_intervention_dialog()
    dialog_manager:set_dialog_type("intervention")
    local interventions, required_interventions = dialog_manager:load_interventions(function(filename) return files:read(filename) end)
    local formatted_interventions = core.format_list_items(interventions, "intervention", daily_logs, {}, required_interventions)
    dialogs:show_list_dialog({
        title = "Log Intervention",
        lines = formatted_interventions,
        search = true,
        zebra = true
    })
end

function show_energy_dialog()
    dialog_manager:set_dialog_type("energy")
    local energy_levels = dialog_manager:get_energy_levels()
    dialogs:show_radio_dialog("Log Energy Level", energy_levels, 0)
end

-- Generic logging function that handles all item types
function log_item(item_type, item_value, metadata)
    local tasker_callback = nil
    local ui_callback = nil
    
    -- For Tasker/Google Sheets, include severity in the logged value
    local tasker_item_value = item_value
    if metadata and metadata.severity then
        tasker_item_value = item_value .. " (severity: " .. metadata.severity .. ")"
    end
    
    if tasker then
        tasker_callback = function(params)
            -- Override the value with severity info for Google Sheets
            if metadata and metadata.severity then
                params.value = tasker_item_value
            end
            tasker:run_task("LongCovid_LogEvent", params)
        end
    end
    
    ui_callback = function(message)
        if type(message) ~= "string" then
            message = tostring(message)
        end
        -- For symptoms with severity, show the severity in the toast
        if metadata and metadata.severity and message:find("Symptom logged:") then
            message = message:gsub("(Symptom logged: " .. core.escape_pattern(item_value) .. ")", "%1 (severity: " .. metadata.severity .. ")")
        end
        ui:show_toast(message)
    end
    
    local success
    if item_type == "energy" then
        success = core.log_energy_with_tasker(daily_logs, item_value, tasker_callback, ui_callback)
    else
        success = core.log_item_with_tasker(daily_logs, item_type, item_value, tasker_callback, ui_callback)
    end
    
    if success then
        save_prefs_data()
        
        -- Show appropriate dialog or return to widget
        local dialog_type = dialog_manager:get_dialog_type()
        if dialog_type == "symptom" or dialog_type == "symptom_edit" then
            show_symptom_dialog()
        elseif dialog_type == "activity" or dialog_type == "activity_edit" then
            show_activity_dialog()
        elseif dialog_type == "intervention" or dialog_type == "intervention_edit" then
            show_intervention_dialog()
        else
            render_widget()
        end
    end
end


function on_dialog_action(result)
    -- Check if we have an active dialog flow (new system)
    if dialog_flow_manager:get_current_dialog() then        
        local status, flow_result = dialog_flow_manager:handle_dialog_result(result)
        
        if status == "show_dialog" then
            show_aio_dialog(flow_result)
        elseif status == "flow_complete" then
            -- Log the completed item
            log_item(flow_result.category, flow_result.item, flow_result.metadata)
            render_widget()
        elseif status == "flow_cancelled" then
            render_widget()
        elseif status == "continue" then
            -- Dialog system quirk handling - do nothing
        elseif status == "error" then
            ui:show_text("Dialog flow error: " .. tostring(flow_result))
            render_widget()
        end
        return true
    end
    
    -- Fall back to legacy dialog system for activities/interventions
    local action, param1, param2, param3, param4 = dialog_manager:handle_dialog_result(
        result, 
        daily_logs, 
        function(filename) return files:read(filename) end, 
        log_item
    )
    
    if action == "cancelled" then
        return true
    elseif action == "edit_dialog" then
        dialogs:show_edit_dialog(param1, param2, param3)
        return true
    elseif action == "logged" then
        return true
    elseif action == "return_to_list" then
        local dialog_type = dialog_manager:get_dialog_type()
        if dialog_type == "symptom" then
            show_symptom_dialog()
        elseif dialog_type == "activity" then
            show_activity_dialog()
        elseif dialog_type == "intervention" then
            show_intervention_dialog()
        end
        return true
    end
    
    return true
end