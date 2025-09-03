-- test_energy_integration.lua
-- Integration tests for Energy Dialog Flow

-- Set path first
package.path = package.path .. ";../my/?.lua"

-- Mock AIO dependencies BEFORE loading core
files = { read = function() return nil end }
prefs = {}
ui = { toast = function() end, show_text = function() end }
dialogs = {}
tasker = {}

-- Import core module AFTER setting up mocks
local core_module = "long_covid_core"
local core = require(core_module)

-- Import the test framework
local test = require "test_framework"
    
-- Test energy flow initialization
test.add_test("Energy flow initialization", function()
    local flow_manager = core.create_dialog_flow_manager()
    local data_manager = core.create_dialog_manager()
    
    flow_manager:set_data_manager(data_manager)
    flow_manager:set_daily_logs({["2025-01-21"] = {energy_levels = {}}})
    
    local status, data = flow_manager:start_flow("energy")
    test.assert_equals("show_dialog", status, "Should return show_dialog status")
    test.assert_equals("radio", data.type, "Should be radio dialog")
    test.assert_equals("Log Energy Level", data.title, "Should have correct title")
    test.assert_contains(data.data.options, "1 - Completely drained", "Should contain energy level 1")
    test.assert_contains(data.data.options, "5 - Average", "Should contain energy level 5")
    test.assert_contains(data.data.options, "10 - Peak energy", "Should contain energy level 10")
end)
    
-- Test energy selection and completion
test.add_test("Energy selection and completion", function()
    local flow_manager = core.create_dialog_flow_manager()
    local data_manager = core.create_dialog_manager()
    
    flow_manager:set_data_manager(data_manager)
    flow_manager:set_daily_logs({["2025-01-21"] = {energy_levels = {}}})
    
    -- Start flow and select energy level 7
    flow_manager:start_flow("energy")
    local status, result = flow_manager:handle_dialog_result(7) -- "7 - Good"
    
    test.assert_equals("flow_complete", status, "Should complete flow")
    test.assert_equals("energy", result.category, "Should be energy category")
    test.assert_equals(7, result.item, "Should extract numeric energy level")
end)
    
-- Test all energy levels can be selected
test.add_test("All energy levels selectable", function()
    local flow_manager = core.create_dialog_flow_manager()
    local data_manager = core.create_dialog_manager()
    
    flow_manager:set_data_manager(data_manager)
    flow_manager:set_daily_logs({["2025-01-21"] = {energy_levels = {}}})
    
    -- Test levels 1, 5, and 10
    local test_levels = {
        {index = 1, expected = 1},
        {index = 5, expected = 5}, 
        {index = 10, expected = 10}
    }
    
    for _, test_case in ipairs(test_levels) do
        local new_flow_manager = core.create_dialog_flow_manager()
        new_flow_manager:set_data_manager(data_manager)
        new_flow_manager:set_daily_logs({["2025-01-21"] = {energy_levels = {}}})
        
        new_flow_manager:start_flow("energy")
        local status, result = new_flow_manager:handle_dialog_result(test_case.index)
        
        test.assert_equals("flow_complete", status, "Level " .. test_case.index .. " should complete flow")
        test.assert_equals(test_case.expected, result.item, "Should extract correct energy level " .. test_case.expected)
    end
end)
    
-- Test energy flow cancellation
test.add_test("Energy flow cancellation", function()
    local flow_manager = core.create_dialog_flow_manager()
    local data_manager = core.create_dialog_manager()
    
    flow_manager:set_data_manager(data_manager)
    flow_manager:set_daily_logs({["2025-01-21"] = {energy_levels = {}}})
    
    -- Start flow and cancel (accounts for AIO dialog quirk)
    flow_manager:start_flow("energy")
    local first_cancel = flow_manager:handle_cancel()
    test.assert_equals("continue", first_cancel, "First cancel should be ignored (AIO quirk)")
    
    -- Second cancel should actually cancel
    local second_cancel = flow_manager:handle_cancel()
    test.assert_equals("flow_cancelled", second_cancel, "Second cancel should cancel flow")
end)
    
-- Test energy logging integration
test.add_test("Energy logging integration", function()
    local today = os.date("%Y-%m-%d")
    local daily_logs = {[today] = {energy_levels = {}}}
    
    -- Test the log_energy_with_tasker function (this is what the widget actually calls)
    local success = core.log_energy_with_tasker(daily_logs, 8, nil, nil)
    test.assert_equals(true, success, "Should successfully log energy")
    
    local today_logs = core.get_daily_logs(daily_logs, today)
    test.assert_equals(1, #today_logs.energy_levels, "Should have one energy entry")
    test.assert_equals(8, today_logs.energy_levels[1].level, "Should log correct energy level")
end)
    
-- Individual runner pattern
if ... == nil then
    test.run_tests("Energy Dialog Flow Integration")
    local success = test.print_final_results()
    os.exit(success and 0 or 1)
end