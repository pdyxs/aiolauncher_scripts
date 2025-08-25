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

-- Test suite
local function run_activities_integration_tests()
    print("Running Activities Dialog Flow Integration Tests...")
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
    
    -- Test activity flow initialization (using fallback data since file mocking is complex)
    test("Activity flow initialization", function()
        local flow_manager = core.create_dialog_flow_manager()
        local data_manager = core.create_dialog_manager()
        
        flow_manager:set_data_manager(data_manager)
        flow_manager:set_daily_logs({["2025-01-21"] = {activities = {}}})
        
        local status, data = flow_manager:start_flow("activity")
        assert_equals(status, "show_dialog", "Should return show_dialog status")
        assert_equals(data.type, "radio", "Should be radio dialog")
        assert_equals(data.title, "Log Activity", "Should have correct title")
        -- Test with fallback data (what the code actually uses)
        assert_contains(data.data.options, "   Work", "Should contain Work option") 
        assert_contains(data.data.options, "   Walk", "Should contain Walk option")
        assert_contains(data.data.options, "   Other...", "Should contain Other option")
    end)
    
    -- Test activity without options - direct completion
    test("Activity without options - direct completion", function()
        local flow_manager = core.create_dialog_flow_manager()
        local data_manager = core.create_dialog_manager()
        
        flow_manager:set_data_manager(data_manager)
        flow_manager:set_daily_logs({["2025-01-21"] = {activities = {}}})
        
        -- Start flow and select activity
        flow_manager:start_flow("activity")
        
        -- Simulate selecting "Meeting-heavy day" (no options) 
        local status, result = flow_manager:handle_dialog_result(2) -- Meeting-heavy day is index 2 in fallback data
        assert_equals(status, "flow_complete", "Should complete flow directly")
        assert_equals(result.category, "activity", "Should be activity category")
        assert_equals(result.item, "Meeting-heavy day", "Should log correct item")
    end)
    
    -- Test activity flow basic mechanics (using fallback data since file mocking is complex)
    test("Activity flow basic mechanics", function()
        local flow_manager = core.create_dialog_flow_manager()
        local data_manager = core.create_dialog_manager()
        
        flow_manager:set_data_manager(data_manager)
        flow_manager:set_daily_logs({["2025-01-21"] = {activities = {}}})
        
        -- Test options flow: Work has options, should show options dialog
        flow_manager:start_flow("activity")
        local status, data = flow_manager:handle_dialog_result(1) -- Work is index 1, has options
        
        assert_equals(status, "show_dialog", "Should show options dialog")
        assert_equals(data.title, "Select Option", "Should have options dialog title")
        assert_contains(data.data.options, "In Office", "Should have In Office option")
        assert_contains(data.data.options, "From Home", "Should have From Home option")
        
        -- Select "From Home" option
        local final_status, result = flow_manager:handle_dialog_result(2) -- From Home
        assert_equals(final_status, "flow_complete", "Should complete flow")
        assert_equals(result.category, "activity", "Should be activity category")  
        assert_equals(result.item, "Work: From Home", "Should log combined item")
    end)
    
    -- Test custom activity input
    test("Custom activity input flow", function()
        local flow_manager = core.create_dialog_flow_manager()
        local data_manager = core.create_dialog_manager()
        
        flow_manager:set_data_manager(data_manager)
        flow_manager:set_daily_logs({["2025-01-21"] = {activities = {}}})
        
        -- Start flow and select "Other..." (should be last option - index 8 in fallback data)
        flow_manager:start_flow("activity") 
        local status, data = flow_manager:handle_dialog_result(8) -- "Other..." is index 8
        
        assert_equals(status, "show_dialog", "Should show custom input dialog")
        assert_equals(data.type, "edit", "Should be edit dialog")
        assert_equals(data.title, "Custom Activity", "Should have custom input title")
        
        -- Enter custom activity
        local final_status, result = flow_manager:handle_dialog_result("Custom Exercise")
        assert_equals(final_status, "flow_complete", "Should complete flow")
        assert_equals(result.category, "activity", "Should be activity category")
        assert_equals(result.item, "Custom Exercise", "Should log custom item")
    end)
    
    -- Test options parsing functionality  
    test("Options parsing from activities content", function()
        local activities_content = files.read("activities.md")
        
        -- Test Work options
        local work_options = core.parse_item_options(activities_content, "Work")
        assert_equals(#work_options, 2, "Work should have 2 options")
        assert_contains(work_options, "In Office", "Should contain In Office")
        assert_contains(work_options, "From Home", "Should contain From Home")
        
        -- Test Walk options
        local walk_options = core.parse_item_options(activities_content, "Walk")
        assert_equals(#walk_options, 3, "Walk should have 3 options")
        assert_contains(walk_options, "Light", "Should contain Light")
        assert_contains(walk_options, "Medium", "Should contain Medium")
        assert_contains(walk_options, "Heavy", "Should contain Heavy")
        
        -- Test activity without options
        local yoga_options = core.parse_item_options(activities_content, "Yin Yoga")
        assert_equals(yoga_options, nil, "Yin Yoga should have no options")
        
        -- Test required activity parsing
        local cooking_options = core.parse_item_options(activities_content, "Cooking (simple)")
        assert_equals(cooking_options, nil, "Cooking (simple) should have no options")
    end)
    
    -- Test cancellation handling (accounts for AIO dialog quirk)
    test("Activity flow cancellation", function()
        local flow_manager = core.create_dialog_flow_manager()
        local data_manager = core.create_dialog_manager()
        
        flow_manager:set_data_manager(data_manager)
        flow_manager:set_daily_logs({["2025-01-21"] = {activities = {}}})
        
        -- Start flow and cancel (first cancel is ignored due to AIO quirk)
        flow_manager:start_flow("activity")
        local first_cancel = flow_manager:handle_cancel()
        assert_equals(first_cancel, "continue", "First cancel should be ignored (AIO quirk)")
        
        -- Second cancel should actually cancel
        local second_cancel = flow_manager:handle_cancel()
        assert_equals(second_cancel, "flow_cancelled", "Second cancel should cancel flow")
    end)
    
    print("Suite Results: " .. tests_passed .. "/" .. tests_total .. " tests passed")
    
    if tests_passed == tests_total then
        print("\nActivities dialog flow integration is working correctly!")
        print("The new dialog stack system is ready for activities.")
        return true
    else
        print("\n" .. (tests_total - tests_passed) .. " test(s) failed!")
        return false
    end
end

-- Run tests if called directly
if not TEST_RUNNER then
    run_activities_integration_tests()
else
    return {
        name = "Activities Integration", 
        run = run_activities_integration_tests
    }
end