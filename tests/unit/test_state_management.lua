local test = require "test_framework"

-- Load the state management module
local state = require "long_covid_state"

-- Mock date_utils for consistent testing
local date_utils = require "long_covid_date"
local original_get_today_date = date_utils.get_today_date
local original_get_date_days_ago = date_utils.get_date_days_ago

-- Initialize state module with mock levels
local mock_levels = {
    {name = "Recovering", color = "#FF4444", key = "red", icon = "bed"},
    {name = "Maintaining", color = "#FFAA00", key = "yellow", icon = "walking"}, 
    {name = "Engaging", color = "#44AA44", key = "green", icon = "rocket-launch"}
}
state.init(mock_levels)

-- Test get_daily_logs function
test.add_test("get_daily_logs creates new log structure", function()
    local daily_logs = {}
    local logs = state.get_daily_logs(daily_logs, "2023-08-30")
    
    test.assert_true(logs.symptoms ~= nil, "Should create symptoms category")
    test.assert_true(logs.activities ~= nil, "Should create activities category")
    test.assert_true(logs.interventions ~= nil, "Should create interventions category")
    test.assert_true(logs.energy_levels ~= nil, "Should create energy_levels category")
    test.assert_equals(0, #logs.energy_levels, "Energy levels should start empty")
end)

test.add_test("get_daily_logs handles nil daily_logs", function()
    local logs = state.get_daily_logs(nil, "2023-08-30")
    
    test.assert_true(logs ~= nil, "Should create logs structure for nil input")
    test.assert_true(logs.symptoms ~= nil, "Should create symptoms category")
end)

test.add_test("get_daily_logs adds backward compatibility for energy_levels", function()
    local daily_logs = {
        ["2023-08-30"] = {
            symptoms = {},
            activities = {},
            interventions = {}
            -- Missing energy_levels
        }
    }
    
    local logs = state.get_daily_logs(daily_logs, "2023-08-30")
    test.assert_true(logs.energy_levels ~= nil, "Should add missing energy_levels field")
    test.assert_equals(0, #logs.energy_levels, "Energy levels should start empty")
end)

-- Test log_item function
test.add_test("log_item adds item to correct category", function()
    local daily_logs = {}
    
    -- Mock today's date
    date_utils.get_today_date = function() return "2023-08-30" end
    
    local success = state.log_item(daily_logs, "activity", "Walk")
    test.assert_true(success, "Should successfully log item")
    
    local logs = state.get_daily_logs(daily_logs, "2023-08-30")
    test.assert_equals(1, logs.activities["Walk"], "Should log walk in activities")
    
    -- Log same item again
    state.log_item(daily_logs, "activity", "Walk")
    test.assert_equals(2, logs.activities["Walk"], "Should increment count for same item")
    
    -- Restore original function
    date_utils.get_today_date = original_get_today_date
end)

test.add_test("log_item handles different item types", function()
    local daily_logs = {}
    
    -- Mock today's date
    date_utils.get_today_date = function() return "2023-08-30" end
    
    state.log_item(daily_logs, "symptom", "Fatigue")
    state.log_item(daily_logs, "activity", "Exercise")
    state.log_item(daily_logs, "intervention", "Medication")
    
    local logs = state.get_daily_logs(daily_logs, "2023-08-30")
    test.assert_equals(1, logs.symptoms["Fatigue"], "Should log symptom")
    test.assert_equals(1, logs.activities["Exercise"], "Should log activity")
    test.assert_equals(1, logs.interventions["Medication"], "Should log intervention")
    
    -- Restore original function
    date_utils.get_today_date = original_get_today_date
end)

test.add_test("log_item handles invalid item type", function()
    local daily_logs = {}
    
    local success, error_msg = state.log_item(daily_logs, "invalid", "Test")
    test.assert_equals(nil, success, "Should return nil for invalid type")
    test.assert_contains(error_msg, "Invalid item type", "Should return error message")
end)

-- Test log_energy function
test.add_test("log_energy adds energy entry", function()
    local daily_logs = {}
    
    -- Mock today's date and time
    date_utils.get_today_date = function() return "2023-08-30" end
    local original_os_time = os.time
    local original_os_date = os.date
    os.time = function() return 1693400000 end
    os.date = function(fmt) if fmt == "%H:%M" then return "14:30" else return original_os_date(fmt) end end
    
    local success = state.log_energy(daily_logs, 7)
    test.assert_true(success, "Should successfully log energy")
    
    local logs = state.get_daily_logs(daily_logs, "2023-08-30")
    test.assert_equals(1, #logs.energy_levels, "Should have one energy entry")
    test.assert_equals(7, logs.energy_levels[1].level, "Should store correct energy level")
    test.assert_equals(1693400000, logs.energy_levels[1].timestamp, "Should store timestamp")
    test.assert_equals("14:30", logs.energy_levels[1].time_display, "Should store time display")
    
    -- Restore original functions
    date_utils.get_today_date = original_get_today_date
    os.time = original_os_time
    os.date = original_os_date
end)

-- Test get_energy_button_color function
test.add_test("get_energy_button_color returns red for no logs", function()
    local daily_logs = {}
    
    -- Mock today's date
    date_utils.get_today_date = function() return "2023-08-30" end
    
    local color = state.get_energy_button_color(daily_logs)
    test.assert_equals("#dc3545", color, "Should return red for no energy logs")
    
    -- Restore original function
    date_utils.get_today_date = original_get_today_date
end)

test.add_test("get_energy_button_color returns green for recent logs", function()
    local daily_logs = {}
    
    -- Mock today's date and current time (1 hour after log)
    date_utils.get_today_date = function() return "2023-08-30" end
    local original_os_time = os.time
    
    -- Add energy log 1 hour ago
    os.time = function() return 1693400000 end
    state.log_energy(daily_logs, 8)
    
    -- Current time (1 hour later)
    os.time = function() return 1693403600 end -- +3600 seconds = 1 hour
    
    local color = state.get_energy_button_color(daily_logs)
    test.assert_equals("#28a745", color, "Should return green for recent log")
    
    -- Restore original functions
    date_utils.get_today_date = original_get_today_date
    os.time = original_os_time
end)

test.add_test("get_energy_button_color returns yellow for old logs", function()
    local daily_logs = {}
    
    -- Mock today's date and current time (5 hours after log)
    date_utils.get_today_date = function() return "2023-08-30" end
    local original_os_time = os.time
    
    -- Add energy log 5 hours ago
    os.time = function() return 1693400000 end
    state.log_energy(daily_logs, 6)
    
    -- Current time (5 hours later)
    os.time = function() return 1693418000 end -- +18000 seconds = 5 hours
    
    local color = state.get_energy_button_color(daily_logs)
    test.assert_equals("#ffc107", color, "Should return yellow for old log")
    
    -- Restore original functions
    date_utils.get_today_date = original_get_today_date
    os.time = original_os_time
end)

-- Test save_daily_choice function
test.add_test("save_daily_choice saves capacity choice", function()
    local daily_capacity_log = {}
    
    -- Mock today's date and time
    date_utils.get_today_date = function() return "2023-08-30" end
    local original_os_date = os.date
    os.date = function(fmt) if fmt == "%H:%M" then return "09:15" else return original_os_date(fmt) end end
    
    local updated_log = state.save_daily_choice(daily_capacity_log, 2)
    
    test.assert_true(updated_log["2023-08-30"] ~= nil, "Should create entry for today")
    test.assert_equals(2, updated_log["2023-08-30"].capacity, "Should store capacity index")
    test.assert_equals("Maintaining", updated_log["2023-08-30"].capacity_name, "Should store capacity name")
    test.assert_equals("09:15", updated_log["2023-08-30"].timestamp, "Should store time")
    
    -- Restore original functions
    date_utils.get_today_date = original_get_today_date
    os.date = original_os_date
end)

test.add_test("save_daily_choice handles level 0 (no selection)", function()
    local daily_capacity_log = {existing = "data"}
    
    local updated_log = state.save_daily_choice(daily_capacity_log, 0)
    test.assert_equals(daily_capacity_log, updated_log, "Should return unchanged log for level 0")
end)


-- Test purge_old_daily_logs function
test.add_test("purge_old_daily_logs keeps recent logs", function()
    local daily_logs = {
        ["2023-07-01"] = {activities = {}}, -- Very old
        ["2023-08-15"] = {activities = {}}, -- Recent enough
        ["2023-08-30"] = {activities = {}}  -- Today
    }
    
    -- Mock date functions
    date_utils.get_date_days_ago = function(days) 
        if days == 30 then return "2023-08-01" end
        return original_get_date_days_ago(days)
    end
    
    local purged = state.purge_old_daily_logs(daily_logs, "2023-08-30")
    
    test.assert_equals(nil, purged["2023-07-01"], "Should remove old logs")
    test.assert_true(purged["2023-08-15"] ~= nil, "Should keep recent logs")
    test.assert_true(purged["2023-08-30"] ~= nil, "Should keep today's logs")
    
    -- Restore original function
    date_utils.get_date_days_ago = original_get_date_days_ago
end)

test.add_test("purge_old_daily_logs handles nil input", function()
    local purged = state.purge_old_daily_logs(nil, "2023-08-30")
    test.assert_true(type(purged) == "table", "Should return empty table for nil input")
end)

-- Test check_daily_reset function
test.add_test("check_daily_reset detects new day", function()
    local daily_logs = {["2023-08-29"] = {activities = {}}}
    
    -- Mock date functions
    date_utils.get_today_date = function() return "2023-08-30" end
    date_utils.get_date_days_ago = function(days) 
        if days == 30 then return "2023-08-01" end
        return original_get_date_days_ago(days)
    end
    
    local changes = state.check_daily_reset("2023-08-29", 2, {}, daily_logs)
    
    test.assert_equals(0, changes.selected_level, "Should reset to no selection")
    test.assert_equals("2023-08-30", changes.last_selection_date, "Should update to today")
    test.assert_true(changes.daily_logs ~= nil, "Should purge old logs")
    
    -- Restore original functions
    date_utils.get_today_date = original_get_today_date
    date_utils.get_date_days_ago = original_get_date_days_ago
end)

test.add_test("check_daily_reset handles same day", function()
    local daily_capacity_log = {["2023-08-30"] = {capacity = 3}}
    
    -- Mock today's date
    date_utils.get_today_date = function() return "2023-08-30" end
    
    local changes = state.check_daily_reset("2023-08-30", 1, daily_capacity_log, {})
    
    test.assert_equals(3, changes.selected_level, "Should restore saved selection")
    test.assert_equals(nil, changes.last_selection_date, "Should not change date")
    
    -- Restore original function
    date_utils.get_today_date = original_get_today_date
end)

if ... == nil then
    test.run_tests("State Management Tests")
    local success = test.print_final_results()
    os.exit(success and 0 or 1)
end