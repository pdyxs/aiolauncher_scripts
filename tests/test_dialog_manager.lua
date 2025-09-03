-- test_dialog_manager.lua - Tests for dialog manager functionality  
-- Tests data loading, caching, and file reading

-- Add paths for imports
package.path = package.path .. ";../my/?.lua;./?.lua"

local test = require "test_framework"
local data = require "test_data"
local core = require "long_covid_core"

test.add_test("Dialog manager creation", function()
    local dialog_manager = core.create_dialog_manager()
    
    test.assert_type("table", dialog_manager, "Should return table")
    test.assert_type("function", dialog_manager.load_symptoms, "Should have load_symptoms method")
    test.assert_type("function", dialog_manager.load_activities, "Should have load_activities method")
    test.assert_type("function", dialog_manager.load_interventions, "Should have load_interventions method")
    test.assert_type("function", dialog_manager.get_activities_content, "Should have get_activities_content method")
    test.assert_type("function", dialog_manager.get_interventions_content, "Should have get_interventions_content method")
end)

test.add_test("Symptom data loading and caching", function()
    local dialog_manager = core.create_dialog_manager()
    local file_reader = data.create_mock_file_reader()
    
    local symptoms = dialog_manager:load_symptoms(file_reader)
    
    test.assert_type("table", symptoms, "Should return table")
    test.assert_true(#symptoms > 0, "Should have symptoms loaded")
    test.assert_equals("Fatigue", symptoms[1], "Should load first symptom")
end)

test.add_test("Activity data loading with required items", function()
    local dialog_manager = core.create_dialog_manager()
    local file_reader = data.create_mock_file_reader()
    
    local activities, required_activities = dialog_manager:load_activities(file_reader)
    
    test.assert_type("table", activities, "Should return activities table")
    test.assert_type("table", required_activities, "Should return required activities")
    test.assert_true(#activities > 0, "Should have activities loaded")
    test.assert_true(#required_activities > 0, "Should have required activities")
end)

test.add_test("Intervention data loading", function()
    local dialog_manager = core.create_dialog_manager()
    local file_reader = data.create_mock_file_reader()
    
    local interventions, required_interventions = dialog_manager:load_interventions(file_reader)
    
    test.assert_type("table", interventions, "Should return interventions table")
    test.assert_type("table", required_interventions, "Should return required interventions")
    test.assert_true(#interventions > 0, "Should have interventions loaded")
    test.assert_true(#required_interventions > 0, "Should have required interventions")
end)

test.add_test("Data caching functionality", function()
    local dialog_manager = core.create_dialog_manager()
    local file_reader = data.create_mock_file_reader()
    
    -- Load data for the first time
    local symptoms1 = dialog_manager:load_symptoms(file_reader)
    local activities1, required_activities1 = dialog_manager:load_activities(file_reader)
    local interventions1, required_interventions1 = dialog_manager:load_interventions(file_reader)
    
    -- Load data again - should use cached versions
    local symptoms2 = dialog_manager:load_symptoms(file_reader)
    local activities2, required_activities2 = dialog_manager:load_activities(file_reader)
    local interventions2, required_interventions2 = dialog_manager:load_interventions(file_reader)
    
    -- Verify caching works (same table references)
    test.assert_equals(symptoms1, symptoms2, "Symptoms should be cached")
    test.assert_equals(activities1, activities2, "Activities should be cached")
    test.assert_equals(interventions1, interventions2, "Interventions should be cached")
    test.assert_equals(required_activities1, required_activities2, "Required activities should be cached")
    test.assert_equals(required_interventions1, required_interventions2, "Required interventions should be cached")
end)

test.add_test("Content access methods", function()
    local dialog_manager = core.create_dialog_manager()
    local file_reader = data.create_mock_file_reader()
    
    -- Load data to populate cache
    dialog_manager:load_activities(file_reader)
    dialog_manager:load_interventions(file_reader)
    
    -- Test content access methods
    local activities_content = dialog_manager:get_activities_content()
    local interventions_content = dialog_manager:get_interventions_content()
    
    test.assert_type("string", activities_content, "Should return activities content as string")
    test.assert_type("string", interventions_content, "Should return interventions content as string")
    test.assert_true(#activities_content > 0, "Activities content should not be empty")
    test.assert_true(#interventions_content > 0, "Interventions content should not be empty")
end)

-- Run tests if this file is executed directly
if ... == nil then
    test.run_tests("Dialog Manager")
    local success = test.print_final_results()
    os.exit(success and 0 or 1)
end