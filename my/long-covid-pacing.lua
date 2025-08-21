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

-- Initialize daily logs tracking
if not prefs.daily_logs then
    prefs.daily_logs = {}
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
local cached_activities = nil
local cached_interventions = nil
local cached_required_activities = nil
local cached_required_interventions = nil
local current_dialog_type = nil  -- Track which dialog is open: "symptom", "activity", or "intervention"
local data_source = "none"  -- "files" or "tasker" or "none"

-- Global variables to store prefs data
local selected_level = 0
local last_selection_date = ""
local daily_capacity_log = {}
local daily_logs = {}

function load_prefs_data()
    -- Load prefs data into global variables
    selected_level = prefs.selected_level or 0
    last_selection_date = prefs.last_selection_date or ""
    daily_capacity_log = prefs.daily_capacity_log or {}
    daily_logs = prefs.daily_logs or {}
    
    -- Purge old daily logs on every load for performance
    local today = os.date("%Y-%m-%d")
    purge_old_daily_logs(today)
end

function save_prefs_data()
    -- Save global variables back to prefs
    prefs.selected_level = selected_level
    prefs.last_selection_date = last_selection_date
    prefs.daily_capacity_log = daily_capacity_log
    prefs.daily_logs = daily_logs
end

function on_resume()
    -- Add error handling for the main entry point
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
    local today = os.date("%Y-%m-%d")
    if last_selection_date ~= today then
        -- New day - reset to no selection
        selected_level = 0
        last_selection_date = today
        -- Purge all old daily logs - only keep today's data for performance
        purge_old_daily_logs(today)
        -- Save changes back to prefs
        save_prefs_data()
    else
        -- Same day - check if we have a stored selection
        if daily_capacity_log and daily_capacity_log[today] then
            selected_level = daily_capacity_log[today].capacity
        end
    end
end

function purge_old_daily_logs(today)
    if not daily_logs then
        daily_logs = {}
        return
    end
    
    -- Keep only today's entry, remove all others for performance
    local today_logs = daily_logs[today]
    daily_logs = {}
    
    -- Initialize today's logs if needed
    if not today_logs then
        daily_logs[today] = {
            symptoms = {},
            activities = {},
            interventions = {},
            energy_levels = {}
        }
    else
        daily_logs[today] = today_logs
    end
end

function get_daily_logs(date)
    -- Use global variable instead of prefs
    if not daily_logs then
        daily_logs = {}
    end
    
    if not daily_logs[date] then
        daily_logs[date] = {
            symptoms = {},
            activities = {},
            interventions = {},
            energy_levels = {}
        }
    else
        -- Ensure existing logs have energy_levels field (backward compatibility)
        if not daily_logs[date].energy_levels then
            daily_logs[date].energy_levels = {}
        end
    end
    
    return daily_logs[date]
end

function log_item(item_type, item_name)
    local today = os.date("%Y-%m-%d")
    local logs = get_daily_logs(today)
    
    -- Should always work now since we use global variables
    if not logs then
        ui:show_toast("ERROR: Could not get daily logs")
        return
    end
    
    local category
    if item_type == "symptom" then
        category = logs.symptoms
    elseif item_type == "activity" then
        category = logs.activities
    elseif item_type == "intervention" then
        category = logs.interventions
    else
        ui:show_toast("ERROR: Invalid item type: " .. tostring(item_type))
        return
    end
    
    category[item_name] = (category[item_name] or 0) + 1
    
    -- Save changes back to prefs immediately
    save_prefs_data()
end

