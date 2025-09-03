#!/usr/bin/env lua

-- Refactored Test Suite for Long Covid Pacing Widget
-- This version imports the core business logic instead of duplicating it
-- Run with: lua test_long_covid_widget_refactored.lua

-- Add the 'my' directory to the Lua path so we can import the core module
package.path = package.path .. ";../my/?.lua"

-- Import the core business logic
local core = require "long_covid_core"

-- Mock data for testing
local test_files = {}
local test_toasts = {}
local test_ui_calls = {}

-- Test data
local test_criteria_content = [[## RED
- Feeling extremely fatigued
- Brain fog severe
- Pain levels high

## YELLOW
- Moderate fatigue
- Some brain fog
- Manageable symptoms

## GREEN
- Good energy levels
- Clear thinking
- Minimal symptoms
]]

local test_monday_content = [[## RED
**Work:** WFH essential only
**Exercise:** Complete rest

### Morning
- Sleep in
- Gentle stretching only

### Afternoon
- Minimal work tasks
- Rest frequently

## YELLOW
**Work:** WFH normal schedule
**Exercise:** Light walking

### Morning
- Normal wake time
- Light breakfast prep

### Afternoon
- Standard work tasks
- 15 min walk

## GREEN
**Work:** Office possible
**Exercise:** Full routine

### Morning
- Early start possible
- Full breakfast prep

### Afternoon
- All work tasks
- 30 min exercise
]]

local test_activities_content = [[
# Long Covid Activities

## Physical
- Light walk
- Physio (full) {Required: Mon,Wed,Fri}
- Yin Yoga {Required}

## Work
- Work from home
]]

local test_interventions_content = [[
## Medications
- LDN (4mg) {Required}
- Claratyne

## Supplements
- Salvital {Required: Mon,Wed,Fri}
]]

-- Test framework
local tests = {}

local function add_test(name, test_func)
    table.insert(tests, {name = name, func = test_func})
end

local function assert_equals(expected, actual, message)
    if expected ~= actual then
        error((message or "Assertion failed") .. ": expected '" .. tostring(expected) .. "', got '" .. tostring(actual) .. "'")
    end
end

local function assert_true(condition, message)
    if not condition then
        error(message or "Expected true but got false")
    end
end

local function assert_contains(haystack, needle, message)
    if type(haystack) == "table" then
        for _, item in ipairs(haystack) do
            if string.find(tostring(item), tostring(needle), 1, true) then return end
        end
        error((message or "Table does not contain expected value") .. ": " .. tostring(needle))
    else
        if not string.find(tostring(haystack), tostring(needle), 1, true) then
            error((message or "String does not contain expected substring") .. ": " .. tostring(needle))
        end
    end
end

