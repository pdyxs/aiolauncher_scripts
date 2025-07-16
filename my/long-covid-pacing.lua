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
        elseif elem_text:find("rotate%-right") then
            -- Reset selection button
            prefs.selected_level = 0
            ui:show_toast("Selection reset")
            render_widget()
        elseif elem_text:find("sync") then
            -- Sync files button
            sync_plan_files()
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
    
    -- Map weekend to combined weekend file
    if today == "saturday" or today == "sunday" then
        return "weekend"
    end
    
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
        elseif line:match("^## YELLOW") then
            current_level = "yellow"
            current_category = nil
        elseif line:match("^## GREEN") then
            current_level = "green"
            current_category = nil
        elseif line:match("^### ") and current_level then
            current_category = line:match("^### (.+)")
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

function render_widget()
    local today = get_current_day()
    local day_display = today:gsub("^%l", string.upper)  -- Capitalize first letter
    
    ui:set_title("Long Covid Pacing - " .. day_display)
    
    -- Build Rich UI
    local ui_elements = {}
    
    -- Add capacity level buttons
    for i, level in ipairs(levels) do
        local color
        local button_text
        
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
        
        table.insert(ui_elements, {"button", button_text, {color = color}})
        if i < #levels then
            table.insert(ui_elements, {"spacer", 1})
        end
    end
    
    -- Add reset button (always icon-only)
    table.insert(ui_elements, {"spacer", 2})
    table.insert(ui_elements, {"button", "fa:rotate-right", {color = "#666666"}})

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
            table.insert(ui_elements, {"button", "%%fa:sync%% Sync Files", {color = "#4CAF50"}})
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
                table.insert(ui_elements, {"button", "%%fa:sync%% Sync Files", {color = "#4CAF50"}})
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
    
    table.insert(ui_elements, {"text", "<b>Today's Plan:</b>", {size = 18}})
    table.insert(ui_elements, {"new_line", 1})
    
    -- Add each category
    for category, items in pairs(level_plan) do
        if #items > 0 then
            table.insert(ui_elements, {"text", "<b>" .. category .. ":</b>", {size = 16, color = "#666666"}})
            table.insert(ui_elements, {"new_line", 1})
            for _, item in ipairs(items) do
                table.insert(ui_elements, {"text", "• " .. item})
                table.insert(ui_elements, {"new_line", 1})
            end
            table.insert(ui_elements, {"new_line", 1})
        end
    end
    
    -- Add sync button at the end
    table.insert(ui_elements, {"button", "%%fa:sync%% Sync Files", {color = "#4CAF50"}})
end

function save_daily_choice(level_idx)
    if level_idx == 0 then
        return  -- Don't save if no selection
    end
    
    local today = os.date("%Y-%m-%d")
    local day_name = get_current_day()
    local level_name = levels[level_idx].name
    
    local entry = string.format("## %s (%s)\n- Capacity: %s\n- Time: %s\n\n", 
        today, day_name:gsub("^%l", string.upper), level_name, os.date("%H:%M"))
    
    -- Read existing tracking file
    local existing_content = files:read("tracking.md") or "# Long Covid Daily Tracking\n\n"
    
    -- Append new entry
    local new_content = existing_content .. entry
    
    -- Save updated content
    files:write("tracking.md", new_content)
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
        elseif elem_text:find("rotate%-right") then
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