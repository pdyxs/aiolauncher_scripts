-- name = "Long Covid Pacing"
-- description = "Daily capacity level selection and plan display"
-- type = "widget"
-- author = "Paul Sztajer"
-- version = "1.0"
-- foldable = "true"

local prefs = require "prefs"

-- Initialize preferences
if not prefs.selected_level then
    prefs.selected_level = 0  -- Default to no selection
end

-- Track what day we last made a selection
if not prefs.last_selection_date then
    prefs.last_selection_date = ""
end

-- Capacity levels
local levels = {
    {name = "Recovering", color = "#FF4444", key = "red", icon = "bed"},
    {name = "Maintaining", color = "#FFAA00", key = "yellow", icon = "walking"}, 
    {name = "Engaging", color = "#44AA44", key = "green", icon = "bolt"}
}

-- Using AIO Launcher's files module (sandboxed directory) 
-- OR receive data directly from Tasker via broadcast intent
-- Tasker sends plan data directly to avoid file permission issues

-- Cache for parsed data
local cached_plans = {}
local cached_criteria = nil
local cached_symptoms = nil
local data_source = "none"  -- "files" or "tasker" or "none"

function on_resume()
    -- Add error handling for the main entry point
    local success, error_msg = pcall(function()
        check_daily_reset()
        load_data()
        render_widget()
    end)
    
    if not success then
        ui:show_text("Error loading widget: " .. tostring(error_msg))
    end
end

function check_daily_reset()
    local today = os.date("%Y-%m-%d")
    if prefs.last_selection_date ~= today then
        -- New day - reset to no selection
        prefs.selected_level = 0
        prefs.last_selection_date = today
    else
        -- Same day - check if we have a stored selection
        if prefs.daily_capacity_log and prefs.daily_capacity_log[today] then
            prefs.selected_level = prefs.daily_capacity_log[today].capacity
        end
    end
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
            if prefs.selected_level == 0 or 1 <= prefs.selected_level then
                prefs.selected_level = 1
                save_daily_choice(1)
                render_widget()
            else
                ui:show_toast("Can only downgrade capacity level")
            end
        elseif elem_text:find("walking") then
            -- Capacity level 2 (Maintaining)
            if prefs.selected_level == 0 or 2 <= prefs.selected_level then
                prefs.selected_level = 2
                save_daily_choice(2)
                render_widget()
            else
                ui:show_toast("Can only downgrade capacity level")
            end
        elseif elem_text:find("bolt") then
            -- Capacity level 3 (Engaging)
            if prefs.selected_level == 0 or 3 <= prefs.selected_level then
                prefs.selected_level = 3
                save_daily_choice(3)
                render_widget()
            else
                ui:show_toast("Can only downgrade capacity level")
            end
        elseif elem_text:find("rotate%-right") or elem_text:find("Reset") then
            -- Reset selection button
            prefs.selected_level = 0
            
            -- Also clear the stored daily capacity log for today
            local today = os.date("%Y-%m-%d")
            if prefs.daily_capacity_log and prefs.daily_capacity_log[today] then
                prefs.daily_capacity_log[today] = nil
            end
            
            ui:show_toast("Selection reset")
            render_widget()
        elseif elem_text:find("sync") then
            -- Sync files button
            sync_plan_files()
        elseif elem_text:find("notes%-medical") then
            -- Symptom logging button
            show_symptom_dialog()
        elseif elem_text == "Back" then
            -- Back button from decision criteria
            render_widget()
        end
    end
end

function load_data()
    -- Load decision criteria if not cached
    if not cached_criteria then
        cached_criteria = parse_decision_criteria()
    end
    
    -- Load today's plan if not cached
    local today = get_current_day()
    if not cached_plans[today] then
        cached_plans[today] = parse_day_file(today)
    end
end

function get_current_day()
    local day_names = {"sunday", "monday", "tuesday", "wednesday", "thursday", "friday", "saturday"}
    local today = day_names[tonumber(os.date("%w")) + 1]
    
    return today
