-- test_core_logic.lua - Tests for core business logic functions
-- Tests basic parsing, data management, and utility functions

-- Add paths for imports
package.path = package.path .. ";../my/?.lua;./?.lua"

local test = require "test_framework"
local data = require "test_data"
local core = require "long_covid_core"

test.add_test("Core module levels are defined", function()
    test.assert_type("table", core.levels, "Levels should be a table")
    test.assert_equals(3, #core.levels, "Should have 3 levels")
    test.assert_equals("Recovering", core.levels[1].name, "First level should be Recovering")
    test.assert_equals("Maintaining", core.levels[2].name, "Second level should be Maintaining") 
    test.assert_equals("Engaging", core.levels[3].name, "Third level should be Engaging")
end)

test.add_test("Current day calculation", function()
    local day = core.get_current_day()
    test.assert_type("string", day, "Should return string")
    test.assert_true(#day > 0, "Should return non-empty string")
    
    -- Test with mocked date
    local mock_date, original_date = data.mock_os_date("2023-01-01")
    os.date = mock_date
    
    local sunday = core.get_current_day()
    test.assert_equals("sunday", sunday, "2023-01-01 should be Sunday")
    
    os.date = original_date
end)

test.add_test("Current day abbreviation", function()
    local mock_date, original_date = data.mock_os_date("2023-01-01")
    os.date = mock_date
    
    local abbrev = core.get_current_day_abbrev()
    test.assert_equals("sun", abbrev, "Sunday should abbreviate to 'sun'")
    
    os.date = original_date
end)

test.add_test("Daily reset functionality", function()
    local last_selection_date = "2023-01-01"
    local selected_level = 2
    local daily_capacity_log = {
        ["2023-01-02"] = {capacity = 3, capacity_name = "Engaging"}
    }
    local daily_logs = data.create_sample_daily_logs()
    
    local mock_date, original_date = data.mock_os_date("2023-01-02")
    os.date = mock_date
    
    local changes = core.check_daily_reset(last_selection_date, selected_level, daily_capacity_log, daily_logs)
    
    -- On new day, should reset to 0 (widget handles restore separately)
    test.assert_equals(0, changes.selected_level, "Should reset to 0 on new day")
    test.assert_equals("2023-01-02", changes.last_selection_date, "Should update date")
    test.assert_not_nil(changes.daily_logs, "Should return purged logs")
    
    -- Test same day scenario - should restore saved level
    local same_day_changes = core.check_daily_reset("2023-01-02", 0, daily_capacity_log, daily_logs)
    test.assert_equals(3, same_day_changes.selected_level, "Should restore saved level on same day")
    
    os.date = original_date
end)

test.add_test("Decision criteria parsing", function()
    local criteria = core.parse_decision_criteria(data.test_criteria_content)
    
    test.assert_type("table", criteria, "Should return table")
    test.assert_type("table", criteria.red, "Should have red criteria")
    test.assert_type("table", criteria.yellow, "Should have yellow criteria")
    test.assert_type("table", criteria.green, "Should have green criteria")
    
    test.assert_true(#criteria.red > 0, "Should have red criteria items")
    test.assert_contains(criteria.red, "Feeling extremely fatigued", "Should contain expected red criterion")
    test.assert_contains(criteria.green, "Good energy levels", "Should contain expected green criterion")
end)

test.add_test("Day file parsing", function()
    local plan = core.parse_day_file(data.test_monday_content)
    
    test.assert_type("table", plan, "Should return table")
    test.assert_not_nil(plan.red, "Should have red level plan")
    test.assert_not_nil(plan.yellow, "Should have yellow level plan")
    test.assert_not_nil(plan.green, "Should have green level plan")
    
    test.assert_type("table", plan.red.overview, "Should have overview for red")
    test.assert_contains(plan.red.overview, "**Work:** WFH essential only", "Should contain work overview")
    
    test.assert_type("table", plan.red.Morning, "Should have Morning section")
    test.assert_contains(plan.red.Morning, "Sleep in", "Should contain morning activity")
end)

test.add_test("Log item functionality", function()
    local daily_logs = {}
    
    local mock_date, original_date = data.mock_os_date("2023-01-01")
    os.date = mock_date
    
    local success = core.log_item(daily_logs, "symptom", "Fatigue")
    test.assert_true(success, "Should successfully log symptom")
    
    local today_logs = core.get_daily_logs(daily_logs, "2023-01-01")
    test.assert_equals(1, today_logs.symptoms["Fatigue"], "Should log symptom with count 1")
    
    -- Log same symptom again
    core.log_item(daily_logs, "symptom", "Fatigue")
    test.assert_equals(2, today_logs.symptoms["Fatigue"], "Should increment count")
    
    -- Test invalid item type
    local success2, error_msg = core.log_item(daily_logs, "invalid", "test")
    test.assert_false(success2, "Should fail with invalid type")
    test.assert_not_nil(error_msg, "Should return error message")
    
    os.date = original_date
end)

test.add_test("Log energy functionality", function()
    local daily_logs = {}
    local mock_date, original_date = data.mock_os_date("2023-01-01")
    os.date = mock_date
    
    local success = core.log_energy(daily_logs, 7)
    test.assert_true(success, "Should successfully log energy")
    
    local today_logs = core.get_daily_logs(daily_logs, "2023-01-01")
    test.assert_equals(1, #today_logs.energy_levels, "Should have one energy entry")
    test.assert_equals(7, today_logs.energy_levels[1].level, "Should store energy level")
    test.assert_not_nil(today_logs.energy_levels[1].timestamp, "Should have timestamp")
    
    os.date = original_date
end)

test.add_test("Energy button color logic", function()
    local daily_logs = {}
    
    -- No energy logged - should be red
    local color = core.get_energy_button_color(daily_logs)
    test.assert_equals("#dc3545", color, "Should be red when no energy logged")
    
    -- Recent energy logged - should be green
    local mock_date, original_date = data.mock_os_date("2023-01-01")
    os.date = mock_date
    core.log_energy(daily_logs, 5)
    
    color = core.get_energy_button_color(daily_logs)
    test.assert_equals("#28a745", color, "Should be green when recently logged")
    
    os.date = original_date
end)

test.add_test("Parse required activities", function()
    local required = core.parse_items_with_metadata(data.test_activities_content, "activities").metadata
    
    test.assert_type("table", required, "Should return table")
    test.assert_true(#required >= 1, "Should have required activities")
    
    local physio_found = false
    local yoga_found = false
    
    for _, req in ipairs(required) do
        if req.name == "Physio (full)" then
            physio_found = true
            test.assert_type("table", req.days, "Physio should have specific days")
            test.assert_contains(req.days, "mon", "Should include Monday")
        elseif req.name == "Yin Yoga" then
            yoga_found = true
            test.assert_nil(req.days, "Yin Yoga should be required all days")
        end
    end
    
    test.assert_true(physio_found, "Should find Physio requirement")
    test.assert_true(yoga_found, "Should find Yin Yoga requirement")
end)

test.add_test("Parse required interventions", function()
    local required = core.parse_items_with_metadata(data.test_interventions_content, "interventions").metadata
    
    test.assert_type("table", required, "Should return table")
    test.assert_true(#required >= 1, "Should have required interventions")
    
    local ldn_found = false
    for _, req in ipairs(required) do
        if req.name == "LDN (4mg)" then
            ldn_found = true
            test.assert_nil(req.days, "LDN should be required all days")
        end
    end
    
    test.assert_true(ldn_found, "Should find LDN requirement")
end)

test.add_test("Required items completion status", function()
    local daily_logs = data.create_sample_daily_logs()
    local required_activities = data.create_sample_required_activities()
    local required_interventions = data.create_sample_required_interventions()
    
    local mock_date, original_date = data.mock_os_date("2023-01-01")
    os.date = mock_date
    
    -- Test activities completion
    local activities_complete = core.are_all_required_items_completed(daily_logs, required_activities, "activities")
    test.assert_true(activities_complete, "Should complete required activities")
    
    -- Test interventions completion
    local interventions_complete = core.are_all_required_items_completed(daily_logs, required_interventions, "interventions")
    test.assert_true(interventions_complete, "Should complete required interventions")
    
    os.date = original_date
end)

test.add_test("Format list items with required markers", function()
    local daily_logs = data.create_sample_daily_logs()
    local required_activities = data.create_sample_required_activities()
    local activities = {"Light walk", "Physio (full)", "Yin Yoga", "Other..."}
    
    local mock_date, original_date = data.mock_os_date("2023-01-01")
    os.date = mock_date
    
    local formatted = core.format_list_items(activities, "activity", daily_logs, required_activities)
    
    test.assert_type("table", formatted, "Should return table")
    test.assert_equals(#activities, #formatted, "Should have same number of items")
    
    -- Check for completion markers (2023-01-01 is Sunday)
    local light_walk_formatted = formatted[1]  -- Light walk: completed, not required
    local physio_formatted = formatted[2]      -- Physio: not required on Sunday
    local yoga_formatted = formatted[3]        -- Yin Yoga: required every day, completed
    
    test.assert_true(light_walk_formatted:find("✓"), "Completed non-required should have ✓")
    test.assert_true(physio_formatted:find("   "), "Non-required should have spaces") -- Physio not required on Sunday
    test.assert_true(yoga_formatted:find("✅"), "Completed required should have ✅") -- Yin Yoga completed
    
    os.date = original_date
end)

test.add_test("Extract item name from formatted string", function()
    test.assert_equals("Fatigue", core.extract_item_name("✓ Fatigue (2)"), "Should extract name from checked counted item")
    test.assert_equals("LDN (4mg)", core.extract_item_name("✅ LDN (4mg) (1)"), "Should extract name preserving inner brackets")
    test.assert_equals("Yin Yoga", core.extract_item_name("⚠️ Yin Yoga"), "Should extract name from warning item")
    test.assert_equals("Simple item", core.extract_item_name("   Simple item"), "Should remove leading spaces from plain items")
end)

test.add_test("Save daily choice functionality", function()
    local daily_capacity_log = {}
    local mock_date, original_date = data.mock_os_date("2023-01-01")
    os.date = mock_date
    
    local updated_log = core.save_daily_choice(daily_capacity_log, 2)
    
    test.assert_not_nil(updated_log["2023-01-01"], "Should create entry for today")
    test.assert_equals(2, updated_log["2023-01-01"].capacity, "Should save capacity level")
    test.assert_equals("Maintaining", updated_log["2023-01-01"].capacity_name, "Should save level name")
    
    -- Test level 0 (no selection)
    local unchanged_log = core.save_daily_choice(daily_capacity_log, 0)
    test.assert_equals(daily_capacity_log, unchanged_log, "Should not change log for level 0")
    
    os.date = original_date
end)

test.add_test("File parsing with nil content", function()
    -- Test that all parse functions handle nil content gracefully
    local criteria = core.parse_decision_criteria(nil)
    test.assert_type("table", criteria, "Should return table for nil criteria")
    test.assert_not_nil(criteria.red, "Should have default red criteria")
    
    local day_plan = core.parse_day_file(nil)
    test.assert_type("table", day_plan, "Should return table for nil day plan")
    test.assert_not_nil(day_plan.red, "Should have default red plan")
    
    local symptoms = core.parse_symptoms_file(nil)
    test.assert_type("table", symptoms, "Should return table for nil symptoms")
    test.assert_true(#symptoms > 0, "Should have default symptoms")
    
    local activities = core.parse_items_with_metadata(nil, "activities").display_names
    test.assert_type("table", activities, "Should return table for nil activities")
    test.assert_true(#activities > 0, "Should have default activities")
    
    local interventions = core.parse_items_with_metadata(nil, "interventions").display_names
    test.assert_type("table", interventions, "Should return table for nil interventions")
    test.assert_true(#interventions > 0, "Should have default interventions")
end)

-- This file can be run standalone or included by main test runner
if ... == nil then
    test.run_tests("Core Business Logic")
    local success = test.print_final_results()
    os.exit(success and 0 or 1)
end