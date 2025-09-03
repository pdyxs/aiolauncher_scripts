-- test_framework.lua - Shared testing utilities for Long Covid Widget tests
-- This provides common assertion functions and test running capabilities
--
-- CRITICAL: This is the ONLY testing framework for this project.
-- ALL test files must use this framework to ensure consistent output formatting.
-- 
-- Required usage pattern:
--   local test = require "test_framework"
--   test.add_test("name", function() ... end)
--   if ... == nil then
--       test.run_tests("Suite Name")
--       local success = test.print_final_results()
--       os.exit(success and 0 or 1)
--   end
--
-- DO NOT create custom test runners, output formatting, or assertion functions.

local M = {}

-- Test result tracking
M.tests = {}
M.passed = 0
M.failed = 0
M.quiet_mode = false  -- When true, only show summary for successful suites

-- Add a test to the current suite
function M.add_test(name, test_func)
    table.insert(M.tests, {name = name, func = test_func})
end

-- Assertion functions
function M.assert_equals(expected, actual, message)
    if expected ~= actual then
        error((message or "Assertion failed") .. 
              string.format(": expected %s, got %s", tostring(expected), tostring(actual)), 2)
    end
end

function M.assert_true(condition, message)
    if not condition then
        error((message or "Expected true") .. ": got " .. tostring(condition), 2)
    end
end

function M.assert_false(condition, message)
    if condition then
        error((message or "Expected false") .. ": got " .. tostring(condition), 2)
    end
end

function M.assert_contains(haystack, needle, message)
    if type(haystack) == "table" then
        for _, v in ipairs(haystack) do
            if v == needle then
                return
            end
        end
        error((message or "Table does not contain expected value") .. 
              string.format(": %s not found", tostring(needle)), 2)
    elseif type(haystack) == "string" then
        if not haystack:find(needle, 1, true) then
            error((message or "String does not contain expected substring") .. 
                  string.format(": '%s' not found in '%s'", tostring(needle), tostring(haystack)), 2)
        end
    else
        error("assert_contains expects table or string as first argument", 2)
    end
end

function M.assert_type(expected_type, actual_value, message)
    local actual_type = type(actual_value)
    if actual_type ~= expected_type then
        error((message or "Type assertion failed") .. 
              string.format(": expected %s, got %s", expected_type, actual_type), 2)
    end
end

function M.assert_nil(value, message)
    if value ~= nil then
        error((message or "Expected nil") .. ": got " .. tostring(value), 2)
    end
end

function M.assert_not_nil(value, message)
    if value == nil then
        error(message or "Expected non-nil value", 2)
    end
end

-- Run tests for a specific suite with configurable output
function M.run_tests(suite_name)
    if #M.tests == 0 then
        if not M.quiet_mode then
            print("No tests found for " .. (suite_name or "unknown suite"))
        end
        return true
    end
    
    local suite_passed = 0
    local suite_failed = 0
    local failed_tests = {}
    
    for _, test in ipairs(M.tests) do
        local success, error_msg = pcall(test.func)
        if success then
            suite_passed = suite_passed + 1
            if not M.quiet_mode then
                print("✓ " .. test.name)
            end
        else
            suite_failed = suite_failed + 1
            table.insert(failed_tests, {name = test.name, error = tostring(error_msg)})
            if not M.quiet_mode then
                print("✗ " .. test.name)
                print("  Error: " .. tostring(error_msg))
            end
        end
    end
    
    M.passed = M.passed + suite_passed
    M.failed = M.failed + suite_failed
    
    -- Output results based on mode
    if M.quiet_mode then
        if suite_failed == 0 then
            -- Success: single line
            print("✅ " .. (suite_name or "Test Suite") .. " - PASSED (" .. suite_passed .. " tests)")
        else
            -- Failure: show failed tests and summary
            print("❌ " .. (suite_name or "Test Suite") .. " - FAILED")
            for _, failed_test in ipairs(failed_tests) do
                print("  ✗ " .. failed_test.name)
                print("    Error: " .. failed_test.error)
            end
        end
    else
        -- Verbose mode (individual test runs)
        if suite_failed == 0 then
            print("✅ All tests passed (" .. suite_passed .. " tests)")
        else
            print("❌ " .. suite_failed .. " test(s) failed out of " .. (suite_passed + suite_failed))
        end
    end
    
    -- Clear tests for next suite
    M.tests = {}
    
    return suite_failed == 0
end

-- Final results summary (only used in non-quiet mode)
function M.print_final_results()
    if M.quiet_mode then
        return M.failed == 0
    end
    
    local total = M.passed + M.failed
    print("\n" .. string.rep("=", 60))
    print(string.format("FINAL RESULTS: %d/%d tests passed", M.passed, total))
    
    if M.failed == 0 then
        print("All tests passed! 🎉")
        print("The Long Covid Widget is working correctly.")
        return true
    else
        print(string.format("%d tests failed. ❌", M.failed))
        return false
    end
end

-- Reset counters (useful for running tests multiple times)
function M.reset()
    M.tests = {}
    M.passed = 0
    M.failed = 0
    M.quiet_mode = false
end

-- Set quiet mode (for use by run_all_tests)
function M.set_quiet_mode(quiet)
    M.quiet_mode = quiet
end

return M