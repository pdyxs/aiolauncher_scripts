-- test_consolidated_completion.lua - Tests for Phase 2 consolidated completion logic

-- Add paths for imports
package.path = package.path .. ";../my/?.lua;./?.lua"

local test = require "test_framework"
local data = require "test_data"
local core = require "long_covid_core"

-- Test: Consolidated get_required_items_for_today function
test.add_test("Consolidated get_required_items_for_today - activities", function()
    local mock_date, original_date = data.mock_os_date("2023-08-30") -- Wednesday
    os.date = mock_date
    
    local required_activities = {
        {name = "Work", required = true},
        {name = "Exercise", required = false, days = {"wed", "fri"}},  -- Use lowercase to match get_current_day_abbrev()
        {name = "Eye mask", weekly_required = true}
    }
    
    local daily_logs = {
        ["2023-08-29"] = { activities = {["Eye mask"] = 1} } -- Yesterday
    }
    
    local result = core.get_required_items_for_today(required_activities, daily_logs)
    
    -- Should include Work (daily required) and Exercise (Wednesday) but not Eye mask (logged yesterday)
    test.assert_equals(2, #result, "Should return 2 required activities")
    test.assert_contains(result, "Work", "Should include Work (daily required)")
    test.assert_contains(result, "Exercise", "Should include Exercise (Wednesday)")
    
    os.date = original_date
end)

test.add_test("Consolidated get_required_items_for_today - interventions", function()
    local mock_date, original_date = data.mock_os_date("2023-08-30") -- Wednesday  
    os.date = mock_date
    
    local required_interventions = {
        {name = "LDN (4mg)", required = true},
        {name = "Meditation", required = false},
        {name = "Vitamin D", weekly_required = true}
    }
    
    local daily_logs = {}
    
    local result = core.get_required_items_for_today(required_interventions, daily_logs)
    
    -- Should include LDN (daily required) and Vitamin D (weekly, not logged) but not Meditation (not required)
    test.assert_equals(2, #result, "Should return 2 required interventions")
    test.assert_contains(result, "LDN (4mg)", "Should include LDN (daily required)")
    test.assert_contains(result, "Vitamin D", "Should include Vitamin D (weekly required)")
    
    os.date = original_date
end)

-- Test: Consolidated are_all_required_items_completed function
test.add_test("Consolidated completion check - all activities completed", function()
    local mock_date, original_date = data.mock_os_date("2023-08-30")
    os.date = mock_date
    
    local required_activities = {
        {name = "Work", required = true},
        {name = "Exercise", required = true}
    }
    
    local daily_logs = {
        ["2023-08-30"] = {
            activities = {
                ["Work"] = 1,
                ["Exercise"] = 1
            }
        }
    }
    
    local result = core.are_all_required_items_completed(daily_logs, required_activities, "activities")
    test.assert_true(result, "Should return true when all activities completed")
    
    os.date = original_date
end)

test.add_test("Consolidated completion check - missing interventions", function()
    local mock_date, original_date = data.mock_os_date("2023-08-30")
    os.date = mock_date
    
    local required_interventions = {
        {name = "LDN (4mg)", required = true},
        {name = "Meditation", required = true}
    }
    
    local daily_logs = {
        ["2023-08-30"] = {
            interventions = {
                ["LDN (4mg)"] = 1
                -- Missing Meditation
            }
        }
    }
    
    local result = core.are_all_required_items_completed(daily_logs, required_interventions, "interventions")
    test.assert_false(result, "Should return false when interventions missing")
    
    os.date = original_date
end)

test.add_test("Consolidated completion check - options handling", function()
    local mock_date, original_date = data.mock_os_date("2023-08-30")
    os.date = mock_date
    
    local required_activities = {
        {name = "Work", required = true}
    }
    
    local daily_logs = {
        ["2023-08-30"] = {
            activities = {
                ["Work: From Home"] = 1  -- Option variant should count
            }
        }
    }
    
    local result = core.are_all_required_items_completed(daily_logs, required_activities, "activities")
    test.assert_true(result, "Should handle option variants (Work: From Home counts as Work)")
    
    os.date = original_date
end)

test.add_test("Consolidated completion check - no requirements", function()
    local mock_date, original_date = data.mock_os_date("2023-08-30")
    os.date = mock_date
    
    local no_requirements = {}
    local daily_logs = {["2023-08-30"] = {activities = {}}}
    
    local result = core.are_all_required_items_completed(daily_logs, no_requirements, "activities")
    test.assert_true(result, "Should return true when no requirements")
    
    os.date = original_date
end)


-- Test: Feature parity between activities and interventions
test.add_test("Feature parity - both item types handle weekly requirements", function()
    local weekly_activities = {
        {name = "Eye mask", weekly_required = true}
    }
    
    local weekly_interventions = {
        {name = "Massage", weekly_required = true}
    }
    
    local daily_logs = {
        ["2023-08-25"] = { -- 5 days ago
            activities = {["Eye mask"] = 1},
            interventions = {["Massage"] = 1}
        }
    }
    
    local mock_date, original_date = data.mock_os_date("2023-08-30")
    os.date = mock_date
    
    -- Both should handle weekly requirements identically
    local activities_result = core.are_all_required_items_completed(daily_logs, weekly_activities, "activities")
    local interventions_result = core.are_all_required_items_completed(daily_logs, weekly_interventions, "interventions")
    
    test.assert_true(activities_result, "Activities should handle weekly requirements")
    test.assert_true(interventions_result, "Interventions should handle weekly requirements")
    
    os.date = original_date
end)

test.add_test("Feature parity - both item types handle options", function()
    local mock_date, original_date = data.mock_os_date("2023-08-30")
    os.date = mock_date
    
    local activities_with_options = {
        {name = "Work", required = true}
    }
    
    local interventions_with_options = {
        {name = "Medication", required = true}
    }
    
    local daily_logs = {
        ["2023-08-30"] = {
            activities = {["Work: From Home"] = 1},
            interventions = {["Medication: Morning"] = 1}
        }
    }
    
    -- Both should handle option variants identically
    local activities_result = core.are_all_required_items_completed(daily_logs, activities_with_options, "activities")
    local interventions_result = core.are_all_required_items_completed(daily_logs, interventions_with_options, "interventions")
    
    test.assert_true(activities_result, "Activities should handle options")
    test.assert_true(interventions_result, "Interventions should handle options")
    
    os.date = original_date
end)

print("Consolidated Completion Logic Test Suite loaded - " .. #test.tests .. " tests")