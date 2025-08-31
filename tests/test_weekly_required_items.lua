-- test_weekly_required_items.lua - Tests for weekly required items functionality
-- Tests date calculation, weekly requirement checking, and integration with existing systems
-- These tests should FAIL initially (RED phase of TDD cycle)

-- Add paths for imports
package.path = package.path .. ";../my/?.lua;./?.lua"

local test = require "test_framework"
local data = require "test_data"
local core = require "long_covid_core"

-- Test: Date calculation functions
test.add_test("Calculate date N days ago", function()
    -- Mock specific date for predictable testing
    local mock_date, original_date = data.mock_os_date("2023-08-30") -- Wednesday
    os.date = mock_date
    
    -- Test getting dates going backwards
    test.assert_equals("2023-08-29", core.get_date_days_ago(1), "Should return yesterday")
    test.assert_equals("2023-08-28", core.get_date_days_ago(2), "Should return 2 days ago")
    test.assert_equals("2023-08-23", core.get_date_days_ago(7), "Should return 1 week ago")
    test.assert_equals("2023-08-30", core.get_date_days_ago(0), "Should return today for 0 days")
    
    os.date = original_date
end)

test.add_test("Calculate date N days ago with month boundaries", function()
    -- Test month boundary edge case
    local mock_date, original_date = data.mock_os_date("2023-09-02") -- September 2nd
    os.date = mock_date
    
    test.assert_equals("2023-08-31", core.get_date_days_ago(2), "Should handle month boundary")
    test.assert_equals("2023-08-26", core.get_date_days_ago(7), "Should handle week crossing month boundary")
    
    os.date = original_date
end)

test.add_test("Calculate date N days ago with year boundaries", function()
    -- Test year boundary edge case
    local mock_date, original_date = data.mock_os_date("2024-01-03") -- January 3rd
    os.date = mock_date
    
    test.assert_equals("2023-12-31", core.get_date_days_ago(3), "Should handle year boundary")
    test.assert_equals("2023-12-27", core.get_date_days_ago(7), "Should handle week crossing year boundary")
    
    os.date = original_date
end)

test.add_test("Calculate date N days ago with leap year", function()
    -- Test leap year edge case
    local mock_date, original_date = data.mock_os_date("2024-03-01") -- March 1st in leap year
    os.date = mock_date
    
    test.assert_equals("2024-02-29", core.get_date_days_ago(1), "Should handle leap year Feb 29")
    test.assert_equals("2024-02-23", core.get_date_days_ago(7), "Should handle week in leap year")
    
    os.date = original_date
end)

