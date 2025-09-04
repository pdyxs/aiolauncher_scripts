-- Long Covid Widget - State Management Module
-- Handles daily state, logging, and completion tracking

local M = {}

-- Dependencies
local date_utils = require "long_covid_date"

-- Need to reference capacity levels - will be injected by core module
M.levels = nil  -- Will be set during initialization

function M.check_daily_reset(last_selection_date, selected_level, daily_capacity_log, daily_logs)
    local today = date_utils.get_today_date()
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
    local today = date_utils.get_today_date()
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
    local today = date_utils.get_today_date()
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
    local today = date_utils.get_today_date()
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

function M.save_daily_choice(daily_capacity_log, level_idx)
    if level_idx == 0 then
        return daily_capacity_log
    end
    
    local today = date_utils.get_today_date()
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

-- Generic logging function with Tasker integration
function M.log_item_with_tasker(daily_logs, item_type, item_name, tasker_callback, ui_callback)
    local success, error_msg = pcall(function()
        local result, err = M.log_item(daily_logs, item_type, item_name)
        if not result then
            error(err or "Unknown error")
        end
        return result
    end)
    
    if not success then
        if ui_callback then
            ui_callback("Error logging " .. item_type .. ": " .. tostring(error_msg))
        end
        return false
    end
    
    local timestamp = os.date("%Y-%m-%d %H:%M:%S")
    local event_type = item_type:gsub("^%l", string.upper) -- Capitalize first letter
    
    if tasker_callback then
        tasker_callback({
            timestamp = timestamp,
            event_type = event_type,
            value = item_name
        })
    end
    
    if ui_callback then
        local message = "✓ " .. event_type .. " logged: " .. item_name
        ui_callback(message)
    end
    
    return true
end

function M.log_energy_with_tasker(daily_logs, energy_level, tasker_callback, ui_callback)
    local success, error_msg = pcall(function()
        local result = M.log_energy(daily_logs, energy_level)
        if not result then
            error("Failed to log energy")
        end
        return result
    end)
    
    if not success then
        if ui_callback then
            ui_callback("Error logging energy: " .. tostring(error_msg))
        end
        return false
    end
    
    local timestamp = os.date("%Y-%m-%d %H:%M:%S")
    
    if tasker_callback then
        tasker_callback({
            timestamp = timestamp,
            event_type = "Energy",
            value = tostring(energy_level)
        })
    end
    
    if ui_callback then
        local message = "✓ Energy level " .. tostring(energy_level) .. " logged"
        ui_callback(message)
    end
    
    return true
end


-- Clean up old daily logs to prevent unlimited growth
function M.purge_old_daily_logs(daily_logs, today)
    if not daily_logs then
        return {}
    end
    
    -- Keep last 30 days of logs for analysis
    local cutoff_date = date_utils.get_date_days_ago(30)
    local purged_logs = {}
    
    for date, logs in pairs(daily_logs) do
        if date >= cutoff_date then
            purged_logs[date] = logs
        end
    end
    
    return purged_logs
end

-- Initialize the module with capacity levels from core
function M.init(levels)
    M.levels = levels
end

return M