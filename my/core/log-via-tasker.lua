-- log-via-tasker.lua - Enhanced Tasker logging module with 4-column support
-- Extends the existing 3-column logging to support timestamp, event, value, detail

local M = {}

-- Log data to spreadsheet via Tasker with 4-column support
-- Parameters:
--   timestamp - Date/time string (YYYY-MM-DD HH:MM:SS format)
--   event - Event type (e.g., "Capacity", "Symptom", "Activity", "Intervention", "Energy", "Note")
--   value - Primary value (e.g., level name, item name, energy level)
--   detail - Optional additional information (e.g., severity, options, notes)
--   ui_callback - Function to call for user feedback (required)
function M.log_to_spreadsheet(timestamp, event, value, detail, ui_callback)
    -- Input validation
    if not ui_callback or type(ui_callback) ~= "function" then
        error("ui_callback is required and must be a function")
    end

    if not timestamp or type(timestamp) ~= "string" then
        ui_callback("Error: Invalid timestamp")
        return false
    end

    if not event or type(event) ~= "string" then
        ui_callback("Error: Invalid event type")
        return false
    end

    if not value then
        ui_callback("Error: Invalid value")
        return false
    end

    -- Convert value to string
    local value_str = tostring(value)

    -- Detail is optional, convert to string if provided, ensure it's never nil
    local detail_str = (detail and tostring(detail) ~= "") and tostring(detail) or ""

    if not tasker then
        ui_callback("Tasker not available")
        return false
    end

    -- Call Tasker with 4-column data
    local success, error_msg = pcall(function()
        tasker:run_task("LongCovid_LogEvent4Col", {
            timestamp = timestamp,
            event = event,
            value = value_str,
            detail = detail_str
        })
    end)

    if not success then
        ui_callback("Error logging to Tasker: " .. tostring(error_msg))
        return false
    end

    local message = "✓ Logged to spreadsheet: " .. event
    if detail_str ~= "" then
        message = message .. " (detail: " .. detail_str .. ")"
    end
    ui_callback(message)

    return true
end

return M