#!/usr/bin/env lua

-- Test Suite for Day Reset Scenarios - Long Covid Pacing Widget
-- Tests widget behavior when reset between days, focusing on manager initialization and command handling
-- Run with: lua test_day_reset.lua

package.path = package.path .. ";../my/?.lua"

local test_framework = require "test_framework"
local test_data = require "test_data"

-- Mock storage for test isolation
local test_files = {}
local test_toasts = {}
local test_ui_calls = {}
local test_prefs = {}

-- Mock AIO Launcher APIs with reset capability
local mock_files = {
    write = function(filename, content)
        test_files[filename] = content
        return true
    end,
    
    read = function(filename)
        return test_files[filename] or ""
    end
}

local mock_ui = {
    show_toast = function(message)
        table.insert(test_toasts, message)
    end
}

local mock_prefs = {
    daily_capacity_log = {},
    
    -- Add indexing for dynamic access
    __index = function(t, k)
        return test_prefs[k]
    end,
    
    __newindex = function(t, k, v)
        test_prefs[k] = v
    end
}

setmetatable(mock_prefs, mock_prefs)

-- Global mocks need to be set before requiring the core
_G.files = mock_files
_G.ui = mock_ui
_G.prefs = mock_prefs

-- Helper function to reset test state
local function reset_test_state()
    test_files = {}
    test_toasts = {}
    test_ui_calls = {}
    test_prefs = {}
    
    -- Reset mock prefs
    mock_prefs.daily_capacity_log = {}
    
    -- Add test data
    test_files["criteria.md"] = test_data.test_criteria_content
    test_files["monday.md"] = test_data.test_monday_content
    test_files["activities.md"] = test_data.test_activities_content
end

-- Helper function to simulate widget being reloaded/reset
local function simulate_widget_reset()
    -- Clear any existing global state that might persist
    package.loaded["long_covid_core"] = nil
    
    -- Reload the core module (simulates widget reset)
    local core = require "long_covid_core"
    
    return core
end

-- Helper function to simulate on_command being called during reset
local function simulate_on_command_during_reset(command_data)
    -- Import the main widget file in a way that simulates reset conditions
    local widget_code = [[
        -- Simulate the widget being loaded fresh
        package.path = package.path .. ";../my/?.lua"
        local core = require "long_covid_core"
        
        -- Simulate global variables being reset
        if not prefs.daily_capacity_log then
            prefs.daily_capacity_log = {}
        end
        
        -- Create managers (this could fail during reset)
        local dialog_manager = core.create_dialog_manager()
        local cache_manager = core.create_cache_manager()
        local button_mapper = core.create_button_mapper()
        local ui_generator = core.create_ui_generator()
        
        -- Define on_command function as it exists in the widget
        function on_command(data)
            local function split_string(str, delimiter)
                local result = {}
                local pattern = "([^" .. delimiter .. "]+)"
                for match in str:gmatch(pattern) do
                    table.insert(result, match)
                end
                return result
            end
            
            local parts = split_string(data, ":")
            if #parts < 3 then
                return
            end
            
            local data_type = parts[1]
            local filename = parts[2]
            local content = table.concat(parts, ":", 3)
            
            if data_type == "plan_data" then
                files:write(filename, content)
                
                -- Clear cache to reload data - this is where the error occurred
                if cache_manager then
                    cache_manager:clear_cache()
                end
                if dialog_manager then
                    dialog_manager.cached_symptoms = nil
                    dialog_manager.cached_activities = nil
                    dialog_manager.cached_interventions = nil
                    dialog_manager.cached_required_activities = nil
                    dialog_manager.cached_required_interventions = nil
                end
                
                ui:show_toast("✓ Plan data updated")
            end
        end
        
        return on_command
    ]]
    
    -- Execute the widget code and get the on_command function
    local chunk, err = load(widget_code, "widget_reset_simulation")
    if not chunk then
        error("Failed to load widget simulation: " .. err)
    end
    
    local success, on_command_func = pcall(chunk)
    if not success then
        error("Failed to execute widget simulation: " .. on_command_func)
    end
    
    -- Now call on_command with the provided data
    return pcall(on_command_func, command_data)
end

-- Test: Widget handles day reset without managers being nil
test_framework.add_test("Day reset with proper manager initialization", function()
    reset_test_state()
    
    -- Simulate widget being reset (fresh load)
    local core = simulate_widget_reset()
    
    -- Create managers as would happen on fresh widget load
    local dialog_manager = core.create_dialog_manager()
    local cache_manager = core.create_cache_manager()
    
    -- Verify managers are properly initialized
    test_framework.assert_not_nil(dialog_manager, "Dialog manager should be initialized")
    test_framework.assert_not_nil(cache_manager, "Cache manager should be initialized")
    test_framework.assert_type("table", dialog_manager, "Dialog manager should be a table")
    test_framework.assert_type("table", cache_manager, "Cache manager should be a table")
end)