test.add_test("Get last N dates array", function()
    local mock_date, original_date = data.mock_os_date("2023-08-30")
    os.date = mock_date
    
    local last_7_dates = core.get_last_n_dates(7)
    test.assert_equals(7, #last_7_dates, "Should return 7 dates")
    test.assert_equals("2023-08-30", last_7_dates[1], "First date should be today")
    test.assert_equals("2023-08-24", last_7_dates[7], "Last date should be 6 days ago")
    
    local last_3_dates = core.get_last_n_dates(3)
    test.assert_equals(3, #last_3_dates, "Should return 3 dates")
    test.assert_equals("2023-08-30", last_3_dates[1], "Should include today")
    test.assert_equals("2023-08-28", last_3_dates[3], "Should include 2 days ago")
    
    os.date = original_date
end)

-- Test: Weekly syntax parsing
test.add_test("Parse weekly required items from activities content", function()
    local activities_content = [[
# Long Covid Activities

## Physical
- Light walk
- Physio (full) {Required: Mon,Wed,Fri}
- Yin Yoga {Required}
- Eye mask {Required: Weekly}
- Supplements {Required: Weekly}

## Work
- Work from home
- Office work {Required: Weekly}
]]
    
    local parsed_activities = core.parse_activities(activities_content)
    local weekly_items = core.get_weekly_required_items(parsed_activities)
    
    test.assert_equals(3, #weekly_items, "Should find 3 weekly required items")
    -- Check that weekly_items contains objects with correct names
    local names = {}
    for _, item in ipairs(weekly_items) do
        table.insert(names, item.name)
    end
    test.assert_contains(names, "Eye mask", "Should include Eye mask")
    test.assert_contains(names, "Supplements", "Should include Supplements") 
    test.assert_contains(names, "Office work", "Should include Office work")
end)

test.add_test("Parse weekly required items from interventions content", function()
    local interventions_content = [[
# Long Covid Interventions

## Treatments
- Ice bath {Required: Weekly}
- Massage therapy {Required: Mon,Wed}
- Meditation {Required}

## Supplements
- Vitamin D {Required: Weekly}
- B-complex daily {Required}
]]
    
    local parsed_interventions = core.parse_interventions(interventions_content)
    local weekly_items = core.get_weekly_required_items(parsed_interventions)
    
    test.assert_equals(2, #weekly_items, "Should find 2 weekly required items")
    -- Check that weekly_items contains objects with correct names
    local names = {}
    for _, item in ipairs(weekly_items) do
        table.insert(names, item.name)
    end
    test.assert_contains(names, "Ice bath", "Should include Ice bath")
    test.assert_contains(names, "Vitamin D", "Should include Vitamin D")
end)

test.add_test("Weekly syntax works with Options syntax", function()
    local content = [[
# Test Items

## Combined Syntax
- Stretching {Options: Light,Full} {Required: Weekly}
- Exercise {Required: Weekly} {Options: Walk,Run,Swim}
- Meal prep {Required: Weekly}
]]
    
    local parsed_items = core.parse_activities(content)
    local weekly_items = core.get_weekly_required_items(parsed_items)
    
    test.assert_equals(3, #weekly_items, "Should find 3 weekly required items")
    -- Check that weekly_items contains objects with correct names
    local names = {}
    for _, item in ipairs(weekly_items) do
        table.insert(names, item.name)
    end
    test.assert_contains(names, "Stretching", "Should parse weekly + options")
    test.assert_contains(names, "Exercise", "Should parse options + weekly")
    test.assert_contains(names, "Meal prep", "Should parse simple weekly")
end)

-- Test: 7-day log retention logic
test.add_test("Purge old logs retains 7 days for weekly requirements", function()
    local mock_date, original_date = data.mock_os_date("2023-08-30")
    os.date = mock_date
    
    -- Create logs for 10 days to test retention
    local daily_logs = {}
    for i = 0, 9 do
        local date = core.get_date_days_ago(i)
        daily_logs[date] = {
            symptoms = {},
            activities = {["Eye mask"] = 1},
            interventions = {},
            energy_levels = {}
        }
    end
    
    local purged_logs = core.purge_old_daily_logs_weekly(daily_logs, "2023-08-30")
    
    -- Should keep 7 days: today + previous 6 days
    test.assert_equals(7, core.count_log_days(purged_logs), "Should keep 7 days of logs")
    
    -- Verify it keeps the right days
    test.assert_not_nil(purged_logs["2023-08-30"], "Should keep today")
    test.assert_not_nil(purged_logs["2023-08-24"], "Should keep 6 days ago")
    test.assert_nil(purged_logs["2023-08-23"], "Should purge 7+ days ago")
    
    os.date = original_date
end)

-- Test: Weekly requirement checking logic
test.add_test("Check weekly requirement - item logged within 7 days", function()
    local mock_date, original_date = data.mock_os_date("2023-08-30") -- Wednesday
    os.date = mock_date
    
    local daily_logs = {}
    -- Log "Eye mask" 3 days ago
    daily_logs["2023-08-27"] = {
        symptoms = {},
        activities = {["Eye mask"] = 1},
        interventions = {},
        energy_levels = {}
    }
    
    local is_required = core.is_weekly_item_required("Eye mask", daily_logs)
    
    test.assert_false(is_required, "Item should NOT be required if logged within 7 days")
    
    os.date = original_date
end)

test.add_test("Check weekly requirement - item not logged in 7 days", function()
    local mock_date, original_date = data.mock_os_date("2023-08-30") -- Wednesday
    os.date = mock_date
    
    local daily_logs = {}
    -- Log "Eye mask" 8 days ago (outside 7-day window)
    daily_logs["2023-08-22"] = {
        symptoms = {},
        activities = {["Eye mask"] = 1},
        interventions = {},
        energy_levels = {}
    }
    
    local is_required = core.is_weekly_item_required("Eye mask", daily_logs)
    
    test.assert_true(is_required, "Item should be required if not logged within 7 days")
    
    os.date = original_date
end)

test.add_test("Check weekly requirement - item never logged", function()
    local mock_date, original_date = data.mock_os_date("2023-08-30")
    os.date = mock_date
    
    local daily_logs = {} -- Empty logs
    
    local is_required = core.is_weekly_item_required("Eye mask", daily_logs)
    
    test.assert_true(is_required, "Item should be required if never logged")
    
    os.date = original_date
end)

test.add_test("Check weekly requirement - multiple logs per day", function()
    local mock_date, original_date = data.mock_os_date("2023-08-30")
    os.date = mock_date
    
    local daily_logs = {}
    -- Multiple logs on same day should still count as "logged on that day"
    daily_logs["2023-08-29"] = {
        symptoms = {},
        activities = {["Eye mask"] = 3}, -- Multiple entries
        interventions = {},
        energy_levels = {}
    }
    
    local is_required = core.is_weekly_item_required("Eye mask", daily_logs)
    
    test.assert_false(is_required, "Multiple logs per day should still satisfy requirement")
    
    os.date = original_date
end)

test.add_test("Check weekly requirement - exact 7-day boundary", function()
    local mock_date, original_date = data.mock_os_date("2023-08-30") -- Wednesday
    os.date = mock_date
    
    local daily_logs = {}
    -- Log exactly 7 days ago should make it required (outside 7-day window)
    daily_logs["2023-08-23"] = {
        symptoms = {},
        activities = {["Eye mask"] = 1},
        interventions = {},
        energy_levels = {}
    }
    
    local is_required = core.is_weekly_item_required("Eye mask", daily_logs)
    
    test.assert_true(is_required, "Item logged 7+ days ago should be required")
    
    -- But 6 days ago should not be required
    daily_logs["2023-08-24"] = {
        symptoms = {},
        activities = {["Eye mask"] = 1},
        interventions = {},
        energy_levels = {}
    }
    
    local is_not_required = core.is_weekly_item_required("Eye mask", daily_logs)
    
    test.assert_false(is_not_required, "Item logged 6 days ago should NOT be required")
    
    os.date = original_date
end)

-- Test: Integration with button color system
test.add_test("Weekly items integrate with button color system", function()
    local activities = {
        {name = "Light walk", category = "Physical"},
        {name = "Eye mask", category = "Physical", weekly_required = true}
    }
    
    local interventions = {
        {name = "Meditation", category = "Mental", required = true},
        {name = "Ice bath", category = "Recovery", weekly_required = true}
    }
    
    local mock_date, original_date = data.mock_os_date("2023-08-30")
    os.date = mock_date
    
    local daily_logs = {}
    -- Log daily required but not weekly required
    daily_logs["2023-08-30"] = {
        symptoms = {},
        activities = {},
        interventions = {["Meditation"] = 1},
        energy_levels = {}
    }
    
    local activity_colors = core.get_button_colors(activities, "activities", daily_logs)
    local intervention_colors = core.get_button_colors(interventions, "interventions", daily_logs)
    
    test.assert_equals("default", activity_colors["Light walk"], "Non-required should be default")
    test.assert_equals("required", activity_colors["Eye mask"], "Weekly required should be red")
    test.assert_equals("completed", intervention_colors["Meditation"], "Daily completed should be green")
    test.assert_equals("required", intervention_colors["Ice bath"], "Weekly required should be red")
    
    os.date = original_date
end)

-- Test: Edge cases and error handling
test.add_test("Handle malformed weekly syntax gracefully", function()
    local content = [[
# Malformed Test

## Items
- Good item {Required: Weekly}
- Bad syntax {Required: }
- Missing close {Required: Weekly
- Extra spaces { Required : Weekly }
- Empty item {Required: Weekly}
]]
    
    local parsed_items = core.parse_activities(content)
    local weekly_items = core.get_weekly_required_items(parsed_items)
    
    -- Should handle gracefully and find valid ones
    test.assert_true(#weekly_items >= 1, "Should find at least valid weekly items")
    -- Check that weekly_items contains objects with correct names
    local names = {}
    for _, item in ipairs(weekly_items) do
        table.insert(names, item.name)
    end
    test.assert_contains(names, "Good item", "Should parse correctly formatted item")
end)

test.add_test("Weekly requirement checking with empty or nil logs", function()
    local is_required_nil = core.is_weekly_item_required("Eye mask", nil)
    test.assert_true(is_required_nil, "Should handle nil logs")
    
    local is_required_empty = core.is_weekly_item_required("Eye mask", {})
    test.assert_true(is_required_empty, "Should handle empty logs")
end)

test.add_test("Date calculations with invalid input", function()
    test.assert_equals(nil, core.get_date_days_ago(-1), "Should handle negative days")
    test.assert_equals(nil, core.get_date_days_ago("invalid"), "Should handle non-numeric input")
    
    local empty_dates = core.get_last_n_dates(0)
    test.assert_equals(0, #empty_dates, "Should handle zero days request")
end)

-- Test: Mock data scenarios from feature requirements
test.add_test("Feature scenario - Eye mask weekly requirement", function()
    local mock_date, original_date = data.mock_os_date("2023-08-30") -- Wednesday
    os.date = mock_date
    
    -- Scenario: User logged Eye mask on Monday (2 days ago)
    local daily_logs = {}
    daily_logs["2023-08-28"] = { -- Monday
        symptoms = {},
        activities = {["Eye mask"] = 1},
        interventions = {},
        energy_levels = {}
    }
    
    -- Wednesday: Should not be required yet (only 2 days)
    local wed_required = core.is_weekly_item_required("Eye mask", daily_logs)
    test.assert_false(wed_required, "Eye mask should not be required on Wednesday after Monday log")
    
    -- Fast forward to next Monday (7 days later)
    local mock_date_next_mon, _ = data.mock_os_date("2023-09-04") -- Next Monday
    os.date = mock_date_next_mon
    
    local mon_required = core.is_weekly_item_required("Eye mask", daily_logs)
    test.assert_true(mon_required, "Eye mask should be required next Monday")
    
    os.date = original_date
end)

print("Weekly Required Items Test Suite loaded - " .. #test.tests .. " tests")