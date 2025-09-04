local test = require "test_framework"

-- Load the weekly requirements module
local weekly = require "long_covid_weekly"

-- Mock date_utils for consistent testing
local date_utils = require "long_covid_date"
local original_get_last_n_dates = date_utils.get_last_n_dates

-- Test get_weekly_required_items function
test.add_test("get_weekly_required_items extracts weekly items from parsed metadata", function()
    local parsed_items = {
        {name = "Exercise", required = true, weekly_required = false},
        {name = "Eye mask", required = false, weekly_required = true},
        {name = "Vitamin shot", required = false, weekly_required = true},
        {name = "Daily walk", required = true, weekly_required = false}
    }
    
    local weekly_items = weekly.get_weekly_required_items(parsed_items)
    
    test.assert_equals(2, #weekly_items, "Should find 2 weekly items")
    test.assert_equals("Eye mask", weekly_items[1].name, "Should include Eye mask")
    test.assert_equals("Vitamin shot", weekly_items[2].name, "Should include Vitamin shot")
end)

test.add_test("get_weekly_required_items handles string content", function()
    local content = [[
- Exercise {Required}
- Eye mask {Required: Weekly}
- Vitamin shot {Required: Weekly}
- Daily walk {Required}
]]
    
    local weekly_items = weekly.get_weekly_required_items(content)
    
    test.assert_equals(2, #weekly_items, "Should find 2 weekly items")
    test.assert_contains(weekly_items, "Eye mask", "Should include Eye mask")
    test.assert_contains(weekly_items, "Vitamin shot", "Should include Vitamin shot")
end)

test.add_test("get_weekly_required_items handles empty/nil input", function()
    test.assert_equals(0, #weekly.get_weekly_required_items(nil), "Should return empty for nil")
    test.assert_equals(0, #weekly.get_weekly_required_items({}), "Should return empty for empty array")
    test.assert_equals(0, #weekly.get_weekly_required_items(""), "Should return empty for empty string")
end)

-- Test is_weekly_item_required function  
test.add_test("is_weekly_item_required detects item logged in last 7 days", function()
    local daily_logs = {
        ["2023-08-28"] = {activities = {["Eye mask"] = 1}}, -- 2 days ago
        ["2023-08-25"] = {activities = {["Exercise"] = 1}} -- 5 days ago
    }
    
    -- Mock last 7 dates
    date_utils.get_last_n_dates = function(n)
        if n == 7 then
            return {"2023-08-30", "2023-08-29", "2023-08-28", "2023-08-27", 
                    "2023-08-26", "2023-08-25", "2023-08-24"}
        end
        return original_get_last_n_dates(n)
    end
    
    test.assert_false(weekly.is_weekly_item_required("Eye mask", daily_logs), "Should not be required if logged 2 days ago")
    test.assert_false(weekly.is_weekly_item_required("Exercise", daily_logs), "Should not be required if logged 5 days ago")
    test.assert_true(weekly.is_weekly_item_required("Vitamin shot", daily_logs), "Should be required if not logged")
    
    -- Restore original function
    date_utils.get_last_n_dates = original_get_last_n_dates
end)

test.add_test("is_weekly_item_required handles different item categories", function()
    local daily_logs = {
        ["2023-08-28"] = {
            activities = {["Walk"] = 1},
            interventions = {["Massage"] = 1},
            symptoms = {["Fatigue"] = 1}
        }
    }
    
    -- Mock last 7 dates
    date_utils.get_last_n_dates = function(n)
        if n == 7 then
            return {"2023-08-30", "2023-08-29", "2023-08-28", "2023-08-27", 
                    "2023-08-26", "2023-08-25", "2023-08-24"}
        end
        return original_get_last_n_dates(n)
    end
    
    test.assert_false(weekly.is_weekly_item_required("Walk", daily_logs), "Should check activities")
    test.assert_false(weekly.is_weekly_item_required("Massage", daily_logs), "Should check interventions")  
    test.assert_false(weekly.is_weekly_item_required("Fatigue", daily_logs), "Should check symptoms")
    test.assert_true(weekly.is_weekly_item_required("Not logged", daily_logs), "Should be required if not found")
    
    -- Restore original function
    date_utils.get_last_n_dates = original_get_last_n_dates
end)

test.add_test("is_weekly_item_required handles nil input", function()
    test.assert_true(weekly.is_weekly_item_required(nil, {}), "Should be required for nil item name")
    test.assert_true(weekly.is_weekly_item_required("Test", nil), "Should be required for nil logs")
    test.assert_true(weekly.is_weekly_item_required(nil, nil), "Should be required for both nil")
end)

test.add_test("is_weekly_item_required checks exact 7-day boundary", function()
    local daily_logs = {
        ["2023-08-23"] = {activities = {["Eye mask"] = 1}}, -- Exactly 7 days ago
        ["2023-08-22"] = {activities = {["Vitamin shot"] = 1}} -- 8 days ago
    }
    
    -- Mock last 7 dates (includes exactly 7 days ago)
    date_utils.get_last_n_dates = function(n)
        if n == 7 then
            return {"2023-08-30", "2023-08-29", "2023-08-28", "2023-08-27", 
                    "2023-08-26", "2023-08-25", "2023-08-24"}
        end
        return original_get_last_n_dates(n)
    end
    
    test.assert_true(weekly.is_weekly_item_required("Eye mask", daily_logs), "Should be required - 7 days ago not included in last 7")
    test.assert_true(weekly.is_weekly_item_required("Vitamin shot", daily_logs), "Should be required - 8 days ago not included")
    
    -- Restore original function  
    date_utils.get_last_n_dates = original_get_last_n_dates
end)

-- Test is_weekly_requirement function
test.add_test("is_weekly_requirement detects new format weekly requirements", function()
    local required_info = {name = "Eye mask", weekly_required = true}
    local daily_logs = {}
    
    test.assert_true(weekly.is_weekly_requirement(required_info, daily_logs), "Should detect new format weekly requirement")
    
    local non_weekly = {name = "Exercise", weekly_required = false}
    test.assert_false(weekly.is_weekly_requirement(non_weekly, daily_logs), "Should not detect non-weekly requirement")
end)

test.add_test("is_weekly_requirement detects old format weekly requirements", function()
    local required_info = {name = "Eye mask", days = {"weekly"}}
    local daily_logs = {}
    
    test.assert_true(weekly.is_weekly_requirement(required_info, daily_logs), "Should detect old format weekly requirement")
    
    local daily_required = {name = "Exercise", days = {"mon", "wed", "fri"}}
    test.assert_false(weekly.is_weekly_requirement(daily_required, daily_logs), "Should not detect daily requirement")
end)

test.add_test("is_weekly_requirement integrates with is_weekly_item_required", function()
    local required_info = {name = "Eye mask", weekly_required = true}
    local daily_logs = {
        ["2023-08-28"] = {activities = {["Eye mask"] = 1}} -- 2 days ago
    }
    
    -- Mock last 7 dates
    date_utils.get_last_n_dates = function(n)
        if n == 7 then
            return {"2023-08-30", "2023-08-29", "2023-08-28", "2023-08-27", 
                    "2023-08-26", "2023-08-25", "2023-08-24"}
        end
        return original_get_last_n_dates(n)
    end
    
    test.assert_false(weekly.is_weekly_requirement(required_info, daily_logs), "Should not be required if logged recently")
    
    -- Restore original function
    date_utils.get_last_n_dates = original_get_last_n_dates
end)

-- Test purge_for_weekly_tracking function
test.add_test("purge_for_weekly_tracking keeps only last 7 days", function()
    local daily_logs = {
        ["2023-08-20"] = {activities = {}}, -- 10 days ago
        ["2023-08-25"] = {activities = {}}, -- 5 days ago  
        ["2023-08-28"] = {activities = {}}, -- 2 days ago
        ["2023-08-30"] = {activities = {}}  -- Today
    }
    
    -- Mock last 7 dates
    date_utils.get_last_n_dates = function(n)
        if n == 7 then
            return {"2023-08-30", "2023-08-29", "2023-08-28", "2023-08-27", 
                    "2023-08-26", "2023-08-25", "2023-08-24"}
        end
        return original_get_last_n_dates(n)
    end
    
    local purged = weekly.purge_for_weekly_tracking(daily_logs)
    
    test.assert_equals(nil, purged["2023-08-20"], "Should remove logs older than 7 days")
    test.assert_true(purged["2023-08-25"] ~= nil, "Should keep logs from last 7 days")
    test.assert_true(purged["2023-08-28"] ~= nil, "Should keep recent logs")
    test.assert_true(purged["2023-08-30"] ~= nil, "Should keep today's logs")
    
    -- Restore original function
    date_utils.get_last_n_dates = original_get_last_n_dates
end)

test.add_test("purge_for_weekly_tracking handles nil input", function()
    local purged = weekly.purge_for_weekly_tracking(nil)
    test.assert_true(type(purged) == "table", "Should return empty table for nil input")
    test.assert_equals(0, #purged, "Should return empty table")
end)

if ... == nil then
    test.run_tests("Weekly Requirements Tests")
    local success = test.print_final_results()
    os.exit(success and 0 or 1)
end