end

function parse_decision_criteria()
    local content = files:read("decision_criteria.md")
    if not content then
        return {red = {}, yellow = {}, green = {}}
    end
    
    local criteria = {red = {}, yellow = {}, green = {}}
    local current_level = nil
    
    for line in content:gmatch("[^\r\n]+") do
        if line:match("^## RED") then
            current_level = "red"
        elseif line:match("^## YELLOW") then
            current_level = "yellow"
        elseif line:match("^## GREEN") then
            current_level = "green"
        elseif line:match("^%- ") and current_level then
            local item = line:match("^%- (.+)")
            if item then
                table.insert(criteria[current_level], item)
            end
        end
    end
    
    return criteria
end

function parse_day_file(day)
    local filename = day .. ".md"
    local content = files:read(filename)
    
    if not content then
        return {red = {}, yellow = {}, green = {}}
    end
    
    local template = {red = {}, yellow = {}, green = {}}
    local current_level = nil
    local current_category = nil
    
    for line in content:gmatch("[^\r\n]+") do
        if line:match("^## RED") then
            current_level = "red"
            current_category = nil
            template[current_level].overview = {}
        elseif line:match("^## YELLOW") then
            current_level = "yellow"
            current_category = nil
            template[current_level].overview = {}
        elseif line:match("^## GREEN") then
            current_level = "green"
            current_category = nil
            template[current_level].overview = {}
        elseif line:match("^%*%*") and current_level and not current_category then
            -- Parse quick summary lines like "**Work:** WFH normal, hourly breaks"
            table.insert(template[current_level].overview, line)
        elseif line:match("^### ") and current_level then
            current_category = line:match("^### (.+)")
            if current_category then
                template[current_level][current_category] = {}
            end
        elseif line:match("^#### ") and current_level then
            current_category = line:match("^#### (.+)")
            if current_category then
                template[current_level][current_category] = {}
            end
        elseif line:match("^%- ") and current_level and current_category then
            local item = line:match("^%- (.+)")
            if item then
                table.insert(template[current_level][current_category], item)
            end
        end
    end
    
    return template
end

function parse_symptoms_file()
    -- Return cached symptoms if available
    if cached_symptoms then
        return cached_symptoms
    end
    
    local content = files:read("symptoms.md")
    if not content then
        -- Fallback to default symptoms if file not available
        cached_symptoms = {
            "Fatigue",
            "Brain fog", 
            "Headache",
            "Shortness of breath",
            "Joint pain",
            "Muscle aches",
            "Sleep issues",
            "Other..."
        }
        return cached_symptoms
    end
    
    local symptoms = {}
    local current_category = nil
    
    for line in content:gmatch("[^\r\n]+") do
        if line:match("^## ") then
            current_category = line:match("^## (.+)")
        elseif line:match("^%- ") then
            local symptom = line:match("^%- (.+)")
            if symptom then
                table.insert(symptoms, symptom)
            end
        end
    end
    
    -- Always add "Other..." as the last option
    table.insert(symptoms, "Other...")
    
    -- Cache the parsed symptoms
    cached_symptoms = symptoms
    
    return symptoms
end

