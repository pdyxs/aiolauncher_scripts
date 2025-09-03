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

-- Import the test framework
local test = require "test_framework"
    
-- Test that logged activities with options show up as already logged
test.add_test("Activity with options shows as logged after completion", function()
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
    
    test.assert_equals("flow_complete", status, "Should complete flow")
    test.assert_equals("Work: From Home", result.item, "Should log combined item")
    
    -- 2. Actually log the item using the core logging function
    core.log_item(daily_logs, result.category, result.item)
    
    -- 3. Start a new flow and check if "Work" shows as already logged
    local new_flow_manager = core.create_dialog_flow_manager()
    new_flow_manager:set_data_manager(data_manager)
    new_flow_manager:set_daily_logs(daily_logs)
    
    local new_status, new_data = new_flow_manager:start_flow("activity")
    test.assert_equals("show_dialog", new_status, "Should show dialog")
    
    -- Check if "Work" option shows as already done
    local work_option = nil
    for _, option in ipairs(new_data.data.options) do
        if option:find("Work") then
            work_option = option
            break
        end
    end
    
    test.assert_contains(work_option, "✓", "Work should show as completed with checkmark")
end)
    
-- Test that specific option variant shows as logged
test.add_test("Specific activity option variant shows as logged", function()
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
    
    test.assert_contains(work_option, "✓", "Work should show as completed even with specific option variant")
end)
    
-- Test that different activity options don't interfere
test.add_test("Different activity options don't cross-contaminate completion status", function()
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
    test.assert_contains(walk_option, "✓", "Walk should show as completed")
    if work_option:find("✓") then
        error("Work should NOT show as completed when only Walk was logged")
    end
end)
    
-- Test base item name extraction for completion checking
test.add_test("Base item name extraction works for completion checking", function()
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
        test.assert_equals(expected_base, base_name, "Base name extraction for " .. logged_item)
    end
end)
    
-- Individual runner pattern
if ... == nil then
    test.run_tests("Activity Logging Persistence")
    local success = test.print_final_results()
    os.exit(success and 0 or 1)
end