function format_list_items(items, item_type)
    local today = os.date("%Y-%m-%d")
    local logs = get_daily_logs(today)
    
    -- Should always work now since we use global variables
    if not logs then
        ui:show_toast("ERROR: Could not get daily logs for formatting")
        return items
    end
    
    local category
    local required_items = {}
    if item_type == "symptom" then
        category = logs.symptoms
        -- Symptoms don't have required items
    elseif item_type == "activity" then
        category = logs.activities
        required_items = get_required_activities_for_today()
    elseif item_type == "intervention" then
        category = logs.interventions
        required_items = get_required_interventions_for_today()
    else
        ui:show_toast("ERROR: Invalid item_type for formatting: " .. tostring(item_type))
        return items
    end
    
    -- Create a set for faster lookup
    local required_set = {}
    for _, req_item in ipairs(required_items) do
        required_set[req_item] = true
    end
    
    local formatted = {}
    for _, item in ipairs(items) do
        local count = category[item]
        local is_required = required_set[item]
        
        if count and count > 0 then
            -- Logged items get checkmark
            if is_required then
                -- Required and completed: Green checkmark
                table.insert(formatted, "✅ " .. item .. " (" .. count .. ")")
            else
                -- Optional and completed: Regular checkmark
                table.insert(formatted, "✓ " .. item .. " (" .. count .. ")")
            end
        else
            -- Unlogged items
            if is_required then
                -- Required but not completed: Warning icon
                table.insert(formatted, "⚠️ " .. item)
            else
                -- Optional and not completed: Regular spacing
                table.insert(formatted, "   " .. item)
            end
        end
    end
    
    return formatted
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
                save_daily_choice(1)
                save_prefs_data()
                render_widget()
            else
                ui:show_toast("Can only downgrade capacity level")
            end
        elseif elem_text:find("walking") then
            -- Capacity level 2 (Maintaining)
            if selected_level == 0 or 2 <= selected_level then
                selected_level = 2
                save_daily_choice(2)
                save_prefs_data()
                render_widget()
            else
                ui:show_toast("Can only downgrade capacity level")
            end
        elseif elem_text:find("bolt") then
            -- Capacity level 3 (Engaging)
            if selected_level == 0 or 3 <= selected_level then
                selected_level = 3
                save_daily_choice(3)
                save_prefs_data()
                render_widget()
            else
                ui:show_toast("Can only downgrade capacity level")
            end
        elseif elem_text:find("rotate%-right") or elem_text:find("Reset") then
            -- Reset selection button
            selected_level = 0
            
            -- Also clear the stored daily capacity log for today
            local today = os.date("%Y-%m-%d")
            if daily_capacity_log and daily_capacity_log[today] then
                daily_capacity_log[today] = nil
            end
            
            save_prefs_data()
            ui:show_toast("Selection reset")
            render_widget()
        elseif elem_text:find("sync") then
            -- Sync files button
            sync_plan_files()
        elseif elem_text:find("heart%-pulse") then
            -- Symptom logging button
            show_symptom_dialog()
        elseif elem_text:find("bolt%-lightning") then
            -- Energy level logging button
            show_energy_dialog()
        elseif elem_text:find("running") then
            -- Activity logging button
            show_activity_dialog()
        elseif elem_text:find("pills") then
            -- Intervention logging button
            show_intervention_dialog()
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

function parse_activities_file()
    -- Return cached activities if available
    if cached_activities then
        return cached_activities
    end
    
    local content = files:read("activities.md")
    if not content then
        -- Fallback to default activities if file not available
        cached_activities = {
            "Light walk",
            "Desk work",
            "Cooking",
            "Reading",
            "Social visit",
            "Rest/nap",
            "Other..."
        }
        return cached_activities
    end
    
    local activities = {}
    local current_category = nil
    
    for line in content:gmatch("[^\r\n]+") do
        if line:match("^## ") then
            current_category = line:match("^## (.+)")
        elseif line:match("^%- ") then
            local activity = line:match("^%- (.+)")
            if activity then
                -- Clean up activity name by removing {Required} markers
                local clean_activity = activity:match("^(.-)%s*%{Required") or activity
                table.insert(activities, clean_activity)
            end
        end
    end
    
    -- Always add "Other..." as the last option
    table.insert(activities, "Other...")
    
    -- Cache the parsed activities
    cached_activities = activities
    
    return activities
end

