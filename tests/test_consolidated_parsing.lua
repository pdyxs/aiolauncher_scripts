-- test_consolidated_parsing.lua - Tests for Phase 1 refactored parsing infrastructure

-- Add paths for imports
package.path = package.path .. ";../my/?.lua;./?.lua"

local test = require "test_framework"
local data = require "test_data"
local core = require "long_covid_core"

-- Test: Consolidated Item Parsing
test.add_test("Consolidated parsing extracts items from activities content", function()
    local activities_content = [[
## Work
- Work {Options: In Office, From Home}  
- Meeting-heavy day

## Physical
- Walk {Options: Light, Medium, Heavy}
- Exercise {Required}
- Eye mask {Required: Weekly}
]]

    local result = core.parse_items_with_metadata(activities_content, "activities")
    
    -- Should return both simple list and rich metadata
    test.assert_true(result.items ~= nil, "Should return items list")
    test.assert_true(result.metadata ~= nil, "Should return metadata")
    test.assert_true(result.display_names ~= nil, "Should return display names")
    
    -- Check items list (for dialog display)
    test.assert_contains(result.display_names, "Work", "Should include Work in display names")
    test.assert_contains(result.display_names, "Exercise", "Should include Exercise")
    test.assert_contains(result.display_names, "Eye mask", "Should include Eye mask")
    
    -- Check metadata (for requirements logic)
    local exercise_meta = nil
    local eye_mask_meta = nil
    for _, item in ipairs(result.metadata) do
        if item.name == "Exercise" then exercise_meta = item end
        if item.name == "Eye mask" then eye_mask_meta = item end
    end
    
    test.assert_true(exercise_meta ~= nil, "Should have Exercise metadata")
    test.assert_true(exercise_meta.required, "Exercise should be required")
    test.assert_false(exercise_meta.weekly_required, "Exercise should not be weekly required")
    
    test.assert_true(eye_mask_meta ~= nil, "Should have Eye mask metadata")
    test.assert_false(eye_mask_meta.required, "Eye mask should not be daily required")
    test.assert_true(eye_mask_meta.weekly_required, "Eye mask should be weekly required")
end)

test.add_test("Consolidated parsing works for interventions content", function() 
    local interventions_content = [[
## Medications
- LDN (4mg) {Required}
- Claratyne

## Lifestyle
- Meditation {Options: 5min, 15min, 30min}  
- Eye drops {Required: Weekly}
]]

    local result = core.parse_items_with_metadata(interventions_content, "interventions")
    
    -- Check display names
    test.assert_contains(result.display_names, "LDN (4mg)", "Should include LDN in display names")
    test.assert_contains(result.display_names, "Meditation", "Should include Meditation")
    test.assert_contains(result.display_names, "Eye drops", "Should include Eye drops")
    
    -- Check metadata
    local ldn_meta = nil
    local drops_meta = nil
    for _, item in ipairs(result.metadata) do
        if item.name == "LDN (4mg)" then ldn_meta = item end
        if item.name == "Eye drops" then drops_meta = item end
    end
    
    test.assert_true(ldn_meta ~= nil, "Should have LDN metadata")
    test.assert_true(ldn_meta.required, "LDN should be required")
    
    test.assert_true(drops_meta ~= nil, "Should have Eye drops metadata") 
    test.assert_true(drops_meta.weekly_required, "Eye drops should be weekly required")
end)

test.add_test("Consolidated parsing handles fallback content", function()
    local result = core.parse_items_with_metadata(nil, "activities")
    
    test.assert_true(#result.display_names > 0, "Should have fallback items")
    test.assert_true(#result.metadata > 0, "Should have fallback metadata")
end)

test.add_test("Feature parity - both activities and interventions support options", function()
    local activities_with_options = [[- Work {Options: Office, Home}]]
    local interventions_with_options = [[- Medication {Options: Morning, Evening}]]
    
    local activities_result = core.parse_items_with_metadata(activities_with_options, "activities")
    local interventions_result = core.parse_items_with_metadata(interventions_with_options, "interventions") 
    
    -- Both should support options parsing
    local activity_meta = activities_result.metadata[1]
    local intervention_meta = interventions_result.metadata[1]
    
    test.assert_true(activity_meta.has_options, "Activities should support options")
    test.assert_true(intervention_meta.has_options, "Interventions should support options")
end)

test.add_test("Feature parity - both activities and interventions support weekly requirements", function()
    local activities_weekly = [[- Exercise {Required: Weekly}]]
    local interventions_weekly = [[- Massage {Required: Weekly}]]
    
    local activities_result = core.parse_items_with_metadata(activities_weekly, "activities")
    local interventions_result = core.parse_items_with_metadata(interventions_weekly, "interventions")
    
    local activity_meta = activities_result.metadata[1]
    local intervention_meta = interventions_result.metadata[1]
    
    test.assert_true(activity_meta.weekly_required, "Activities should support weekly requirements")
    test.assert_true(intervention_meta.weekly_required, "Interventions should support weekly requirements")
end)

-- Test: Shared Dialog Infrastructure  
test.add_test("Shared dialog infrastructure - parse radio result", function()
    local options = {"Option A", "Option B", "Option C"}
    local result = core.parse_radio_result(options, 1)  -- 1-based index
    
    test.assert_equals("Option A", result, "Should return first option for index 1")
    
    local result2 = core.parse_radio_result(options, 3) 
    test.assert_equals("Option C", result2, "Should return third option for index 3")
end)

test.add_test("Shared dialog infrastructure - handle other selection", function()
    local result = core.handle_other_selection("Custom Input")
    
    test.assert_equals("Custom Input", result, "Should return the custom input")
end)

print("Consolidated Parsing Infrastructure Test Suite loaded - " .. #test.tests .. " tests")

