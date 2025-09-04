local test = require "test_framework"

-- Load the parsing module
local parsing = require "long_covid_parsing"

-- Test split_lines utility
test.add_test("split_lines basic functionality", function()
    local text = "line 1\nline 2\nline 3"
    local lines = parsing.split_lines(text)
    
    test.assert_equals(3, #lines, "Should split into 3 lines")
    test.assert_equals("line 1", lines[1], "First line should be correct")
    test.assert_equals("line 2", lines[2], "Second line should be correct")
    test.assert_equals("line 3", lines[3], "Third line should be correct")
end)

test.add_test("split_lines with carriage returns", function()
    local text = "line 1\r\nline 2\rline 3"
    local lines = parsing.split_lines(text)
    
    test.assert_equals(3, #lines, "Should handle mixed line endings")
    test.assert_equals("line 1", lines[1])
    test.assert_equals("line 2", lines[2])
    test.assert_equals("line 3", lines[3])
end)

-- Test escape_pattern utility
test.add_test("escape_pattern escapes special characters", function()
    local pattern = "test.pattern"
    local escaped = parsing.escape_pattern(pattern)
    
    test.assert_equals("test%.pattern", escaped, "Should escape dot character")
    
    local complex = "test[abc]+(def)*{3,5}?"
    local escaped_complex = parsing.escape_pattern(complex)
    test.assert_equals("test%[abc%]%+%(def%)%*%{3%,5%}%?", escaped_complex, "Should escape all pattern characters")
end)

-- Test parse_symptoms_file
test.add_test("parse_symptoms_file with content", function()
    local content = [[# Symptoms
- Fatigue
- Brain fog
- Headache
- Joint pain]]
    
    local symptoms = parsing.parse_symptoms_file(content)
    
    test.assert_true(#symptoms > 4, "Should include all symptoms plus Other")
    test.assert_contains(symptoms, "Fatigue", "Should contain Fatigue")
    test.assert_contains(symptoms, "Brain fog", "Should contain Brain fog")
    test.assert_contains(symptoms, "Headache", "Should contain Headache")
    test.assert_contains(symptoms, "Joint pain", "Should contain Joint pain")
    test.assert_equals("Other...", symptoms[#symptoms], "Should end with Other...")
end)

test.add_test("parse_symptoms_file fallback", function()
    local symptoms = parsing.parse_symptoms_file(nil)
    
    test.assert_true(#symptoms > 0, "Should return fallback symptoms")
    test.assert_contains(symptoms, "Fatigue", "Should include Fatigue in fallback")
    test.assert_equals("Other...", symptoms[#symptoms], "Should end with Other...")
end)

-- Test parse_items_with_metadata
test.add_test("parse_items_with_metadata activities parsing", function()
    local activities_content = [[
## Work
- Work {Options: In Office, From Home}  
- Meeting-heavy day

## Physical
- Walk {Options: Light, Medium, Heavy}
- Exercise {Required}
- Eye mask {Required: Weekly}
- Yin Yoga {Required: Thu}
]]

    local result = parsing.parse_items_with_metadata(activities_content, "activities")
    
    -- Should return both simple list and rich metadata
    test.assert_true(result.items ~= nil, "Should return items list")
    test.assert_true(result.metadata ~= nil, "Should return metadata")
    test.assert_true(result.display_names ~= nil, "Should return display names")
    
    -- Check items list
    test.assert_contains(result.display_names, "Work", "Should include Work in display names")
    test.assert_contains(result.display_names, "Exercise", "Should include Exercise")
    test.assert_contains(result.display_names, "Eye mask", "Should include Eye mask")
    test.assert_contains(result.display_names, "Yin Yoga", "Should include Yin Yoga")
    
    -- Check metadata
    local exercise_meta = nil
    local eye_mask_meta = nil
    local yin_yoga_meta = nil
    local work_meta = nil
    for _, item in ipairs(result.metadata) do
        if item.name == "Exercise" then exercise_meta = item end
        if item.name == "Eye mask" then eye_mask_meta = item end
        if item.name == "Yin Yoga" then yin_yoga_meta = item end
        if item.name == "Work" then work_meta = item end
    end
    
    -- Exercise - daily required
    test.assert_true(exercise_meta ~= nil, "Should have Exercise metadata")
    test.assert_true(exercise_meta.required, "Exercise should be required")
    test.assert_false(exercise_meta.weekly_required, "Exercise should not be weekly required")
    test.assert_false(exercise_meta.has_options, "Exercise should not have options")
    
    -- Eye mask - weekly required
    test.assert_true(eye_mask_meta ~= nil, "Should have Eye mask metadata")
    test.assert_false(eye_mask_meta.required, "Eye mask should not be daily required")
    test.assert_true(eye_mask_meta.weekly_required, "Eye mask should be weekly required")
    
    -- Yin Yoga - specific day required
    test.assert_true(yin_yoga_meta ~= nil, "Should have Yin Yoga metadata")
    test.assert_true(yin_yoga_meta.required, "Yin Yoga should be required")
    test.assert_true(yin_yoga_meta.days ~= nil, "Yin Yoga should have days")
    test.assert_contains(yin_yoga_meta.days, "thu", "Yin Yoga should be required on Thursday")
    
    -- Work - has options
    test.assert_true(work_meta ~= nil, "Should have Work metadata")
    test.assert_true(work_meta.has_options, "Work should have options")
    test.assert_false(work_meta.required, "Work should not be required by default")
end)

test.add_test("parse_items_with_metadata interventions parsing", function()
    local interventions_content = [[
## Medications
- LDN (4mg) {Required}
- Claratyne

## Supplements  
- Salvital {Options: Morning, Evening}
- Vitamin D
- Weekly vitamin shot {Required: Weekly}

## Treatments
- Meditation
- Breathing exercises {Required: Mon,Wed,Fri}
]]

    local result = parsing.parse_items_with_metadata(interventions_content, "interventions")
    
    -- Check specific interventions
    local ldn_meta = nil
    local salvital_meta = nil
    local weekly_shot_meta = nil
    local breathing_meta = nil
    
    for _, item in ipairs(result.metadata) do
        if item.name == "LDN (4mg)" then ldn_meta = item end
        if item.name == "Salvital" then salvital_meta = item end
        if item.name == "Weekly vitamin shot" then weekly_shot_meta = item end
        if item.name == "Breathing exercises" then breathing_meta = item end
    end
    
    -- LDN - daily required
    test.assert_true(ldn_meta.required, "LDN should be required")
    test.assert_false(ldn_meta.weekly_required, "LDN should not be weekly required")
    
    -- Salvital - has options
    test.assert_true(salvital_meta.has_options, "Salvital should have options")
    test.assert_false(salvital_meta.required, "Salvital should not be required by default")
    
    -- Weekly shot - weekly required
    test.assert_true(weekly_shot_meta.weekly_required, "Weekly shot should be weekly required")
    test.assert_false(weekly_shot_meta.required, "Weekly shot should not be daily required")
    
    -- Breathing exercises - specific days
    test.assert_true(breathing_meta.required, "Breathing exercises should be required")
    test.assert_true(breathing_meta.days ~= nil, "Breathing exercises should have days")
    test.assert_contains(breathing_meta.days, "mon", "Should include Monday")
    test.assert_contains(breathing_meta.days, "wed", "Should include Wednesday")
    test.assert_contains(breathing_meta.days, "fri", "Should include Friday")
end)

test.add_test("parse_items_with_metadata fallback content", function()
    local result_activities = parsing.parse_items_with_metadata(nil, "activities")
    local result_interventions = parsing.parse_items_with_metadata(nil, "interventions")
    local result_unknown = parsing.parse_items_with_metadata(nil, "unknown")
    
    test.assert_true(#result_activities.items > 0, "Should return fallback activities")
    test.assert_true(#result_interventions.items > 0, "Should return fallback interventions")
    test.assert_equals(0, #result_unknown.items, "Should return empty for unknown type")
end)

-- Test parse_item_options
test.add_test("parse_item_options extracts options", function()
    local content = [[
- Work {Options: In Office, From Home}  
- Walk {Options: Light, Medium, Heavy}
- Exercise {Required}
]]
    
    local work_options = parsing.parse_item_options(content, "Work")
    local walk_options = parsing.parse_item_options(content, "Walk")
    local exercise_options = parsing.parse_item_options(content, "Exercise")
    
    -- Work options
    test.assert_equals(2, #work_options, "Work should have 2 options")
    test.assert_contains(work_options, "In Office", "Should contain In Office")
    test.assert_contains(work_options, "From Home", "Should contain From Home")
    
    -- Walk options
    test.assert_equals(3, #walk_options, "Walk should have 3 options")
    test.assert_contains(walk_options, "Light", "Should contain Light")
    test.assert_contains(walk_options, "Medium", "Should contain Medium")
    test.assert_contains(walk_options, "Heavy", "Should contain Heavy")
    
    -- Exercise has no options
    test.assert_equals(nil, exercise_options, "Exercise should have no options")
end)

-- Test parse_radio_result
test.add_test("parse_radio_result handles valid selection", function()
    local options = {"Option 1", "Option 2", "Option 3"}
    
    test.assert_equals("Option 1", parsing.parse_radio_result(options, 1))
    test.assert_equals("Option 2", parsing.parse_radio_result(options, 2))
    test.assert_equals("Option 3", parsing.parse_radio_result(options, 3))
end)

test.add_test("parse_radio_result handles invalid input", function()
    local options = {"Option 1", "Option 2", "Option 3"}
    
    test.assert_equals(nil, parsing.parse_radio_result(options, 0), "Should handle index too low")
    test.assert_equals(nil, parsing.parse_radio_result(options, 4), "Should handle index too high")
    test.assert_equals(nil, parsing.parse_radio_result(nil, 1), "Should handle nil options")
    test.assert_equals(nil, parsing.parse_radio_result(options, nil), "Should handle nil index")
end)

-- Test parse_and_get_weekly_items
test.add_test("parse_and_get_weekly_items extracts weekly items", function()
    local content = [[
- Exercise {Required}
- Eye mask {Required: Weekly}
- Vitamin shot {Required: Weekly}
- Breathing {Required: Mon,Wed}
]]
    
    local weekly_items = parsing.parse_and_get_weekly_items(content)
    
    test.assert_equals(2, #weekly_items, "Should find 2 weekly items")
    test.assert_contains(weekly_items, "Eye mask", "Should include Eye mask")
    test.assert_contains(weekly_items, "Vitamin shot", "Should include Vitamin shot")
end)

test.add_test("parse_and_get_weekly_items handles empty content", function()
    local weekly_items = parsing.parse_and_get_weekly_items(nil)
    test.assert_equals(0, #weekly_items, "Should return empty array for nil content")
    
    local empty_items = parsing.parse_and_get_weekly_items("")
    test.assert_equals(0, #empty_items, "Should return empty array for empty content")
end)

-- Test handle_other_selection
test.add_test("handle_other_selection passes through input", function()
    test.assert_equals("Custom input", parsing.handle_other_selection("Custom input"))
    test.assert_equals("", parsing.handle_other_selection(""))
    test.assert_equals(nil, parsing.handle_other_selection(nil))
end)

if ... == nil then
    test.run_tests("Parsing Module Tests")
    local success = test.print_final_results()
    os.exit(success and 0 or 1)
end