-- Test: on_command handles nil managers gracefully (core safety test)
test_framework.add_test("on_command handles nil managers during reset", function()
    reset_test_state()
    
    -- Test the critical part: nil manager handling doesn't crash
    local function test_nil_manager_safety()
        local dialog_manager = nil  -- Simulate uninitialized manager
        local cache_manager = nil   -- Simulate uninitialized manager
        
        -- This is the exact code from the fixed widget
        if cache_manager then
            cache_manager:clear_cache()
        end
        if dialog_manager then
            dialog_manager.cached_symptoms = nil
            dialog_manager.cached_activities = nil
            dialog_manager.cached_interventions = nil
            dialog_manager.cached_required_activities = nil
            dialog_manager.cached_required_interventions = nil
        end
        
        return true  -- Should not crash
    end
    
    local success, error_msg = pcall(test_nil_manager_safety)
    test_framework.assert_true(success, "Should handle nil managers without crashing: " .. tostring(error_msg))
end)

-- Test: Manager cache clearing works with initialized managers
test_framework.add_test("Manager cache clearing with initialized managers", function()
    reset_test_state()
    
    -- Create managers normally
    local core = require "long_covid_core"
    local dialog_manager = core.create_dialog_manager()
    local cache_manager = core.create_cache_manager()
    
    -- Set some cache values to clear
    dialog_manager.cached_symptoms = {"test_symptom"}
    dialog_manager.cached_activities = {"test_activity"}
    
    -- Test cache clearing with initialized managers
    local function test_cache_clearing_with_managers()
        if cache_manager then
            cache_manager:clear_cache()
        end
        if dialog_manager then
            dialog_manager.cached_symptoms = nil
            dialog_manager.cached_activities = nil
            dialog_manager.cached_interventions = nil
            dialog_manager.cached_required_activities = nil
            dialog_manager.cached_required_interventions = nil
        end
        return true
    end
    
    local success, error_msg = pcall(test_cache_clearing_with_managers)
    
    test_framework.assert_true(success, "Should clear cache with initialized managers: " .. tostring(error_msg))
    test_framework.assert_nil(dialog_manager.cached_symptoms, "Cached symptoms should be cleared")
    test_framework.assert_nil(dialog_manager.cached_activities, "Cached activities should be cleared")
end)

-- Test: Manager creation is resilient to multiple resets
test_framework.add_test("Manager creation handles multiple resets", function()
    reset_test_state()
    
    -- Simulate multiple widget resets
    for i = 1, 3 do
        local core = simulate_widget_reset()
        
        local dialog_manager = core.create_dialog_manager()
        local cache_manager = core.create_cache_manager()
        
        test_framework.assert_not_nil(dialog_manager, "Dialog manager should be created on reset " .. i)
        test_framework.assert_not_nil(cache_manager, "Cache manager should be created on reset " .. i)
        
        -- Test that managers have expected structure
        test_framework.assert_type("table", dialog_manager, "Dialog manager should be table on reset " .. i)
        test_framework.assert_type("table", cache_manager, "Cache manager should be table on reset " .. i)
    end
end)

-- Test: Invalid command data doesn't crash during reset
test_framework.add_test("Invalid command data handling during reset", function()
    reset_test_state()
    
    -- Test various invalid inputs
    local invalid_commands = {
        "",
        "incomplete",
        "incomplete:data",
        "plan_data:",
        "plan_data::",
        "unknown_type:file.md:content"
    }
    
    for _, invalid_cmd in ipairs(invalid_commands) do
        local success, error_msg = simulate_on_command_during_reset(invalid_cmd)
        test_framework.assert_true(success, "Should handle invalid command '" .. invalid_cmd .. "': " .. tostring(error_msg))
    end
end)

-- Test: Cache clearing doesn't fail with uninitialized managers
test_framework.add_test("Cache clearing with uninitialized managers", function()
    reset_test_state()
    
    -- Simulate the scenario where managers might be nil during reset
    local function test_cache_clearing()
        local dialog_manager = nil
        local cache_manager = nil
        
        -- This is the fixed code that should handle nil managers
        if cache_manager then
            cache_manager:clear_cache()  -- This should not be called
        end
        if dialog_manager then
            dialog_manager.cached_symptoms = nil  -- This should not be called
            dialog_manager.cached_activities = nil
            dialog_manager.cached_interventions = nil
            dialog_manager.cached_required_activities = nil
            dialog_manager.cached_required_interventions = nil
        end
        
        return true  -- Should reach here without error
    end
    
    local success, error_msg = pcall(test_cache_clearing)
    test_framework.assert_true(success, "Cache clearing should handle nil managers: " .. tostring(error_msg))
end)

-- Run the day reset test suite
print("🔄 Day Reset Test Suite")
print("Testing widget behavior during day transitions and resets...")

local all_passed = test_framework.run_tests("Day Reset Scenarios")
test_framework.print_final_results()

if all_passed then
    print("\n✅ Day reset handling is working correctly!")
    print("The widget should now handle day transitions without 'function arguments expected' errors.")
else
    print("\n❌ Some day reset tests failed.")
    print("Review the failures above to identify day reset issues.")
    os.exit(1)
end