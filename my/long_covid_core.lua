-- long_covid_core.lua - Core business logic for Long Covid Pacing Widget
-- This module contains all the business logic that can be tested independently

local M = {}

-- Capacity levels
M.levels = {
    {name = "Recovering", color = "#FF4444", key = "red", icon = "bed"},
    {name = "Maintaining", color = "#FFAA00", key = "yellow", icon = "walking"}, 
    {name = "Engaging", color = "#44AA44", key = "green", icon = "rocket-launch"}
}

-- Helper function to split text into lines
function M.split_lines(text)
    local lines = {}
    for line in text:gmatch("[^\r\n]+") do
        table.insert(lines, line)
    end
    return lines
end

function M.get_current_day()
    local day_names = {"sunday", "monday", "tuesday", "wednesday", "thursday", "friday", "saturday"}
    local today = day_names[tonumber(os.date("%w")) + 1]
    return today
end

function M.get_current_day_abbrev()
    local day_abbrevs = {"sun", "mon", "tue", "wed", "thu", "fri", "sat"}
    return day_abbrevs[tonumber(os.date("%w")) + 1]
end

function M.check_daily_reset(last_selection_date, selected_level, daily_capacity_log, daily_logs)
    local today = os.date("%Y-%m-%d")
    local changes = {}
    
    if last_selection_date ~= today then
        -- New day - reset to no selection
        changes.selected_level = 0
        changes.last_selection_date = today
        changes.daily_logs = M.purge_old_daily_logs(daily_logs, today)
    else
        -- Same day - check if we have a stored selection
        if daily_capacity_log and daily_capacity_log[today] then
            changes.selected_level = daily_capacity_log[today].capacity
        end
    end
    
    return changes
end

function M.purge_old_daily_logs(daily_logs, today)
    if not daily_logs then
        daily_logs = {}
    end
    
    -- Keep only today's entry, remove all others for performance
    local today_logs = daily_logs[today]
    local new_daily_logs = {}
    
    -- Initialize today's logs if needed
    if not today_logs then
        new_daily_logs[today] = {
            symptoms = {},
            activities = {},
            interventions = {},
            energy_levels = {}
        }
    else
        new_daily_logs[today] = today_logs
    end
    
    return new_daily_logs
end

function M.get_daily_logs(daily_logs, date)
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

function M.log_item(daily_logs, item_type, item_name)
    local today = os.date("%Y-%m-%d")
    local logs = M.get_daily_logs(daily_logs, today)
    
    local category
    if item_type == "symptom" then
        category = logs.symptoms
    elseif item_type == "activity" then
        category = logs.activities
    elseif item_type == "intervention" then
        category = logs.interventions
    else
        return nil, "Invalid item type: " .. tostring(item_type)
    end
    
    category[item_name] = (category[item_name] or 0) + 1
    return true
end

function M.log_energy(daily_logs, energy_level)
    local today = os.date("%Y-%m-%d")
    local logs = M.get_daily_logs(daily_logs, today)
    
    local energy_entry = {
        level = energy_level,
        timestamp = os.time(),
        time_display = os.date("%H:%M")
    }
    
    table.insert(logs.energy_levels, energy_entry)
    return true
end

function M.get_energy_button_color(daily_logs)
    local today = os.date("%Y-%m-%d")
    local logs = M.get_daily_logs(daily_logs, today)
    
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

function M.parse_decision_criteria(content)
    if not content then
        return {red = {}, yellow = {}, green = {}}
    end
    
    local criteria = {red = {}, yellow = {}, green = {}}
    local current_level = nil
    
    local lines = M.split_lines(content)
    for _, line in ipairs(lines) do
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

function M.parse_day_file(content)
    if not content then
        return {red = {}, yellow = {}, green = {}}
    end
    
    local template = {red = {}, yellow = {}, green = {}}
    local current_level = nil
    local current_category = nil
    
    local lines = M.split_lines(content)
    for _, line in ipairs(lines) do
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

function M.parse_symptoms_file(content)
    if not content then
        return {
            "Fatigue",
            "Brain fog", 
            "Headache",
            "Shortness of breath",
            "Joint pain",
            "Muscle aches",
            "Sleep issues",
            "Other..."
        }
    end
    
    local symptoms = {}
    local lines = M.split_lines(content)
    
    for _, line in ipairs(lines) do
        if line:match("^%- ") then
            local symptom = line:match("^%- (.+)")
            if symptom then
                table.insert(symptoms, symptom)
            end
        end
    end
    
    -- Always add "Other..." as the last option
    table.insert(symptoms, "Other...")
    
    return symptoms
end

function M.parse_activities_file(content)
    if not content then
        return {
            "Light walk",
            "Desk work",
            "Cooking",
            "Reading",
            "Social visit",
            "Rest/nap",
            "Other..."
        }
    end
    
    local activities = {}
    local lines = M.split_lines(content)
    
    for _, line in ipairs(lines) do
        if line:match("^%- ") then
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
    
    return activities
end

function M.parse_interventions_file(content)
    if not content then
        return {
            "Vitamin D",
            "Vitamin B12",
            "Magnesium",
            "Extra rest",
            "Breathing exercises",
            "Meditation",
            "Other..."
        }
    end
    
    local interventions = {}
    local lines = M.split_lines(content)
    
    for _, line in ipairs(lines) do
        if line:match("^%- ") then
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
    
    return interventions