-- Tests using the imported core module
add_test("Core module levels are defined", function()
    assert_equals(3, #core.levels, "Should have 3 capacity levels")
    assert_equals("Recovering", core.levels[1].name, "First level should be Recovering")
    assert_equals("Maintaining", core.levels[2].name, "Second level should be Maintaining")
    assert_equals("Engaging", core.levels[3].name, "Third level should be Engaging")
end)

add_test("Current day calculation", function()
    local day = core.get_current_day()
    local valid_days = {"sunday", "monday", "tuesday", "wednesday", "thursday", "friday", "saturday"}
    
    local found = false
    for _, valid_day in ipairs(valid_days) do
        if day == valid_day then
            found = true
            break
        end
    end
    
    assert_true(found, "Should return a valid day name: " .. tostring(day))
end)

add_test("Current day abbreviation", function()
    local day_abbrev = core.get_current_day_abbrev()
    local valid_abbrevs = {"sun", "mon", "tue", "wed", "thu", "fri", "sat"}
    
    local found = false
    for _, valid in ipairs(valid_abbrevs) do
        if day_abbrev == valid then
            found = true
            break
        end
    end
    
    assert_true(found, "Should return valid day abbreviation: " .. tostring(day_abbrev))
end)

add_test("Daily reset functionality", function()
    local last_selection_date = "2023-01-01"
    local selected_level = 2
    local daily_capacity_log = {}
    local daily_logs = {}
    
    local changes = core.check_daily_reset(last_selection_date, selected_level, daily_capacity_log, daily_logs)
    
    assert_equals(0, changes.selected_level, "Should reset selection on new day")
    assert_equals(os.date("%Y-%m-%d"), changes.last_selection_date, "Should update to current date")
    assert_true(changes.daily_logs ~= nil, "Should purge old daily logs")
end)

add_test("Decision criteria parsing", function()
    local criteria = core.parse_decision_criteria(test_criteria_content)
    
    assert_true(type(criteria) == "table", "Should return a table")
    assert_true(type(criteria.red) == "table", "Should have red criteria table")
    assert_true(type(criteria.yellow) == "table", "Should have yellow criteria table")
    assert_true(type(criteria.green) == "table", "Should have green criteria table")
    
    assert_true(#criteria.red > 0, "Should parse RED criteria")
    assert_true(#criteria.yellow > 0, "Should parse YELLOW criteria") 
    assert_true(#criteria.green > 0, "Should parse GREEN criteria")
    
    assert_contains(criteria.red[1], "extremely fatigued", "Should contain expected RED criterion")
    assert_contains(criteria.yellow[1], "Moderate fatigue", "Should contain expected YELLOW criterion")
    assert_contains(criteria.green[1], "Good energy", "Should contain expected GREEN criterion")
end)

add_test("Day file parsing", function()
    local plan = core.parse_day_file(test_monday_content)
    
    assert_true(type(plan) == "table", "Should return a table")
    assert_true(plan.red ~= nil, "Should have RED level plan")
    assert_true(plan.yellow ~= nil, "Should have YELLOW level plan")
    assert_true(plan.green ~= nil, "Should have GREEN level plan")
    
    -- Test overview parsing
    assert_true(type(plan.red.overview) == "table", "Should have RED overview table")
    assert_true(#plan.red.overview > 0, "Should parse RED overview")
    assert_contains(plan.red.overview[1], "WFH essential only", "Should contain work overview")
    
    -- Test category parsing
    assert_true(plan.red.Morning ~= nil, "Should parse Morning category")
    assert_true(type(plan.red.Morning) == "table", "Morning should be a table")
    assert_true(#plan.red.Morning > 0, "Should have Morning items")
    assert_contains(plan.red.Morning[1], "Sleep in", "Should contain expected morning item")
end)

add_test("Log item functionality", function()
    local daily_logs = {}
    
    local success = core.log_item(daily_logs, "symptom", "Fatigue")
    assert_true(success, "Should successfully log symptom")
    
    local today = os.date("%Y-%m-%d")
    local logs = core.get_daily_logs(daily_logs, today)
    
    assert_equals(1, logs.symptoms["Fatigue"], "Should track Fatigue count as 1")
    
    -- Log the same symptom again
    core.log_item(daily_logs, "symptom", "Fatigue")
    assert_equals(2, logs.symptoms["Fatigue"], "Should track Fatigue count as 2")
end)

add_test("Log energy functionality", function()
    local daily_logs = {}
    
    local success = core.log_energy(daily_logs, 7)
    assert_true(success, "Should successfully log energy")
    
    local today = os.date("%Y-%m-%d")
    local logs = core.get_daily_logs(daily_logs, today)
    
    assert_equals(1, #logs.energy_levels, "Should have 1 energy entry")
    assert_equals(7, logs.energy_levels[1].level, "Should store correct energy level")
    assert_true(logs.energy_levels[1].timestamp ~= nil, "Should have timestamp")
    assert_true(logs.energy_levels[1].time_display ~= nil, "Should have time display")
end)

add_test("Energy button color logic", function()
    local daily_logs = {}
    
    -- Initially no energy logged - should be red
    local color = core.get_energy_button_color(daily_logs)
    assert_equals("#dc3545", color, "Should be red when no energy logged")
    
    -- Log energy - should be green
    core.log_energy(daily_logs, 5)
    color = core.get_energy_button_color(daily_logs)
    assert_equals("#28a745", color, "Should be green after logging energy")
end)

add_test("Parse required activities", function()
    local parsed = core.parse_items_with_metadata(test_activities_content, "activities")
    local required = {}
    
    -- Filter to just required items for this test
    for _, meta in ipairs(parsed.metadata) do
        if meta.required then
            table.insert(required, meta)
        end
    end
    
    assert_equals(2, #required, "Should find 2 required activities")
    assert_equals("Physio (full)", required[1].name, "Should parse activity name correctly")
    assert_equals("Yin Yoga", required[2].name, "Should parse daily required activity")
    
    assert_true(required[1].days ~= nil, "Should parse specific days")
    assert_equals(3, #required[1].days, "Should find 3 days for physio")
    assert_true(required[2].days == nil, "Daily required should have no specific days")
end)

add_test("Parse required interventions", function()
    local parsed = core.parse_items_with_metadata(test_interventions_content, "interventions")
    local required = {}
    
    -- Filter to just required items for this test
    for _, meta in ipairs(parsed.metadata) do
        if meta.required then
            table.insert(required, meta)
        end
    end
    
    assert_equals(2, #required, "Should find 2 required interventions")
    assert_equals("LDN (4mg)", required[1].name, "Should parse intervention name correctly")
    assert_equals("Salvital", required[2].name, "Should parse day-specific intervention")
end)

add_test("Required items completion status", function()
    local daily_logs = {}
    local required_activities = core.parse_items_with_metadata(test_activities_content, "activities").metadata
    
    -- Initially no activities logged - should be incomplete
    assert_true(not core.are_all_required_items_completed(daily_logs, required_activities, "activities"), 
                "Should be incomplete when nothing logged")
    
    -- Log one required activity
    core.log_item(daily_logs, "activity", "Yin Yoga")
    
    -- Mock current day to match required activity days for testing
    local orig_get_current_day_abbrev = core.get_current_day_abbrev
    core.get_current_day_abbrev = function() return "tue" end -- Tuesday - only Yin Yoga required
    
    -- Should now be complete
    assert_true(core.are_all_required_items_completed(daily_logs, required_activities, "activities"), 
                "Should be complete after logging all required activities for today")
    
    -- Restore original function
    core.get_current_day_abbrev = orig_get_current_day_abbrev
end)

add_test("Format list items with required markers", function()
    local daily_logs = {}
    local required_activities = core.parse_items_with_metadata(test_activities_content, "activities").metadata
    local activities = {"Physio (full)", "Light walk", "Yin Yoga"}
    
    local formatted = core.format_list_items(activities, "activity", daily_logs, required_activities)
    
    -- Check that required items have warning icons (depends on current day)
    local found_warning = false
    for _, item in ipairs(formatted) do
        if string.find(item, "⚠️") then
            found_warning = true
            break
        end
    end
    assert_true(found_warning, "Should have warning icon for required unlogged items")
    
    -- Log a required activity
    core.log_item(daily_logs, "activity", "Yin Yoga")
    formatted = core.format_list_items(activities, "activity", daily_logs, required_activities)
    
    local found_completed = false
    for _, item in ipairs(formatted) do
        if string.find(item, "✅.*Yin Yoga") then
            found_completed = true
            break
        end
    end
    assert_true(found_completed, "Should have green checkmark for completed required items")
end)

add_test("Extract item name from formatted string", function()
    assert_equals("Fatigue", core.extract_item_name("✓ Fatigue (2)"), "Should extract name from checked counted item")
    assert_equals("Brain fog", core.extract_item_name("✓ Brain fog (1)"), "Should extract name from checked single count")
    assert_equals("Headache", core.extract_item_name("   Headache"), "Should extract name from spaced uncounted item")
    assert_equals("Required Activity", core.extract_item_name("⚠️ Required Activity"), "Should strip warning icon from required item")
    assert_equals("Completed Required Activity", core.extract_item_name("✅ Completed Required Activity (1)"), "Should strip green checkmark from completed required item")
    assert_equals("Physio (full)", core.extract_item_name("✓ Physio (full) (2)"), "Should extract original name with brackets")
end)

add_test("Save daily choice functionality", function()
    local daily_capacity_log = {}
    
    local updated_log = core.save_daily_choice(daily_capacity_log, 2)
    
    local today = os.date("%Y-%m-%d")
    assert_true(updated_log[today] ~= nil, "Should create today's entry")
    assert_equals(2, updated_log[today].capacity, "Should save correct capacity level")
    assert_equals("Maintaining", updated_log[today].capacity_name, "Should save correct capacity name")
    assert_true(updated_log[today].timestamp ~= nil, "Should save timestamp")
end)

add_test("File parsing with nil content", function()
    -- Test that all parse functions handle nil content gracefully
    local criteria = core.parse_decision_criteria(nil)
    assert_true(type(criteria) == "table", "Should return empty table for nil criteria")
    
    local plan = core.parse_day_file(nil)
    assert_true(type(plan) == "table", "Should return empty table for nil day file")
    
    local symptoms = core.parse_symptoms_file(nil)
    assert_true(#symptoms > 0, "Should return default symptoms for nil content")
    assert_contains(symptoms, "Other...", "Should include Other... option")
    
    local activities = core.parse_items_with_metadata(nil, "activities").display_names
    assert_true(#activities > 0, "Should return default activities for nil content")
    assert_contains(activities, "Other...", "Should include Other... option")
    
    local interventions = core.parse_items_with_metadata(nil, "interventions").display_names
    assert_true(#interventions > 0, "Should return default interventions for nil content")
    assert_contains(interventions, "Other...", "Should include Other... option")
end)

-- Run tests
local function run_tests()
    print("Running Refactored Long Covid Widget Tests...")
    print("Using imported core business logic from long_covid_core.lua")
    print("=" .. string.rep("=", 60))
    
    local passed = 0
    
    for _, test in ipairs(tests) do
        local success, error_msg = pcall(test.func)
        
        if success then
            passed = passed + 1
            print("✓ " .. test.name)
        else
            print("✗ " .. test.name)
            print("  Error: " .. tostring(error_msg))
        end
    end
    
    print("=" .. string.rep("=", 60))
    print(string.format("Results: %d/%d tests passed", passed, #tests))
    
    if passed == #tests then
        print("All tests passed! 🎉")
        print("The core business logic is working correctly.")
        os.exit(0)
    else
        print("Some tests failed. ❌")
        os.exit(1)
    end
end

-- Run the tests
run_tests()