-- test_activity_logging_persistence.lua
-- Test that logged activities with options show up as previously logged

-- Set path first
package.path = package.path .. ";../my/?.lua"

-- Mock AIO dependencies BEFORE loading core
files = {
    read = function(filename)
        if filename == "activities.md" then
            return [[# Test Activities

## Work  
- Work {Options: In Office, From Home}
- Meeting-heavy day

## Physical
- Walk {Options: Light, Medium, Heavy}]]
        end
        return nil
    end
}

prefs = {}
ui = { toast = function() end, show_text = function() end }
dialogs = {}
tasker = {}

-- Import core module AFTER setting up mocks
local core_module = "long_covid_core"
local core = require(core_module)

-- Test suite
local function run_activity_logging_persistence_tests()
    print("Running Activity Logging Persistence Tests...")
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
    
    -- Test that logged activities with options show up as already logged
    test("Activity with options shows as logged after completion", function()
        local flow_manager = core.create_dialog_flow_manager()
        local data_manager = core.create_dialog_manager()
        
        -- Set up initial state with empty logs for today
        local today = "2025-01-21"
        local daily_logs = {[today] = {activities = {}}}
        
        flow_manager:set_data_manager(data_manager)
        flow_manager:set_daily_logs(daily_logs)
        
        -- 1. Start flow and complete "Work: From Home"
        flow_manager:start_flow("activity")
        flow_manager:handle_dialog_result(1) -- Select "Work" 
        local status, result = flow_manager:handle_dialog_result(2) -- Select "From Home"
        
        assert_equals(status, "flow_complete", "Should complete flow")
        assert_equals(result.item, "Work: From Home", "Should log combined item")
        
        -- 2. Actually log the item using the core logging function
        core.log_item(daily_logs, result.category, result.item)
        
        -- 3. Start a new flow and check if "Work" shows as already logged
        local new_flow_manager = core.create_dialog_flow_manager()
        new_flow_manager:set_data_manager(data_manager)
        new_flow_manager:set_daily_logs(daily_logs)
        
        local new_status, new_data = new_flow_manager:start_flow("activity")
        assert_equals(new_status, "show_dialog", "Should show dialog")
        
        -- Check if "Work" option shows as already done
        local work_option = nil
        for _, option in ipairs(new_data.data.options) do
            if option:find("Work") then
                work_option = option
                break
            end
        end
        
        assert_contains(work_option, "✓", "Work should show as completed with checkmark")
    end)
    
    -- Test that specific option variant shows as logged
    test("Specific activity option variant shows as logged", function()
        local flow_manager = core.create_dialog_flow_manager()
        local data_manager = core.create_dialog_manager()
        
        local today = "2025-01-21"
        local daily_logs = {[today] = {activities = {}}}
        
        -- Actually log the item properly
        core.log_item(daily_logs, "activity", "Work: In Office")
        
        flow_manager:set_data_manager(data_manager)
        flow_manager:set_daily_logs(daily_logs)
        
        -- Start flow - Work should show as completed
        local status, data = flow_manager:start_flow("activity")
        
        local work_option = nil
        for _, option in ipairs(data.data.options) do
            if option:find("Work") then
                work_option = option
                break
            end
        end
        
        assert_contains(work_option, "✓", "Work should show as completed even with specific option variant")
    end)
    
    -- Test that different activity options don't interfere
    test("Different activity options don't cross-contaminate completion status", function()
        local flow_manager = core.create_dialog_flow_manager()
        local data_manager = core.create_dialog_manager()
        
        local today = "2025-01-21" 
        local daily_logs = {[today] = {activities = {}}}
        
        -- Log Walk properly
        core.log_item(daily_logs, "activity", "Walk: Light")
        
        flow_manager:set_data_manager(data_manager)
        flow_manager:set_daily_logs(daily_logs)
        
        local status, data = flow_manager:start_flow("activity")
        
        local work_option = nil
        local walk_option = nil
        
        for _, option in ipairs(data.data.options) do
            if option:find("Work") then
                work_option = option
            elseif option:find("Walk") then
                walk_option = option
            end
        end
        
        -- Walk should be marked as completed, Work should not
        assert_contains(walk_option, "✓", "Walk should show as completed")
        if work_option:find("✓") then
            error("Work should NOT show as completed when only Walk was logged")
        end
    end)
    
    -- Test base item name extraction for completion checking
    test("Base item name extraction works for completion checking", function()
        local test_cases = {
            {"Work: From Home", "Work"},
            {"Walk: Heavy", "Walk"},  
            {"Meeting-heavy day", "Meeting-heavy day"}, -- No options
            {"Custom Activity", "Custom Activity"}
        }
        
        for _, case in ipairs(test_cases) do
            local logged_item = case[1]
            local expected_base = case[2]
            
            -- Extract base name using the same logic the system should use
            local base_name = logged_item:match("^(.-):%s*") or logged_item
            assert_equals(base_name, expected_base, "Base name extraction for " .. logged_item)
        end
    end)
    
    print("Suite Results: " .. tests_passed .. "/" .. tests_total .. " tests passed")
    
    if tests_passed == tests_total then
        print("\nActivity logging persistence tests passed!")
        return true
    else
        print("\n" .. (tests_total - tests_passed) .. " test(s) failed!")
        return false
    end
end

-- Run tests if called directly
if not TEST_RUNNER then
    run_activity_logging_persistence_tests()
else
    return {
        name = "Activity Logging Persistence", 
        run = run_activity_logging_persistence_tests
    }
end