end

function M.parse_required_activities(content)
    if not content then
        return {}
    end
    
    local required_activities = {}
    local lines = M.split_lines(content)
    
    for _, line in ipairs(lines) do
        if line:match("^%- ") then
            local activity_line = line:match("^%- (.+)")
            if activity_line and activity_line:match("%{Required") then
                local activity_name = activity_line:match("^(.-)%s*%{Required")
                if activity_name then
                    local required_info = {
                        name = activity_name,
                        days = nil
                    }
                    
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
    
    return required_activities
end

function M.parse_required_interventions(content)
    if not content then
        return {}
    end
    
    local required_interventions = {}
    local lines = M.split_lines(content)
    
    for _, line in ipairs(lines) do
        if line:match("^%- ") then
            local intervention_line = line:match("^%- (.+)")
            if intervention_line and intervention_line:match("%{Required") then
                local intervention_name = intervention_line:match("^(.-)%s*%{Required")
                if intervention_name then
                    local required_info = {
                        name = intervention_name,
                        days = nil
                    }
                    
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
    
    return required_interventions
end

function M.is_required_today(required_info)
    if not required_info.days then
        return true
    end
    
    local today_abbrev = M.get_current_day_abbrev()
    for _, day in ipairs(required_info.days) do
        if day == today_abbrev then
            return true
        end
    end
    
    return false
end

function M.get_required_activities_for_today(required_activities)
    local today_required = {}
    
    for _, required_info in ipairs(required_activities) do
        if M.is_required_today(required_info) then
            table.insert(today_required, required_info.name)
        end
    end
    
    return today_required
end

function M.get_required_interventions_for_today(required_interventions)
    local today_required = {}
    
    for _, required_info in ipairs(required_interventions) do
        if M.is_required_today(required_info) then
            table.insert(today_required, required_info.name)
        end
    end
    
    return today_required
end

function M.are_all_required_activities_completed(daily_logs, required_activities)
    local required_today = M.get_required_activities_for_today(required_activities)
    if #required_today == 0 then
        return true
    end
    
    local today = os.date("%Y-%m-%d")
    local logs = M.get_daily_logs(daily_logs, today)
    
    for _, required_activity in ipairs(required_today) do
        if not logs.activities[required_activity] or logs.activities[required_activity] == 0 then
            return false
        end
    end
    
    return true
end

function M.are_all_required_interventions_completed(daily_logs, required_interventions)
    local required_today = M.get_required_interventions_for_today(required_interventions)
    if #required_today == 0 then
        return true
    end
    
    local today = os.date("%Y-%m-%d")
    local logs = M.get_daily_logs(daily_logs, today)
    
    for _, required_intervention in ipairs(required_today) do
        if not logs.interventions[required_intervention] or logs.interventions[required_intervention] == 0 then
            return false
        end
    end
    
    return true
end

function M.format_list_items(items, item_type, daily_logs, required_activities, required_interventions)
    local today = os.date("%Y-%m-%d")
    local logs = M.get_daily_logs(daily_logs, today)
    
    local category
    local required_items = {}
    if item_type == "symptom" then
        category = logs.symptoms
    elseif item_type == "activity" then
        category = logs.activities
        required_items = M.get_required_activities_for_today(required_activities or {})
    elseif item_type == "intervention" then
        category = logs.interventions
        required_items = M.get_required_interventions_for_today(required_interventions or {})
    else
        return items
    end
    
    local required_set = {}
    for _, req_item in ipairs(required_items) do
        required_set[req_item] = true
    end
    
    local formatted = {}
    for _, item in ipairs(items) do
        local count = category[item]
        local is_required = required_set[item]
        
        if count and count > 0 then
            if is_required then
                table.insert(formatted, "✅ " .. item .. " (" .. count .. ")")
            else
                table.insert(formatted, "✓ " .. item .. " (" .. count .. ")")
            end
        else
            if is_required then
                table.insert(formatted, "⚠️ " .. item)
            else
                table.insert(formatted, "   " .. item)
            end
        end
    end
    
    return formatted
end

function M.extract_item_name(formatted_item)
    -- First, remove all icons, checkmarks and leading spaces
    local cleaned = formatted_item:gsub("^[✓✅⚠️%s]*", "")
    
    -- Then extract name before count if present: "Fatigue (2)" -> "Fatigue"
    -- This will only match the LAST (number) pattern, preserving existing brackets
    local item_name = cleaned:match("^(.+)%s%(%d+%)$")
    return item_name or cleaned -- Return cleaned version if no count found
end

function M.save_daily_choice(daily_capacity_log, level_idx)
    if level_idx == 0 then
        return daily_capacity_log
    end
    
    local today = os.date("%Y-%m-%d")
    local level_name = M.levels[level_idx].name
    
    if not daily_capacity_log then
        daily_capacity_log = {}
    end
    
    daily_capacity_log[today] = {
        capacity = level_idx,
        capacity_name = level_name,
        timestamp = os.date("%H:%M")
    }
    
    return daily_capacity_log
end

return M