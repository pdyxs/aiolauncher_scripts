#!/usr/bin/env lua

-- run_all_tests.lua - Main test runner for Long Covid Widget
-- Runs all test suites and provides comprehensive reporting
-- Usage: lua run_all_tests.lua

-- Add paths for imports
package.path = package.path .. ";../my/?.lua;./?.lua"

local test = require "test_framework"

-- Enable quiet mode for clean output
test.set_quiet_mode(true)


-- Test suites to run (in order)
local test_suites = {
    -- Unit tests (new modules)
    {name = "Date Utils Tests", file = "unit.test_date_utils"},
    {name = "Parsing Module Tests", file = "unit.test_parsing"},
    
    -- Existing integration tests
    {name = "Core Business Logic", file = "test_core_logic"},
    {name = "Options Completion Logic", file = "test_options_completion"},
    {name = "Logging Functions", file = "test_logging_functions"}, 
    {name = "Dialog Manager", file = "test_dialog_manager"},
    {name = "Cache Manager", file = "test_cache_manager"},
    {name = "Button Mapper", file = "test_button_mapper"},
    {name = "UI Generator", file = "test_ui_generator"},
    {name = "Day Reset Scenarios", file = "test_day_reset"},
    {name = "Dialog Stack System", file = "test_dialog_stack"},
    {name = "Symptoms Integration", file = "test_symptoms_integration"},
    {name = "Activities Integration", file = "test_activities_integration"},
    {name = "Interventions Integration", file = "test_interventions_integration"},
    {name = "Activity Logging Persistence", file = "test_activity_logging_persistence"},
    {name = "Energy Integration", file = "test_energy_integration"},
    {name = "Weekly Required Items", file = "test_weekly_required_items"},
    {name = "Consolidated Parsing Infrastructure", file = "test_consolidated_parsing"},
    {name = "Consolidated Completion Logic", file = "test_consolidated_completion"},
    {name = "Simplified Formatting", file = "test_simplified_formatting"},
    {name = "Long Covid Widget", file = "test_long_covid_widget"}
}

-- Track overall results
local suite_results = {}
local start_time = os.clock()

-- Run each test suite
for i, suite in ipairs(test_suites) do
    -- Load and run the test suite
    local success, suite_module = pcall(require, suite.file)
    
    if success then
        -- The test suite will run automatically when loaded
        -- and update the shared test framework counters
        local suite_passed = test.run_tests(suite.name)
        
        suite_results[suite.name] = {
            passed = suite_passed,
            file = suite.file
        }
    else
        print("❌ Failed to load test suite: " .. suite.name)
        print("   Error: " .. tostring(suite_module))
        suite_results[suite.name] = {
            passed = false,
            error = tostring(suite_module)
        }
    end
end

local end_time = os.clock()
local total_time = end_time - start_time

-- Print final results summary
local suites_passed = 0
local suites_failed = 0

for suite_name, result in pairs(suite_results) do
    if result.passed then
        suites_passed = suites_passed + 1
    else
        suites_failed = suites_failed + 1
    end
end

local framework_success = test.print_final_results()

if framework_success and suites_failed == 0 then
    print(string.format("🎉 ALL TESTS PASSED - %d suites, %d tests (%.2fs)", suites_passed, test.passed, total_time))
    os.exit(0)
else
    print(string.format("❌ %d/%d suites failed, %d/%d tests failed (%.2fs)", suites_failed, suites_passed + suites_failed, test.failed, test.passed + test.failed, total_time))
    os.exit(1)
end