function render_widget()
    local today = get_current_day()
    local day_display = today:gsub("^%l", string.upper)  -- Capitalize first letter
    
    ui:set_title("Long Covid Pacing - " .. day_display)
    
    -- Build Rich UI
    local ui_elements = {}
    
    -- Add capacity level buttons (centered)
    for i, level in ipairs(levels) do
        local color
        local button_text
        local gravity = nil
        
        if i == prefs.selected_level then
            color = level.color  -- Highlight selected
            button_text = "%%fa:" .. level.icon .. "%% " .. level.name  -- Icon + text for selected
        elseif prefs.selected_level == 0 then
            color = level.color  -- All available when none selected
            button_text = "%%fa:" .. level.icon .. "%% " .. level.name  -- Icon + text when all available
        else
            color = "#888888"  -- Dimmed for unavailable
            button_text = "fa:" .. level.icon  -- Icon only for unavailable
        end
        
        -- Center the first button, anchor others to it
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
        if i < #levels then
            table.insert(ui_elements, {"spacer", 1})
        end
    end
    
    -- Add symptom logging button on the right side
    table.insert(ui_elements, {"button", "fa:notes-medical", {color = "#6c757d", gravity = "right"}})

    ui:set_expandable(true)
    
    -- Add plan details if expanded
    if ui:is_expanded() then
        table.insert(ui_elements, {"new_line", 2})
        
        if prefs.selected_level == 0 then
            -- No selection made yet
            table.insert(ui_elements, {"text", "<b>Select your capacity level:</b>", {size = 18}})
            table.insert(ui_elements, {"new_line", 1})
            table.insert(ui_elements, {"text", "%%fa:bed%% <b>Recovering</b> - Low energy, prioritize rest", {color = "#FF4444"}})
            table.insert(ui_elements, {"new_line", 1})
            table.insert(ui_elements, {"text", "%%fa:walking%% <b>Maintaining</b> - Moderate energy, standard routine", {color = "#FFAA00"}})
            table.insert(ui_elements, {"new_line", 1})
            table.insert(ui_elements, {"text", "%%fa:bolt%% <b>Engaging</b> - High energy, can handle challenges", {color = "#44AA44"}})
            table.insert(ui_elements, {"new_line", 2})
            table.insert(ui_elements, {"button", "%%fa:sync%% Sync Files", {color = "#4CAF50", gravity = "center_h"}})
            table.insert(ui_elements, {"spacer", 2})
            table.insert(ui_elements, {"button", "%%fa:rotate-right%% Reset", {color = "#666666", gravity = "anchor_prev"}})
        else
            local success, error_msg = pcall(function()
                add_plan_details(ui_elements, today)
            end)
            
            if not success then
                -- Show error and sync button
                table.insert(ui_elements, {"text", "<b>Selected:</b> " .. levels[prefs.selected_level].name, {size = 18}})
                table.insert(ui_elements, {"new_line", 1})
                table.insert(ui_elements, {"text", "%%fa:exclamation-triangle%% <b>Can't load plan data</b>", {color = "#ff6b6b"}})
                table.insert(ui_elements, {"new_line", 2})
                table.insert(ui_elements, {"button", "%%fa:sync%% Sync Files", {color = "#4CAF50", gravity = "center_h"}})
                table.insert(ui_elements, {"spacer", 2})
                table.insert(ui_elements, {"button", "%%fa:rotate-right%% Reset", {color = "#666666", gravity = "anchor_prev"}})
            end
        end
    end
    
    -- Render the UI
    my_gui = gui(ui_elements)
    my_gui.render()
end

function add_plan_details(ui_elements, day)
    local plan = cached_plans[day]
    if not plan then
        table.insert(ui_elements, {"text", "No plan available for " .. day, {color = "#ff6b6b"}})
        return
    end
    
    local level_key = levels[prefs.selected_level].key
    local level_plan = plan[level_key]
    
    if not level_plan then
        table.insert(ui_elements, {"text", "No plan available for selected level", {color = "#ff6b6b"}})
        return
    end
    
    -- Add quick overview if available
    if level_plan.overview and #level_plan.overview > 0 then
        table.insert(ui_elements, {"text", "<b>Today's Overview:</b>", {size = 18}})
        table.insert(ui_elements, {"new_line", 1})
        for _, overview_line in ipairs(level_plan.overview) do
            -- Convert markdown bold to HTML bold
            local formatted_line = overview_line:gsub("%*%*([^%*]+)%*%*", "<b>%1</b>")
            table.insert(ui_elements, {"text", formatted_line, {size = 16}})
            table.insert(ui_elements, {"new_line", 1})
        end
        table.insert(ui_elements, {"new_line", 1})
    end
    
    -- Add each category (excluding overview)
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
    
    -- Add sync button and reset at the end
    table.insert(ui_elements, {"button", "%%fa:sync%% Sync Files", {color = "#4CAF50", gravity = "center_h"}})
    table.insert(ui_elements, {"spacer", 2})
    table.insert(ui_elements, {"button", "%%fa:rotate-right%% Reset", {color = "#666666", gravity = "anchor_prev"}})
