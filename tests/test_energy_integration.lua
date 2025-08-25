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

-- Test suite
local function run_energy_integration_tests()
    print("Running Energy Dialog Flow Integration Tests...")
    print("============================================================")
    
    local tests_passed = 0
    local tests_total = 0
    
    local function test(name, test_func)
        tests_total = tests_total + 1
        local success, error_msg = pcall(test_func)
        if success then
            print("✓ " .. name)
            tests_passed = tests_passed + 1
        else
            print("✗ " .. name .. " - " .. tostring(error_msg))
        end
    end
    
    local function assert_equals(actual, expected, message)
        if actual ~= expected then
            error(message .. " - Expected: " .. tostring(expected) .. ", Got: " .. tostring(actual))
        end
    end
    
    local function assert_contains(table_or_string, value, message)
        if type(table_or_string) == "table" then
            for _, v in ipairs(table_or_string) do
                if v == value then return end
            end
            error(message .. " - Table does not contain: " .. tostring(value))
        else
            if not string.find(table_or_string, value, 1, true) then
                error(message .. " - String does not contain: " .. tostring(value))
            end
        end
    end
    
    -- Test energy flow initialization
    test("Energy flow initialization", function()
        local flow_manager = core.create_dialog_flow_manager()
        local data_manager = core.create_dialog_manager()
        
        flow_manager:set_data_manager(data_manager)
        flow_manager:set_daily_logs({["2025-01-21"] = {energy_levels = {}}})
        
        local status, data = flow_manager:start_flow("energy")
        assert_equals(status, "show_dialog", "Should return show_dialog status")
        assert_equals(data.type, "radio", "Should be radio dialog")
        assert_equals(data.title, "Log Energy Level", "Should have correct title")
        assert_contains(data.data.options, "1 - Completely drained", "Should contain energy level 1")
        assert_contains(data.data.options, "5 - Average", "Should contain energy level 5")
        assert_contains(data.data.options, "10 - Peak energy", "Should contain energy level 10")
    end)
    
    -- Test energy selection and completion
    test("Energy selection and completion", function()
        local flow_manager = core.create_dialog_flow_manager()
        local data_manager = core.create_dialog_manager()
        
        flow_manager:set_data_manager(data_manager)
        flow_manager:set_daily_logs({["2025-01-21"] = {energy_levels = {}}})
        
        -- Start flow and select energy level 7
        flow_manager:start_flow("energy")
        local status, result = flow_manager:handle_dialog_result(7) -- "7 - Good"
        
        assert_equals(status, "flow_complete", "Should complete flow")
        assert_equals(result.category, "energy", "Should be energy category")
        assert_equals(result.item, 7, "Should extract numeric energy level")
    end)
    
    -- Test all energy levels can be selected
    test("All energy levels selectable", function()
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
            
            assert_equals(status, "flow_complete", "Level " .. test_case.index .. " should complete flow")
            assert_equals(result.item, test_case.expected, "Should extract correct energy level " .. test_case.expected)
        end
    end)
    
    -- Test energy flow cancellation
    test("Energy flow cancellation", function()
        local flow_manager = core.create_dialog_flow_manager()
        local data_manager = core.create_dialog_manager()
        
        flow_manager:set_data_manager(data_manager)
        flow_manager:set_daily_logs({["2025-01-21"] = {energy_levels = {}}})
        
        -- Start flow and cancel (accounts for AIO dialog quirk)
        flow_manager:start_flow("energy")
        local first_cancel = flow_manager:handle_cancel()
        assert_equals(first_cancel, "continue", "First cancel should be ignored (AIO quirk)")
        
        -- Second cancel should actually cancel
        local second_cancel = flow_manager:handle_cancel()
        assert_equals(second_cancel, "flow_cancelled", "Second cancel should cancel flow")
    end)
    
    -- Test energy logging integration
    test("Energy logging integration", function()
        local today = os.date("%Y-%m-%d")
        local daily_logs = {[today] = {energy_levels = {}}}
        
        -- Test the log_energy_with_tasker function (this is what the widget actually calls)
        local success = core.log_energy_with_tasker(daily_logs, 8, nil, nil)
        assert_equals(success, true, "Should successfully log energy")
        
        local today_logs = core.get_daily_logs(daily_logs, today)
        assert_equals(#today_logs.energy_levels, 1, "Should have one energy entry")
        assert_equals(today_logs.energy_levels[1].level, 8, "Should log correct energy level")
    end)
    
    print("Suite Results: " .. tests_passed .. "/" .. tests_total .. " tests passed")
    
    if tests_passed == tests_total then
        print("\nEnergy dialog flow integration is working correctly!")
        print("The new dialog stack system is ready for energy logging.")
        return true
    else
        print("\n" .. (tests_total - tests_passed) .. " test(s) failed!")
        return false
    end
end

-- Run tests if called directly
if not TEST_RUNNER then
    run_energy_integration_tests()
else
    return {
        name = "Energy Integration", 
        run = run_energy_integration_tests
    }
end