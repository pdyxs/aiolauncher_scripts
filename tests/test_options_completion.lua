#!/usr/bin/env lua

-- Test for Options completion logic - ensuring required items with {Options:} 
-- are properly detected as completed when logged with option variants

package.path = package.path .. ";../my/?.lua"
local core = require "long_covid_core" 
local test = require "test_framework"

-- Test data for activities and interventions with Options syntax
local activities_with_options_content = [[# Test Activities

## Physical
- Yin Yoga {Required} {Options: Morning, Evening}
- Walk {Options: Light, Medium, Heavy}

## Work
- Work {Required: Mon,Wed,Fri} {Options: In Office, From Home}
]]

local interventions_with_options_content = [[# Test Interventions

## Medications
- LDN (4mg)

## Supplements
- Salvital {Required} {Options: Morning, Evening}
- Vitamin D {Options: Morning, Evening}
]]

test.add_test("Options completion - activity with options logged", function()
    local required_activities = core.parse_items_with_metadata(activities_with_options_content, "activities").metadata
    local daily_logs = {}
    
    -- Mock date to Tuesday when only Yin Yoga is required (not Work which is Mon,Wed,Fri)
    local original_date = os.date
    os.date = function(format)
        if format == "*t" then
            return {year = 2023, month = 8, day = 29, wday = 3} -- Tuesday
        elseif format == "%Y-%m-%d" then
            return "2023-08-29"
        elseif format == "%w" then
            return "2"  -- Tuesday is day 2 (0=Sun, 1=Mon, 2=Tue)
        else
            return original_date(format)
        end
    end
    
    -- Log activity with option (this was the bug scenario)
    core.log_item_with_tasker(daily_logs, "activity", "Yin Yoga: Morning", nil, function(msg) end)
    
    local activities_complete = core.are_all_required_items_completed(daily_logs, required_activities, "activities")
    test.assert_true(activities_complete, "Should complete required activity when logged with option")
    
    -- Restore original date function
    os.date = original_date
end)

test.add_test("Options completion - intervention with options logged", function()
    local required_interventions = core.parse_items_with_metadata(interventions_with_options_content, "interventions").metadata
    local daily_logs = {}
    
    -- Log intervention with option
    core.log_item_with_tasker(daily_logs, "intervention", "Salvital: Evening", nil, function(msg) end)
    
    local interventions_complete = core.are_all_required_items_completed(daily_logs, required_interventions, "interventions")
    test.assert_true(interventions_complete, "Should complete required intervention when logged with option")
end)

test.add_test("Options completion - mixed exact and option logging", function()
    local activities_content = [[# Mixed Test Activities
## Physical
- Exercise {Required}
- Yin Yoga {Required} {Options: Morning, Evening}
]]
    
    local interventions_content = [[# Mixed Test Interventions  
## Supplements
- Salvital {Required} {Options: Morning, Evening}
]]
    
    local required_activities = core.parse_items_with_metadata(activities_content, "activities").metadata
    local required_interventions = core.parse_items_with_metadata(interventions_content, "interventions").metadata
    local daily_logs = {}
    
    -- Log one item with exact match, one with option
    core.log_item_with_tasker(daily_logs, "activity", "Exercise", nil, function(msg) end)           -- exact match
    core.log_item_with_tasker(daily_logs, "activity", "Yin Yoga: Evening", nil, function(msg) end)  -- with option
    core.log_item_with_tasker(daily_logs, "intervention", "Salvital: Morning", nil, function(msg) end) -- with option
    
    local activities_complete = core.are_all_required_items_completed(daily_logs, required_activities, "activities")
    local interventions_complete = core.are_all_required_items_completed(daily_logs, required_interventions, "interventions")
    
    test.assert_true(activities_complete, "Should handle mixed exact match and option logging for activities")
    test.assert_true(interventions_complete, "Should handle intervention logged with option")
end)

test.add_test("Options completion - multiple options for same base item", function()
    local required_activities = core.parse_items_with_metadata(activities_with_options_content, "activities").metadata
    local daily_logs = {}
    
    -- Mock date to Tuesday when only Yin Yoga is required (not Work which is Mon,Wed,Fri)
    local original_date = os.date
    os.date = function(format)
        if format == "*t" then
            return {year = 2023, month = 8, day = 29, wday = 3} -- Tuesday
        elseif format == "%Y-%m-%d" then
            return "2023-08-29"
        elseif format == "%w" then
            return "2"  -- Tuesday is day 2 (0=Sun, 1=Mon, 2=Tue)
        else
            return original_date(format)
        end
    end
    
    -- Log same base item with multiple options
    core.log_item_with_tasker(daily_logs, "activity", "Yin Yoga: Morning", nil, function(msg) end)
    core.log_item_with_tasker(daily_logs, "activity", "Yin Yoga: Evening", nil, function(msg) end)
    
    local activities_complete = core.are_all_required_items_completed(daily_logs, required_activities, "activities")
    test.assert_true(activities_complete, "Should handle multiple options of same required item")
    
    -- Verify counts are summed correctly
    local today = core.get_today_date()
    local logs = core.get_daily_logs(daily_logs, today)
    
    -- Restore original date function
    os.date = original_date
    test.assert_equals(logs.activities["Yin Yoga: Morning"], 1, "Should track morning option")
    test.assert_equals(logs.activities["Yin Yoga: Evening"], 1, "Should track evening option")
end)

test.add_test("Options completion - partial completion still incomplete", function()
    local activities_content = [[# Test Activities
## Required Items
- Task A {Required}
- Task B {Required} {Options: Option1, Option2}
]]
    
    local required_activities = core.parse_items_with_metadata(activities_content, "activities").metadata
    local daily_logs = {}
    
    -- Only complete one of two required tasks
    core.log_item_with_tasker(daily_logs, "activity", "Task B: Option1", nil, function(msg) end)
    
    local activities_complete = core.are_all_required_items_completed(daily_logs, required_activities, "activities")
    test.assert_false(activities_complete, "Should not be complete when only some required items are logged")
end)

test.add_test("Options completion - day-specific requirements", function()
    -- Mock to a Wednesday to test day-specific requirements
    local original_date = os.date
    os.date = function(format)
        if format == "*t" then
            return {year = 2023, month = 8, day = 30, wday = 4} -- Wednesday
        elseif format == "%Y-%m-%d" then
            return "2023-08-30"
        else
            return original_date(format)
        end
    end
    
    local required_activities = core.parse_items_with_metadata(activities_with_options_content, "activities").metadata
    local daily_logs = {}
    
    -- Work is required on Mon,Wed,Fri - we're testing Wednesday
    core.log_item_with_tasker(daily_logs, "activity", "Work: From Home", nil, function(msg) end)
    core.log_item_with_tasker(daily_logs, "activity", "Yin Yoga: Morning", nil, function(msg) end)
    
    local activities_complete = core.are_all_required_items_completed(daily_logs, required_activities, "activities")
    test.assert_true(activities_complete, "Should complete day-specific required items with options")
    
    os.date = original_date
end)

-- Run tests if this file is executed directly
if ... == nil then
    test.run_tests("Options Completion Logic")
    local success = test.print_final_results()
    os.exit(success and 0 or 1)
end