end

function save_daily_choice(level_idx)
    if level_idx == 0 then
        return  -- Don't save if no selection
    end
    
    local today = os.date("%Y-%m-%d")
    local timestamp = os.date("%Y-%m-%d %H:%M:%S")
    local level_name = levels[level_idx].name
    
    -- Store locally for offline access and daily reset functionality
    if not prefs.daily_capacity_log then
        prefs.daily_capacity_log = {}
    end
    
    prefs.daily_capacity_log[today] = {
        capacity = level_idx,
        capacity_name = level_name,
        timestamp = os.date("%H:%M")
    }
    
    -- Send to AutoSheets via Tasker (simplified 3-column format)
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
        elseif elem_text:find("bolt") then
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
    -- Call Tasker to send plan data directly to widget
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
        -- Data will be received via on_command callback
    else
        ui:show_toast("✗ Tasker task failed")
    end
end

function on_command(data)
    -- Receive data from Tasker via broadcast intent
    -- Data format: "type:filename:content"
    local parts = data:split(":")
    if #parts < 3 then
        return
    end
    
    local data_type = parts[1]
    local filename = parts[2]
    local content = table.concat(parts, ":", 3)  -- Rejoin content (may contain colons)
    
    if data_type == "plan_data" then
        -- Store the received data using AIO's files module
        files:write(filename, content)
        
        -- Clear cache to reload data
        cached_plans = {}
        cached_criteria = nil
        cached_symptoms = nil
        data_source = "files"
        
        -- Reload widget
        load_data()
        render_widget()
        
        ui:show_toast("✓ Plan data updated")
    end
end

function show_decision_criteria(level_idx)
    local level_key = levels[level_idx].key
    local criteria = cached_criteria[level_key]
    
    if not criteria or #criteria == 0 then
        ui:show_toast("No criteria available")
        return
    end
    
    local ui_elements = {}
    table.insert(ui_elements, {"text", "<b>" .. levels[level_idx].name .. " - Decision Criteria:</b>", {size = 18, color = levels[level_idx].color}})
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
    local symptoms = parse_symptoms_file()
    dialogs:show_list_dialog({
        title = "Log Symptom",
        lines = symptoms,
        search = true,
        zebra = true
    })
end

function log_symptom(symptom_name)
    local timestamp = os.date("%Y-%m-%d %H:%M:%S")
    
    -- Send to AutoSheets via Tasker
    if tasker then
        tasker:run_task("LongCovid_LogEvent", {
            timestamp = timestamp,
            event_type = "Symptom",
            value = symptom_name
        })
        ui:show_toast("✓ Symptom logged: " .. symptom_name)
    else
        ui:show_toast("Tasker not available")
    end
end

function on_dialog_action(result)
    if result == -1 then
        -- Dialog was cancelled
        return
    end
    
    if type(result) == "number" then
        -- List dialog result - symptom selection
        local symptoms = parse_symptoms_file()
        local selected_symptom = symptoms[result]
        
        if selected_symptom == "Other..." then
            -- Show edit dialog for custom symptom
            dialogs:show_edit_dialog("Custom Symptom", "Enter symptom name:", "")
        else
            -- Log the selected symptom
            log_symptom(selected_symptom)
        end
    elseif type(result) == "string" then
        -- Edit dialog result - custom symptom text
        if result ~= "" then
            log_symptom(result)
        end
    end
end