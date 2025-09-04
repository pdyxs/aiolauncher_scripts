local test = require "test_framework"

-- Load the date utilities module  
local date_utils = require "long_covid_date"

-- Mock os.date for consistent testing
local original_os_date = os.date
local original_os_time = os.time

-- Test get_current_day function
test.add_test("get_current_day returns correct day name", function()
    -- Mock Sunday (day 0)
    os.date = function(fmt)
        if fmt == "%w" then return "0" end
        return original_os_date(fmt)
    end
    
    test.assert_equals("sunday", date_utils.get_current_day())
    
    -- Mock Wednesday (day 3)
    os.date = function(fmt)
        if fmt == "%w" then return "3" end
        return original_os_date(fmt)
    end
    
    test.assert_equals("wednesday", date_utils.get_current_day())
    
    -- Restore original function
    os.date = original_os_date
end)

-- Test get_current_day_abbrev function
test.add_test("get_current_day_abbrev returns correct abbreviation", function()
    -- Mock Sunday (day 0)
    os.date = function(fmt)
        if fmt == "%w" then return "0" end
        return original_os_date(fmt)
    end
    
    test.assert_equals("sun", date_utils.get_current_day_abbrev())
    
    -- Mock Friday (day 5)
    os.date = function(fmt)
        if fmt == "%w" then return "5" end
        return original_os_date(fmt)
    end
    
    test.assert_equals("fri", date_utils.get_current_day_abbrev())
    
    -- Restore original function
    os.date = original_os_date
end)

-- Test get_today_date function
test.add_test("get_today_date returns correct format", function()
    -- Mock a specific date
    os.date = function(fmt)
        if fmt == "%Y-%m-%d" then return "2023-08-30" end
        return original_os_date(fmt)
    end
    
    test.assert_equals("2023-08-30", date_utils.get_today_date())
    
    -- Restore original function
    os.date = original_os_date
end)

-- Test get_date_days_ago function - basic functionality
test.add_test("get_date_days_ago basic calculations", function()
    -- Mock current date to 2023-08-30
    os.date = function(fmt)
        if fmt == "%Y-%m-%d" then return "2023-08-30" end
        return original_os_date(fmt)
    end
    
    os.time = function(date_table)
        if date_table and date_table.year == 2023 and date_table.month == 8 and date_table.day == 30 then
            return 1693353600 -- Mock timestamp for 2023-08-30
        end
        return original_os_time(date_table)
    end
    
    -- Mock os.date for timestamp formatting
    local original_date_func = os.date
    os.date = function(fmt, timestamp)
        if fmt == "%Y-%m-%d" and not timestamp then
            return "2023-08-30"
        elseif fmt == "%Y-%m-%d" and timestamp then
            -- Calculate days based on timestamp difference
            local base_timestamp = 1693353600 -- 2023-08-30
            local days_diff = math.floor((base_timestamp - timestamp) / (24 * 60 * 60))
            if days_diff == 1 then return "2023-08-29"
            elseif days_diff == 2 then return "2023-08-28"
            elseif days_diff == 7 then return "2023-08-23"
            end
        end
        return original_date_func(fmt, timestamp)
    end
    
    test.assert_equals("2023-08-29", date_utils.get_date_days_ago(1), "Should return yesterday")
    test.assert_equals("2023-08-28", date_utils.get_date_days_ago(2), "Should return 2 days ago")
    test.assert_equals("2023-08-23", date_utils.get_date_days_ago(7), "Should return 1 week ago")
    test.assert_equals("2023-08-30", date_utils.get_date_days_ago(0), "Should return today for 0 days")
    
    -- Restore original functions
    os.date = original_os_date
    os.time = original_os_time
end)

-- Test get_date_days_ago validation
test.add_test("get_date_days_ago input validation", function()
    test.assert_equals(nil, date_utils.get_date_days_ago(-1), "Should handle negative days")
    test.assert_equals(nil, date_utils.get_date_days_ago("invalid"), "Should handle non-numeric input")
    test.assert_equals(nil, date_utils.get_date_days_ago(nil), "Should handle nil input")
end)

-- Test get_last_n_dates function
test.add_test("get_last_n_dates basic functionality", function()
    -- Mock get_date_days_ago behavior
    local original_get_date_days_ago = date_utils.get_date_days_ago
    date_utils.get_date_days_ago = function(days_ago)
        if days_ago == 0 then return "2023-08-30" end
        if days_ago == 1 then return "2023-08-29" end
        if days_ago == 2 then return "2023-08-28" end
        return nil
    end
    
    local dates = date_utils.get_last_n_dates(3)
    test.assert_equals(3, #dates, "Should return 3 dates")
    test.assert_equals("2023-08-30", dates[1], "First date should be today")
    test.assert_equals("2023-08-29", dates[2], "Second date should be yesterday")
    test.assert_equals("2023-08-28", dates[3], "Third date should be 2 days ago")
    
    -- Restore original function
    date_utils.get_date_days_ago = original_get_date_days_ago
end)

-- Test get_last_n_dates validation
test.add_test("get_last_n_dates input validation", function()
    test.assert_equals(0, #date_utils.get_last_n_dates(0), "Should return empty for 0")
    test.assert_equals(0, #date_utils.get_last_n_dates(-1), "Should return empty for negative")
    test.assert_equals(0, #date_utils.get_last_n_dates("invalid"), "Should return empty for invalid input")
    test.assert_equals(0, #date_utils.get_last_n_dates(nil), "Should return empty for nil")
end)

-- Restore original functions after all tests
local function restore_os_functions()
    os.date = original_os_date
    os.time = original_os_time
end

if ... == nil then
    test.run_tests("Date Utils Tests")
    local success = test.print_final_results()
    restore_os_functions()
    os.exit(success and 0 or 1)
else
    -- When loaded as a module, ensure we still restore os functions
    restore_os_functions()
end