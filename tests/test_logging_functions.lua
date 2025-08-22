-- test_logging_functions.lua - Tests for consolidated logging functions
-- Tests Tasker integration, error handling, and callback mechanisms

-- Add paths for imports
package.path = package.path .. ";../my/?.lua;./?.lua"

local test = require "test_framework"
local data = require "test_data"
local core = require "long_covid_core"

test.add_test("Item logging with Tasker integration - success case", function()
    local daily_logs = {}
    local callbacks = data.create_mock_callbacks()
    
    local mock_date, original_date = data.mock_os_date("2023-01-01")
    os.date = mock_date
    
    local success = core.log_item_with_tasker(daily_logs, "symptom", "Fatigue", callbacks.tasker, callbacks.ui)
    
    os.date = original_date
    
    test.assert_true(success, "Should return success")
    test.assert_equals(2, #callbacks.calls, "Should make tasker and UI callbacks")
    
    -- Check Tasker callback
    local tasker_call = nil
    local ui_call = nil
    for _, call in ipairs(callbacks.calls) do
        if call.type == "tasker" then
            tasker_call = call
        elseif call.type == "ui" then
            ui_call = call
        end
    end
    
    test.assert_not_nil(tasker_call, "Should make Tasker callback")
    test.assert_equals("Symptom", tasker_call.params.event_type, "Should capitalize event type")
    test.assert_equals("Fatigue", tasker_call.params.value, "Should pass item value")
    test.assert_not_nil(tasker_call.params.timestamp, "Should include timestamp")
    
    test.assert_not_nil(ui_call, "Should make UI callback")
    test.assert_contains(ui_call.message, "Symptom logged: Fatigue", "Should show success message")
    
    -- Verify item was actually logged
    local today_logs = core.get_daily_logs(daily_logs, "2023-01-01")
    test.assert_equals(1, today_logs.symptoms["Fatigue"], "Should log item to daily logs")
end)

test.add_test("Item logging with different item types", function()
    local daily_logs = {}
    local callbacks = data.create_mock_callbacks()
    
    -- Test activity logging
    callbacks.calls = {}
    local success = core.log_item_with_tasker(daily_logs, "activity", "Light walk", callbacks.tasker, callbacks.ui)
    test.assert_true(success, "Should log activity successfully")
    
    local tasker_call = nil
    for _, call in ipairs(callbacks.calls) do
        if call.type == "tasker" then
            tasker_call = call
            break
        end
    end
    test.assert_not_nil(tasker_call, "Should make tasker call")
    test.assert_equals("Activity", tasker_call.params.event_type, "Should capitalize Activity")
    test.assert_equals("Light walk", tasker_call.params.value, "Should pass activity name")
    
    -- Test intervention logging
    callbacks.calls = {}
    success = core.log_item_with_tasker(daily_logs, "intervention", "LDN (4mg)", callbacks.tasker, callbacks.ui)
    test.assert_true(success, "Should log intervention successfully")
    
    tasker_call = nil
    for _, call in ipairs(callbacks.calls) do
        if call.type == "tasker" then
            tasker_call = call
            break
        end
    end
    test.assert_not_nil(tasker_call, "Should make tasker call")
    test.assert_equals("Intervention", tasker_call.params.event_type, "Should capitalize Intervention")
    test.assert_equals("LDN (4mg)", tasker_call.params.value, "Should pass intervention name")
end)

test.add_test("Item logging without Tasker callback", function()
    local daily_logs = {}
    local ui_messages = {}
    
    local ui_callback = function(message)
        table.insert(ui_messages, message)
    end
    
    local success = core.log_item_with_tasker(daily_logs, "symptom", "Headache", nil, ui_callback)
    
    test.assert_true(success, "Should succeed without Tasker callback")
    test.assert_equals(1, #ui_messages, "Should still call UI callback")
    test.assert_contains(ui_messages[1], "Symptom logged: Headache", "Should show success message")
end)

test.add_test("Item logging without UI callback", function()
    local daily_logs = {}
    local tasker_calls = {}
    
    local tasker_callback = function(params)
        table.insert(tasker_calls, params)
    end
    
    local success = core.log_item_with_tasker(daily_logs, "activity", "Work", tasker_callback, nil)
    
    test.assert_true(success, "Should succeed without UI callback")
    test.assert_equals(1, #tasker_calls, "Should still call Tasker callback")
end)

test.add_test("Item logging error handling", function()
    local ui_messages = {}
    
    local ui_callback = function(message)
        table.insert(ui_messages, message)
    end
    
    -- Pass invalid item type to trigger error
    local success = core.log_item_with_tasker({}, "invalid_type", "test", nil, ui_callback)
    
    test.assert_false(success, "Should return false on error")
    test.assert_equals(1, #ui_messages, "Should call UI callback with error")
    test.assert_contains(ui_messages[1], "Error logging", "Should show error message")
end)

test.add_test("Energy logging with Tasker integration - success case", function()
    local daily_logs = {}
    local callbacks = data.create_mock_callbacks()
    
    local mock_date, original_date = data.mock_os_date("2023-01-01")
    os.date = mock_date
    
    local success = core.log_energy_with_tasker(daily_logs, 7, callbacks.tasker, callbacks.ui)
    
    os.date = original_date
    
    test.assert_true(success, "Should return success")
    test.assert_equals(2, #callbacks.calls, "Should make tasker and UI callbacks")
    
    -- Check callbacks
    local tasker_call = callbacks.calls[1]
    local ui_call = callbacks.calls[2]
    
    test.assert_equals("Energy", tasker_call.params.event_type, "Should have Energy event type")
    test.assert_equals("7", tasker_call.params.value, "Should convert energy level to string")
    test.assert_not_nil(tasker_call.params.timestamp, "Should include timestamp")
    
    test.assert_contains(ui_call.message, "Energy level 7 logged", "Should show energy success message")
    
    -- Verify energy was logged
    local today_logs = core.get_daily_logs(daily_logs, "2023-01-01")
    test.assert_equals(1, #today_logs.energy_levels, "Should log energy entry")
    test.assert_equals(7, today_logs.energy_levels[1].level, "Should store energy level")
end)

test.add_test("Energy logging with different energy levels", function()
    local daily_logs = {}
    local callbacks = data.create_mock_callbacks()
    
    -- Test boundary values
    local test_levels = {1, 5, 10}
    
    for _, level in ipairs(test_levels) do
        callbacks.calls = {}
        local success = core.log_energy_with_tasker(daily_logs, level, callbacks.tasker, callbacks.ui)
        
        test.assert_true(success, "Should log energy level " .. level)
        
        local tasker_call = nil
        local ui_call = nil
        for _, call in ipairs(callbacks.calls) do
            if call.type == "tasker" then
                tasker_call = call
            elseif call.type == "ui" then
                ui_call = call
            end
        end
        
        test.assert_not_nil(tasker_call, "Should make tasker call")
        test.assert_equals(tostring(level), tasker_call.params.value, "Should convert level " .. level .. " to string")
        
        test.assert_not_nil(ui_call, "Should make UI call")
        test.assert_contains(ui_call.message, "Energy level " .. level .. " logged", "Should show correct level in UI")
    end
end)

test.add_test("Energy logging robustness", function()
    local ui_messages = {}
    
    local ui_callback = function(message)
        table.insert(ui_messages, message)
    end
    
    -- The energy logging function is designed to be very robust
    -- Test that it handles edge cases gracefully
    local success = core.log_energy_with_tasker({}, nil, nil, ui_callback)
    
    test.assert_true(success, "Should handle nil energy level gracefully")
    test.assert_equals(1, #ui_messages, "Should show success message")
    test.assert_contains(ui_messages[1], "Energy level", "Should show energy logged message")
end)

test.add_test("Timestamp format consistency", function()
    local daily_logs = {}
    local tasker_calls = {}
    
    local tasker_callback = function(params)
        table.insert(tasker_calls, params)
    end
    
    -- Mock specific date/time
    local original_date = os.date
    os.date = function(format)
        if format == "%Y-%m-%d %H:%M:%S" then
            return "2023-01-01 10:30:45"
        elseif format == "%Y-%m-%d" then
            return "2023-01-01"
        end
        return original_date(format)
    end
    
    -- Test item logging timestamp
    core.log_item_with_tasker(daily_logs, "symptom", "Test", tasker_callback, nil)
    test.assert_equals("2023-01-01 10:30:45", tasker_calls[1].timestamp, "Item logging should have consistent timestamp format")
    
    -- Test energy logging timestamp
    tasker_calls = {}
    core.log_energy_with_tasker(daily_logs, 5, tasker_callback, nil)
    test.assert_equals("2023-01-01 10:30:45", tasker_calls[1].timestamp, "Energy logging should have consistent timestamp format")
    
    os.date = original_date
end)

test.add_test("Multiple logging calls maintain separate state", function()
    local daily_logs1 = {}
    local daily_logs2 = {}
    local callbacks1 = data.create_mock_callbacks()
    local callbacks2 = data.create_mock_callbacks()
    
    local mock_date, original_date = data.mock_os_date("2023-01-01")
    os.date = mock_date
    
    -- Log different items to different logs
    core.log_item_with_tasker(daily_logs1, "symptom", "Fatigue", callbacks1.tasker, callbacks1.ui)
    core.log_item_with_tasker(daily_logs2, "activity", "Walk", callbacks2.tasker, callbacks2.ui)
    
    os.date = original_date
    
    -- Check that logs are separate
    local logs1 = core.get_daily_logs(daily_logs1, "2023-01-01")
    local logs2 = core.get_daily_logs(daily_logs2, "2023-01-01")
    
    test.assert_equals(1, logs1.symptoms["Fatigue"], "First log should have fatigue")
    test.assert_nil(logs1.activities["Walk"], "First log should not have walk")
    
    test.assert_equals(1, logs2.activities["Walk"], "Second log should have walk")
    test.assert_nil(logs2.symptoms["Fatigue"], "Second log should not have fatigue")
    
    -- Check callbacks are separate
    test.assert_equals(2, #callbacks1.calls, "First callback set should have 2 calls")
    test.assert_equals(2, #callbacks2.calls, "Second callback set should have 2 calls")
end)

test.add_test("Logging with special characters in item names", function()
    local daily_logs = {}
    local callbacks = data.create_mock_callbacks()
    
    -- Test item names with special characters
    local special_items = {
        "LDN (4mg)",
        "Physio - full session",
        "Brain fog & concentration",
        "Sleep 7-8 hours"
    }
    
    for _, item in ipairs(special_items) do
        callbacks.calls = {}
        local success = core.log_item_with_tasker(daily_logs, "symptom", item, callbacks.tasker, callbacks.ui)
        
        test.assert_true(success, "Should log item with special characters: " .. item)
        test.assert_equals(item, callbacks.calls[1].params.value, "Should preserve special characters in Tasker call")
        test.assert_contains(callbacks.calls[2].message, item, "Should preserve special characters in UI message")
    end
end)

test.add_test("Callback parameter validation", function()
    local daily_logs = {}
    
    -- Test with various callback parameter types
    local callback_tests = {
        {nil, nil, "Should handle both callbacks as nil"},
        {function() end, nil, "Should handle UI callback as nil"},
        {nil, function() end, "Should handle Tasker callback as nil"}
    }
    
    for _, test_case in ipairs(callback_tests) do
        local tasker_cb, ui_cb, description = test_case[1], test_case[2], test_case[3]
        
        local success = core.log_item_with_tasker(daily_logs, "symptom", "Test", tasker_cb, ui_cb)
        test.assert_true(success, description)
    end
end)

test.add_test("Integration with existing log_item function", function()
    local daily_logs = {}
    
    local mock_date, original_date = data.mock_os_date("2023-01-01")
    os.date = mock_date
    
    -- First, log using the new Tasker-integrated function
    core.log_item_with_tasker(daily_logs, "symptom", "Fatigue", nil, nil)
    
    -- Then, log using the original function
    core.log_item(daily_logs, "symptom", "Fatigue")
    
    local today_logs = core.get_daily_logs(daily_logs, "2023-01-01")
    
    os.date = original_date
    
    test.assert_equals(2, today_logs.symptoms["Fatigue"], "Both logging methods should contribute to same counter")
end)

test.add_test("Error messages provide useful information", function()
    local ui_messages = {}
    
    local ui_callback = function(message)
        table.insert(ui_messages, message)
    end
    
    -- Test with invalid item type
    core.log_item_with_tasker({}, "invalid_type", "Test", nil, ui_callback)
    
    test.assert_true(#ui_messages > 0, "Should provide error message")
    
    local error_msg = ui_messages[1]
    test.assert_contains(error_msg, "Error logging", "Should indicate logging error")
    test.assert_contains(error_msg, "invalid_type", "Should include item type in error")
end)

-- This file can be run standalone or included by main test runner
if ... == nil then
    test.run_tests("Logging Functions")
    local success = test.print_final_results()
    os.exit(success and 0 or 1)
end