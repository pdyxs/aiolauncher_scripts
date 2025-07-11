-- name = "Long Covid Pacing"
-- description = "Daily capacity level selection and plan display"
-- type = "widget"
-- author = "Paul Sztajer"
-- version = "1.0"
-- foldable = "true"

local prefs = require "prefs"

-- Initialize preferences
if not prefs.selected_level then
    prefs.selected_level = 2  -- Default to YELLOW
end

-- Capacity levels
local levels = {
    {name = "🔴 RED", color = "#FF4444", key = "red"},
    {name = "🟡 YELLOW", color = "#FFAA00", key = "yellow"}, 
    {name = "🟢 GREEN", color = "#44AA44", key = "green"}
}

-- Using AIO Launcher's files module (sandboxed directory)
-- Files will be stored in /sdcard/Android/data/ru.execbit.aiolauncher/files/scripts/

-- Cache for parsed data
local cached_plans = {}
local cached_criteria = nil

function on_resume()
    -- Add error handling for the main entry point
    local success, error_msg = pcall(function()
        load_data()
        render_widget()
    end)
    
    if not success then
        ui:show_text("Error loading widget: " .. tostring(error_msg))
    end
end

function on_click(idx)
    if idx >= 1 and idx <= 3 then
        -- Only allow same level or downgrade
        if idx <= prefs.selected_level then
            prefs.selected_level = idx
            save_daily_choice(idx)
            render_widget()
        else
            ui:show_toast("Can only downgrade capacity level")
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
    
    -- Create buttons with current selection highlighted
    local button_names = {}
    local button_colors = {}
    
    for i, level in ipairs(levels) do
        table.insert(button_names, level.name)
        if i == prefs.selected_level then
            table.insert(button_colors, level.color)
        else
            table.insert(button_colors, "#888888")  -- Dimmed for non-selected
        end
    end
    
    ui:show_buttons(button_names, button_colors)
    
    -- Show plan details if expanded
    if ui:is_expanded() then
        local success, error_msg = pcall(function()
            show_plan_details(today)
        end)
        
        if not success then
            ui:show_text("Selected: " .. levels[prefs.selected_level].name .. "\n\nCan't load plan data.\nCheck file paths in Documents folder.")
        end
    end
end

function show_plan_details(day)
    local plan = cached_plans[day]
    if not plan then
        ui:show_text("No plan available for " .. day)
        return
    end
    
    local level_key = levels[prefs.selected_level].key
    local level_plan = plan[level_key]
    
    if not level_plan then
        ui:show_text("No plan available for selected level")
        return
    end
    
    local lines = {}
    table.insert(lines, "<b>Today's Plan:</b>")
    table.insert(lines, "")
    
    -- Add each category
    for category, items in pairs(level_plan) do
        if #items > 0 then
            table.insert(lines, "<b>" .. category .. ":</b>")
            for _, item in ipairs(items) do
                table.insert(lines, "• " .. item)
            end
            table.insert(lines, "")
        end
    end
    
    ui:show_lines(lines)
end

function save_daily_choice(level_idx)
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
    if idx >= 1 and idx <= 3 then
        -- Show decision criteria for selected level
        show_decision_criteria(idx)
    end
end

function show_decision_criteria(level_idx)
    local level_key = levels[level_idx].key
    local criteria = cached_criteria[level_key]
    
    if not criteria or #criteria == 0 then
        ui:show_toast("No criteria available")
        return
    end
    
    local lines = {}
    table.insert(lines, "<b>" .. levels[level_idx].name .. " - Decision Criteria:</b>")
    table.insert(lines, "")
    
    for _, criterion in ipairs(criteria) do
        table.insert(lines, "• " .. criterion)
    end
    
    ui:show_lines(lines)
end