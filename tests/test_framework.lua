-- test_framework.lua - Shared testing utilities for Long Covid Widget tests
-- This provides common assertion functions and test running capabilities

local M = {}

-- Test result tracking
M.tests = {}
M.passed = 0
M.failed = 0

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

-- Run tests for a specific suite
function M.run_tests(suite_name)
    if #M.tests == 0 then
        print("No tests found for " .. (suite_name or "unknown suite"))
        return true
    end
    
    print("\nRunning " .. (suite_name or "Test Suite") .. "...")
    print(string.rep("=", 60))
    
    local suite_passed = 0
    local suite_failed = 0
    
    for _, test in ipairs(M.tests) do
        local success, error_msg = pcall(test.func)
        if success then
            suite_passed = suite_passed + 1
            print("✓ " .. test.name)
        else
            suite_failed = suite_failed + 1
            print("✗ " .. test.name)
            print("  Error: " .. tostring(error_msg))
        end
    end
    
    M.passed = M.passed + suite_passed
    M.failed = M.failed + suite_failed
    
    print(string.format("Suite Results: %d/%d tests passed", suite_passed, suite_passed + suite_failed))
    
    -- Clear tests for next suite
    M.tests = {}
    
    return suite_failed == 0
end

-- Final results summary
function M.print_final_results()
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
end

return M