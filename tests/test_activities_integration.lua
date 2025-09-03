-- test_activities_integration.lua
-- Integration tests for Activities Dialog Flow

-- Set path first
package.path = package.path .. ";../my/?.lua"

-- Mock AIO dependencies and override global files BEFORE loading core
files = {
    read = function(filename)
        if filename == "activities.md" then
            return [[# Test Activities

## Work  
- Work {Options: In Office, From Home}
- Meeting-heavy day

## Physical
- Walk {Options: Light, Medium, Heavy}
- Yin Yoga {Required: Thu}

## Daily Living  
- Cooking (simple)
- Shopping (quick)]]
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
    
-- Test activity flow initialization (using fallback data since file mocking is complex)
test.add_test("Activity flow initialization", function()
    local flow_manager = core.create_dialog_flow_manager()
    local data_manager = core.create_dialog_manager()
    
    flow_manager:set_data_manager(data_manager)
    flow_manager:set_daily_logs({["2025-01-21"] = {activities = {}}})
    
    local status, data = flow_manager:start_flow("activity")
    test.assert_equals("show_dialog", status, "Should return show_dialog status")
    test.assert_equals("radio", data.type, "Should be radio dialog")
    test.assert_equals("Log Activity", data.title, "Should have correct title")
    -- Test with fallback data (what the code actually uses)
    test.assert_contains(data.data.options, "   Work", "Should contain Work option") 
    test.assert_contains(data.data.options, "   Walk", "Should contain Walk option")
    test.assert_contains(data.data.options, "   Other...", "Should contain Other option")
end)
    
-- Test activity without options - direct completion
test.add_test("Activity without options - direct completion", function()
    local flow_manager = core.create_dialog_flow_manager()
    local data_manager = core.create_dialog_manager()
    
    flow_manager:set_data_manager(data_manager)
    flow_manager:set_daily_logs({["2025-01-21"] = {activities = {}}})
    
    -- Start flow and select activity
    flow_manager:start_flow("activity")
    
    -- Simulate selecting "Meeting-heavy day" (no options) 
    local status, result = flow_manager:handle_dialog_result(2) -- Meeting-heavy day is index 2 in fallback data
    test.assert_equals("flow_complete", status, "Should complete flow directly")
    test.assert_equals("activity", result.category, "Should be activity category")
    test.assert_equals("Meeting-heavy day", result.item, "Should log correct item")
end)
    
-- Test activity flow basic mechanics (using fallback data since file mocking is complex)
test.add_test("Activity flow basic mechanics", function()
    local flow_manager = core.create_dialog_flow_manager()
    local data_manager = core.create_dialog_manager()
    
    flow_manager:set_data_manager(data_manager)
    flow_manager:set_daily_logs({["2025-01-21"] = {activities = {}}})
    
    -- Test options flow: Work has options, should show options dialog
    flow_manager:start_flow("activity")
    local status, data = flow_manager:handle_dialog_result(1) -- Work is index 1, has options
    
    test.assert_equals("show_dialog", status, "Should show options dialog")
    test.assert_equals("Select Option", data.title, "Should have options dialog title")
    test.assert_contains(data.data.options, "In Office", "Should have In Office option")
    test.assert_contains(data.data.options, "From Home", "Should have From Home option")
    
    -- Select "From Home" option
    local final_status, result = flow_manager:handle_dialog_result(2) -- From Home
    test.assert_equals("flow_complete", final_status, "Should complete flow")
    test.assert_equals("activity", result.category, "Should be activity category")  
    test.assert_equals("Work: From Home", result.item, "Should log combined item")
end)
    
-- Test custom activity input
test.add_test("Custom activity input flow", function()
    local flow_manager = core.create_dialog_flow_manager()
    local data_manager = core.create_dialog_manager()
    
    flow_manager:set_data_manager(data_manager)
    flow_manager:set_daily_logs({["2025-01-21"] = {activities = {}}})
    
    -- Start flow and select "Other..." (should be last option - index 8 in fallback data)
    flow_manager:start_flow("activity") 
    local status, data = flow_manager:handle_dialog_result(9) -- "Other..." is index 9
    
    test.assert_equals("show_dialog", status, "Should show custom input dialog")
    test.assert_equals("edit", data.type, "Should be edit dialog")
    test.assert_equals("Custom Activity", data.title, "Should have custom input title")
    
    -- Enter custom activity
    local final_status, result = flow_manager:handle_dialog_result("Custom Exercise")
    test.assert_equals("flow_complete", final_status, "Should complete flow")
    test.assert_equals("activity", result.category, "Should be activity category")
    test.assert_equals("Custom Exercise", result.item, "Should log custom item")
end)
    
-- Test options parsing functionality  
test.add_test("Options parsing from activities content", function()
    local activities_content = files.read("activities.md")
    
    -- Test Work options
    local work_options = core.parse_item_options(activities_content, "Work")
    test.assert_equals(2, #work_options, "Work should have 2 options")
    test.assert_contains(work_options, "In Office", "Should contain In Office")
    test.assert_contains(work_options, "From Home", "Should contain From Home")
    
    -- Test Walk options
    local walk_options = core.parse_item_options(activities_content, "Walk")
    test.assert_equals(3, #walk_options, "Walk should have 3 options")
    test.assert_contains(walk_options, "Light", "Should contain Light")
    test.assert_contains(walk_options, "Medium", "Should contain Medium")
    test.assert_contains(walk_options, "Heavy", "Should contain Heavy")
    
    -- Test activity without options
    local yoga_options = core.parse_item_options(activities_content, "Yin Yoga")
    test.assert_equals(nil, yoga_options, "Yin Yoga should have no options")
    
    -- Test required activity parsing
    local cooking_options = core.parse_item_options(activities_content, "Cooking (simple)")
    test.assert_equals(nil, cooking_options, "Cooking (simple) should have no options")
end)
    
-- Test cancellation handling (accounts for AIO dialog quirk)
test.add_test("Activity flow cancellation", function()
    local flow_manager = core.create_dialog_flow_manager()
    local data_manager = core.create_dialog_manager()
    
    flow_manager:set_data_manager(data_manager)
    flow_manager:set_daily_logs({["2025-01-21"] = {activities = {}}})
    
    -- Start flow and cancel (first cancel is ignored due to AIO quirk)
    flow_manager:start_flow("activity")
    local first_cancel = flow_manager:handle_cancel()
    test.assert_equals("continue", first_cancel, "First cancel should be ignored (AIO quirk)")
    
    -- Second cancel should actually cancel
    local second_cancel = flow_manager:handle_cancel()
    test.assert_equals("flow_cancelled", second_cancel, "Second cancel should cancel flow")
end)
    
-- Individual runner pattern
if ... == nil then
    test.run_tests("Activities Dialog Flow Integration")
    local success = test.print_final_results()
    os.exit(success and 0 or 1)
end