function parse_interventions_file()
    -- Return cached interventions if available
    if cached_interventions then
        return cached_interventions
    end
    
    local content = files:read("interventions.md")
    if not content then
        -- Fallback to default interventions if file not available
        cached_interventions = {
            "Vitamin D",
            "Vitamin B12",
            "Magnesium",
            "Extra rest",
            "Breathing exercises",
            "Meditation",
            "Other..."
        }
        return cached_interventions
    end
    
    local interventions = {}
    local current_category = nil
    
    for line in content:gmatch("[^\r\n]+") do
        if line:match("^## ") then
            current_category = line:match("^## (.+)")
        elseif line:match("^%- ") then
            local intervention = line:match("^%- (.+)")
            if intervention then
                -- Clean up intervention name by removing {Required} markers
                local clean_intervention = intervention:match("^(.-)%s*%{Required") or intervention
                table.insert(interventions, clean_intervention)
            end
        end
    end
    
    -- Always add "Other..." as the last option
    table.insert(interventions, "Other...")
    
    -- Cache the parsed interventions
    cached_interventions = interventions
    
    return interventions
end

function parse_required_activities()
    -- Return cached required activities if available
    if cached_required_activities then
        return cached_required_activities
    end
    
    local content = files:read("activities.md")
    if not content then
        cached_required_activities = {}
        return cached_required_activities
    end
    
    local required_activities = {}
    
    for line in content:gmatch("[^\r\n]+") do
        if line:match("^%- ") then
            local activity_line = line:match("^%- (.+)")
            if activity_line and activity_line:match("%{Required") then
                -- Extract activity name (everything before {Required)
                local activity_name = activity_line:match("^(.-)%s*%{Required")
                if activity_name then
                    local required_info = {
                        name = activity_name,
                        days = nil -- nil means all days
                    }
                    
                    -- Check for specific days: {Required: Mon,Wed,Fri}
                    local days_match = activity_line:match("%{Required:%s*([^%}]+)%}")
                    if days_match then
                        required_info.days = {}
                        for day_abbrev in days_match:gmatch("([^,%s]+)") do
                            table.insert(required_info.days, day_abbrev:lower())
                        end
                    end
                    
                    table.insert(required_activities, required_info)
                end
            end
        end
    end
    
    -- Cache the parsed required activities
    cached_required_activities = required_activities
    
    return required_activities
end

function parse_required_interventions()
    -- Return cached required interventions if available
    if cached_required_interventions then
        return cached_required_interventions
    end
    
    local content = files:read("interventions.md")
    if not content then
        cached_required_interventions = {}
        return cached_required_interventions
    end
    
    local required_interventions = {}
    
    for line in content:gmatch("[^\r\n]+") do
        if line:match("^%- ") then
            local intervention_line = line:match("^%- (.+)")
            if intervention_line and intervention_line:match("%{Required") then
                -- Extract intervention name (everything before {Required)
                local intervention_name = intervention_line:match("^(.-)%s*%{Required")
                if intervention_name then
                    local required_info = {
                        name = intervention_name,
                        days = nil -- nil means all days
                    }
                    
                    -- Check for specific days: {Required: Mon,Wed,Fri}
                    local days_match = intervention_line:match("%{Required:%s*([^%}]+)%}")
                    if days_match then
                        required_info.days = {}
                        for day_abbrev in days_match:gmatch("([^,%s]+)") do
                            table.insert(required_info.days, day_abbrev:lower())
                        end
                    end
                    
                    table.insert(required_interventions, required_info)
                end
            end
        end
    end
    
    -- Cache the parsed required interventions
    cached_required_interventions = required_interventions
    
    return required_interventions
end

function get_current_day_abbrev()
    local day_abbrevs = {"sun", "mon", "tue", "wed", "thu", "fri", "sat"}
    return day_abbrevs[tonumber(os.date("%w")) + 1]
end

function is_required_today(required_info)
    -- If no specific days, it's required every day
    if not required_info.days then
        return true
    end
    
    local today_abbrev = get_current_day_abbrev()
    for _, day in ipairs(required_info.days) do
        if day == today_abbrev then
            return true
        end
    end
    
    return false
end

function get_required_activities_for_today()
    local required_activities = parse_required_activities()
    local today_required = {}
    
    for _, required_info in ipairs(required_activities) do
        if is_required_today(required_info) then
            table.insert(today_required, required_info.name)
        end
    end
    
    return today_required
end

function get_required_interventions_for_today()
    local required_interventions = parse_required_interventions()
    local today_required = {}
    
    for _, required_info in ipairs(required_interventions) do
        if is_required_today(required_info) then
            table.insert(today_required, required_info.name)
        end
    end
    
    return today_required
end

function are_all_required_activities_completed()
    local required_activities = get_required_activities_for_today()
    if #required_activities == 0 then
        return true -- No required activities, so all are "completed"
    end
    
    local today = os.date("%Y-%m-%d")
    local logs = get_daily_logs(today)
    
    for _, required_activity in ipairs(required_activities) do
        if not logs.activities[required_activity] or logs.activities[required_activity] == 0 then
            return false -- This required activity hasn't been logged
        end
    end
    
    return true
end

function are_all_required_interventions_completed()
    local required_interventions = get_required_interventions_for_today()
    if #required_interventions == 0 then
        return true -- No required interventions, so all are "completed"
    end
    
    local today = os.date("%Y-%m-%d")
    local logs = get_daily_logs(today)
    
    for _, required_intervention in ipairs(required_interventions) do
        if not logs.interventions[required_intervention] or logs.interventions[required_intervention] == 0 then
            return false -- This required intervention hasn't been logged
        end
    end
    
    return true
end

function get_energy_button_color()
    local today = os.date("%Y-%m-%d")
    local logs = get_daily_logs(today)
    
    if not logs.energy_levels or #logs.energy_levels == 0 then
        -- Never logged today - red
        return "#dc3545"
    end
    
    -- Find the most recent energy log
    local most_recent_time = 0
    for _, entry in ipairs(logs.energy_levels) do
        if entry.timestamp and entry.timestamp > most_recent_time then
            most_recent_time = entry.timestamp
        end
    end
    
    if most_recent_time == 0 then
        -- No valid timestamps - red
        return "#dc3545"
    end
    
    local current_time = os.time()
    local hours_since_last = (current_time - most_recent_time) / 3600
    
    if hours_since_last >= 4 then
        -- 4+ hours since last log - yellow
        return "#ffc107"
    else
        -- Logged within 4 hours - green
        return "#28a745"
    end
end

function render_widget()
    local today = get_current_day()
    local day_display = today:gsub("^%l", string.upper)  -- Capitalize first letter
    
    ui:set_title("Long Covid Pacing - " .. day_display)
    
    -- Build Rich UI
    local ui_elements = {}
    
    -- Add capacity level buttons (always centered)
    for i, level in ipairs(levels) do
        local color
        local button_text
        local gravity = nil
        
        if i == selected_level then
            color = level.color  -- Highlight selected
            button_text = "%%fa:" .. level.icon .. "%% " .. level.name  -- Icon + text for selected
        elseif selected_level == 0 then
            color = level.color  -- All available when none selected
            button_text = "%%fa:" .. level.icon .. "%% " .. level.name  -- Icon + text when all available
        else
            color = "#888888"  -- Dimmed for unavailable
            button_text = "fa:" .. level.icon  -- Icon only for unavailable
        end
        
        -- Always center the capacity buttons
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
    
    -- Add new line for second row of buttons
    table.insert(ui_elements, {"new_line", 1})
    
    -- Determine button colors based on completion and timing
    local activity_color = are_all_required_activities_completed() and "#28a745" or "#dc3545" -- Green or Red
    local intervention_color = are_all_required_interventions_completed() and "#007bff" or "#dc3545" -- Blue or Red
    local energy_color = get_energy_button_color() -- Red/Yellow/Green based on timing
    
    -- First group: Health tracking (left side, centered)
    table.insert(ui_elements, {"button", "fa:heart-pulse", {color = "#6c757d", gravity = "center_h"}})
    table.insert(ui_elements, {"button", "fa:bolt-lightning", {color = energy_color, gravity = "anchor_prev"}})
    
    -- Add spacing between groups
    table.insert(ui_elements, {"spacer", 3})
    
    -- Second group: Activity and intervention logging (right side)
    table.insert(ui_elements, {"button", "fa:running", {color = activity_color, gravity = "anchor_prev"}})
    table.insert(ui_elements, {"button", "fa:pills", {color = intervention_color, gravity = "anchor_prev"}})

    ui:set_expandable(true)
    
    -- Add plan details if expanded
    if ui:is_expanded() then
        table.insert(ui_elements, {"new_line", 2})
        
        if selected_level == 0 then
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
                table.insert(ui_elements, {"text", "<b>Selected:</b> " .. levels[selected_level].name, {size = 18}})
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
    
    local level_key = levels[selected_level].key
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
    if not daily_capacity_log then
        daily_capacity_log = {}
    end
    
    daily_capacity_log[today] = {
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
        cached_activities = nil
        cached_interventions = nil
        cached_required_activities = nil
        cached_required_interventions = nil
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
    current_dialog_type = "symptom"
    local symptoms = parse_symptoms_file()
    local formatted_symptoms = format_list_items(symptoms, "symptom")
    dialogs:show_list_dialog({
        title = "Log Symptom",
        lines = formatted_symptoms,
        search = true,
        zebra = true
    })
end

function log_symptom(symptom_name)
    local timestamp = os.date("%Y-%m-%d %H:%M:%S")
    
    -- Track locally with count
    log_item("symptom", symptom_name)
    
    -- Send to AutoSheets via Tasker
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
    
    -- Re-open the symptom dialog to show updated counts
    if current_dialog_type == "symptom" or current_dialog_type == "symptom_edit" then
        show_symptom_dialog()
    end
end

function show_activity_dialog()
    current_dialog_type = "activity"
    local activities = parse_activities_file()
    local formatted_activities = format_list_items(activities, "activity")
    dialogs:show_list_dialog({
        title = "Log Activity",
        lines = formatted_activities,
        search = true,
        zebra = true
    })
end

function log_activity(activity_name)
    local timestamp = os.date("%Y-%m-%d %H:%M:%S")
    
    -- Track locally with count
    log_item("activity", activity_name)
    
    -- Send to AutoSheets via Tasker
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
    
    -- Re-open the activity dialog to show updated counts
    if current_dialog_type == "activity" or current_dialog_type == "activity_edit" then
        show_activity_dialog()
    end
end

function show_intervention_dialog()
    current_dialog_type = "intervention"
    local interventions = parse_interventions_file()
    local formatted_interventions = format_list_items(interventions, "intervention")
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
    dialogs:show_radio_dialog({
        title = "Log Energy Level",
        lines = energy_levels,
        selected = -1  -- No initial selection
    })
end

function log_intervention(intervention_name)
    local timestamp = os.date("%Y-%m-%d %H:%M:%S")
    
    -- Track locally with count
    log_item("intervention", intervention_name)
    
    -- Send to AutoSheets via Tasker
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
    
    -- Re-open the intervention dialog to show updated counts
    if current_dialog_type == "intervention" or current_dialog_type == "intervention_edit" then
        show_intervention_dialog()
    end
end

function log_energy(energy_level)
    local timestamp = os.date("%Y-%m-%d %H:%M:%S")
    local today = os.date("%Y-%m-%d")
    local logs = get_daily_logs(today)
    
    -- Store energy level with timestamp
    local energy_entry = {
        level = energy_level,
        timestamp = os.time(),
        time_display = os.date("%H:%M")
    }
    
    table.insert(logs.energy_levels, energy_entry)
    
    -- Save changes back to prefs immediately
    save_prefs_data()
    
    -- Send to AutoSheets via Tasker
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
    
    -- Re-render widget to update button color
    render_widget()
end

function extract_item_name(formatted_item)
    -- Extract original item name from formatted string
    -- Handle: "✓ Fatigue (2)" -> "Fatigue" or "   Headache" -> "Headache"
    
    -- First, remove checkmark and leading spaces
    local cleaned = formatted_item:gsub("^[✓%s]*", "")
    
    -- Then extract name before count if present
    -- This regex matches only the LAST (number) pattern, preserving existing brackets:
    -- "Fatigue (2)" -> "Fatigue"
    -- "Physio (full) (2)" -> "Physio (full)"
    local item_name = cleaned:match("^(.+)%s%(%d+%)$")
    return item_name or cleaned -- Return cleaned version if no count found
end

function on_dialog_action(result)
    if result == -1 then
        -- Dialog was cancelled
        if current_dialog_type == "symptom" or current_dialog_type == "activity" or current_dialog_type == "intervention" or current_dialog_type == "energy" then
            -- Main list dialog was cancelled, clear completely
            current_dialog_type = nil
        end
        -- If we're in edit mode (symptom_edit/activity_edit/intervention_edit), keep the state
        -- because the list dialog closing doesn't mean the edit dialog was cancelled
        return true  -- Close dialog on cancel
    end
    
    if type(result) == "number" then
        -- List dialog result
        if current_dialog_type == "symptom" then
            local symptoms = parse_symptoms_file()
            local formatted_symptoms = format_list_items(symptoms, "symptom")
            local selected_formatted = formatted_symptoms[result]
            local selected_item = extract_item_name(selected_formatted)
            
            if selected_item == "Other..." then
                -- Show edit dialog for custom symptom
                current_dialog_type = "symptom_edit"  -- Change to indicate edit mode
                dialogs:show_edit_dialog("Custom Symptom", "Enter symptom name:", "")
                return true  -- Close list dialog
            else
                -- Log the selected symptom
                log_symptom(selected_item)
                -- Keep current_dialog_type so "Other..." still works
                return true  -- Close dialog
            end
        elseif current_dialog_type == "activity" then
            local activities = parse_activities_file()
            local formatted_activities = format_list_items(activities, "activity")
            local selected_formatted = formatted_activities[result]
            local selected_item = extract_item_name(selected_formatted)
            
            if selected_item == "Other..." then
                -- Show edit dialog for custom activity
                current_dialog_type = "activity_edit"  -- Change to indicate edit mode
                dialogs:show_edit_dialog("Custom Activity", "Enter activity name:", "")
                return true  -- Close list dialog
            else
                -- Log the selected activity
                log_activity(selected_item)
                -- Keep current_dialog_type so "Other..." still works
                return true  -- Close dialog
            end
        elseif current_dialog_type == "intervention" then
            local interventions = parse_interventions_file()
            local formatted_interventions = format_list_items(interventions, "intervention")
            local selected_formatted = formatted_interventions[result]
            local selected_item = extract_item_name(selected_formatted)
            
            if selected_item == "Other..." then
                -- Show edit dialog for custom intervention
                current_dialog_type = "intervention_edit"  -- Change to indicate edit mode
                dialogs:show_edit_dialog("Custom Intervention", "Enter intervention name:", "")
                return true  -- Close list dialog
            else
                -- Log the selected intervention
                log_intervention(selected_item)
                -- Keep current_dialog_type so "Other..." still works
                return true  -- Close dialog
            end
        elseif current_dialog_type == "energy" then
            -- Energy level logging - extract the number from "1 - Completely drained"
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
            return true  -- Close dialog
        end
    elseif type(result) == "string" then
        -- Edit dialog result - custom text
        if result ~= "" then
            if current_dialog_type == "symptom_edit" then
                current_dialog_type = "symptom"  -- Set to main state before logging
                log_symptom(result)  -- This will re-open the dialog
            elseif current_dialog_type == "activity_edit" then
                current_dialog_type = "activity"  -- Set to main state before logging
                log_activity(result)  -- This will re-open the dialog
            elseif current_dialog_type == "intervention_edit" then
                current_dialog_type = "intervention"  -- Set to main state before logging
                log_intervention(result)  -- This will re-open the dialog
            end
        else
            -- Empty result, go back to main dialog state and re-open
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
        return true  -- Close edit dialog
    end
end