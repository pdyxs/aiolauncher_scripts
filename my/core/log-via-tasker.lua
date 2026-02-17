-- log-via-tasker.lua - Enhanced Tasker logging module with 4-column support
-- Extends the existing 3-column logging to support timestamp, event, value, detail

local M = {}
local time_utils = require "core.time-utils"
local util = require "core.util"
local prefs = require "prefs"

-- Log data to spreadsheet via Tasker with 4-column support
-- Parameters:
--   event - Event type (e.g., "Capacity", "Symptom", "Activity", "Intervention", "Energy", "Note")
--   value - Primary value (e.g., level name, item name, energy level)
--   detail - Optional additional information (e.g., severity, options, notes)
--   ui_callback - Function to call for user feedback (optional)
function M.log_to_spreadsheet(event, ui_callback)
    return M.log_events_to_spreadsheet({ event }, ui_callback)
end

function M.log_events_to_spreadsheet(events, ui_callback)
    ui_callback = ui_callback or function(message) ui:show_toast(message) end

    local timestamp = os.date("%Y-%m-%d %H:%M:%S")

    local data = map(function(event)
        return map(tostring, event)
    end, events)

    local str = table.concat(
        map(function(event)
            return timestamp .. "¦" .. table.concat(event, "¦")
        end, events),
        "\n"
    )

    if not tasker then
        ui_callback("Tasker not available")
        return false
    end

    local success, error_msg = pcall(function()
        tasker:run_task("LongCovid_Log", {
            data = str
        })
    end)

    if not success then
        ui_callback("Error logging to Tasker: " .. tostring(error_msg))
        return false
    end

    local message = "✓ Logged:"
    for k, event in pairs(data) do
        message = message .. "\n" .. table.concat(event, " - ")
    end
    M.store_logs(data)

    ui_callback(message)
end

function M.store_ignore(event, value, detail)
    local logs = prefs.logs or {}

    if not logs[event] then
        logs[event] = { count = 0, values = {} }
    end

    if not logs[event].values[value] then
        logs[event].values[value] = { count = 0, details = {} }
    end

    if detail ~= "" and detail ~= nil then
        if not logs[event].values[value].details then
            logs[event].values[value].details = {}
        end

        if not logs[event].values[value].details[detail] then
            logs[event].values[value].details[detail] = { count = 0 }
        end

        logs[event].values[value].details[detail].last_ignored = time_utils.get_current_timestamp()
    else
        logs[event].values[value].last_ignored = time_utils.get_current_timestamp()
    end

    prefs.logs = logs
end

function M.store_log(event, value, detail)
    local logs = prefs.logs or {}

    if not logs[event] then
        logs[event] = { count = 0, values = {} }
    end

    logs[event].count = (logs[event].count or 0) + 1
    logs[event].last_logged = time_utils.get_current_timestamp()
    logs[event].last_value = value

    if not logs[event].values[value] then
        logs[event].values[value] = { count = 0, details = {} }
    end

    logs[event].values[value].count = (logs[event].values[value].count or 0) + 1
    logs[event].values[value].last_logged = time_utils.get_current_timestamp()

    if detail ~= "" and detail ~= nil then
        logs[event].values[value].last_detail = detail

        if not logs[event].values[value].details then
            logs[event].values[value].details = {}
        end

        if not logs[event].values[value].details[detail] then
            logs[event].values[value].details[detail] = { count = 0 }
        end

        logs[event].values[value].details[detail].count = (logs[event].values[value].details[detail].count or 0) + 1
        logs[event].values[value].details[detail].last_logged = time_utils.get_current_timestamp()
    end

    prefs.logs = logs
end

function M.store_logs(events)
    local logs = prefs.logs or {}
    local seen_events = {}
    local seen_values = {}
    local timestamp = time_utils.get_current_timestamp()

    for _, event_data in ipairs(events) do
        local event, value, detail = event_data[1], event_data[2], event_data[3]

        if not logs[event] then
            logs[event] = { count = 0, values = {} }
        end

        if not seen_events[event] then
            logs[event].count = (logs[event].count or 0) + 1
            seen_events[event] = true
        end
        logs[event].last_logged = timestamp
        logs[event].last_value = value

        if not logs[event].values[value] then
            logs[event].values[value] = { count = 0, details = {} }
        end

        local value_key = event .. "\0" .. value
        if not seen_values[value_key] then
            logs[event].values[value].count = (logs[event].values[value].count or 0) + 1
            seen_values[value_key] = true
        end
        logs[event].values[value].last_logged = timestamp

        if detail ~= "" and detail ~= nil then
            logs[event].values[value].last_detail = detail

            if not logs[event].values[value].details then
                logs[event].values[value].details = {}
            end

            if not logs[event].values[value].details[detail] then
                logs[event].values[value].details[detail] = { count = 0 }
            end

            logs[event].values[value].details[detail].count = (logs[event].values[value].details[detail].count or 0) + 1
            logs[event].values[value].details[detail].last_logged = timestamp
        end
    end

    prefs.logs = logs
end

function M.last_ignored(event, value, detail)
    if prefs.logs == nil or prefs.logs[event] == nil then
        return 0
    end

    if value == nil or prefs.logs[event].values[value] == nil then
        return 0
    end

    if detail == nil or detail == "" then
        return prefs.logs[event].values[value].last_ignored
    end

    if prefs.logs[event].values[value].details == nil or prefs.logs[event].values[value].details[detail] == nil then
        return 0
    end

    return prefs.logs[event].values[value].details[detail].last_ignored
end

function M.log_count(event, value)
    if prefs.logs == nil or prefs.logs[event] == nil then
        return 0
    end

    if value == nil then
        return prefs.logs[event].count
    end

    if prefs.logs[event].values[value] == nil then
        return 0
    end
    return prefs.logs[event].values[value].count
end

function M.last_logged(event, value, detail)
    if prefs.logs == nil or prefs.logs[event] == nil then
        return 0
    end

    if value == nil then
        return prefs.logs[event].last_logged
    end

    if prefs.logs[event].values[value] == nil then
        return 0
    end

    if detail == nil then
        return prefs.logs[event].values[value].last_logged
    end

    if prefs.logs[event].values[value].details == nil or prefs.logs[event].values[value].details[detail] == nil then
        return 0
    end

    return prefs.logs[event].values[value].details[detail].last_logged
end

function M.last_value(event)
    if prefs.logs == nil or prefs.logs[event] == nil then
        return nil
    end
    return prefs.logs[event].last_value
end

function M.last_detail(event, value)
    if prefs.logs == nil or prefs.logs[event] == nil or prefs.logs[event].values[value] == nil then
        return nil
    end
    return prefs.logs[event].values[value].last_detail
end

return M
