-- test_cache_manager.lua - Tests for cache manager functionality
-- Tests file caching, data loading, and cache management

-- Add paths for imports
package.path = package.path .. ";../my/?.lua;./?.lua"

local test = require "test_framework"
local data = require "test_data"
local core = require "long_covid_core"

test.add_test("Cache manager creation", function()
    local cache_manager = core.create_cache_manager()
    
    test.assert_type("table", cache_manager, "Should return table")
    test.assert_type("function", cache_manager.clear_cache, "Should have clear_cache method")
    test.assert_type("function", cache_manager.load_decision_criteria, "Should have load_decision_criteria method")
    test.assert_type("function", cache_manager.load_day_plan, "Should have load_day_plan method")
    test.assert_type("function", cache_manager.load_symptoms, "Should have load_symptoms method")
    test.assert_type("function", cache_manager.load_activities, "Should have load_activities method")
    test.assert_type("function", cache_manager.load_interventions, "Should have load_interventions method")
end)

test.add_test("Decision criteria caching", function()
    local cache_manager = core.create_cache_manager()
    local file_calls = {}
    
    -- Track file reader calls
    local file_reader = function(filename)
        table.insert(file_calls, filename)
        return data.create_mock_file_reader()(filename)
    end
    
    -- First load
    local criteria1 = cache_manager:load_decision_criteria(file_reader)
    test.assert_type("table", criteria1, "Should return criteria table")
    test.assert_not_nil(criteria1.red, "Should have red criteria")
    test.assert_not_nil(criteria1.yellow, "Should have yellow criteria")
    test.assert_not_nil(criteria1.green, "Should have green criteria")
    
    -- Second load (should use cache)
    local criteria2 = cache_manager:load_decision_criteria(file_reader)
    test.assert_equals(criteria1, criteria2, "Should return cached criteria")
    
    -- Verify file was only read once
    local criteria_calls = 0
    for _, call in ipairs(file_calls) do
        if call == "decision_criteria.md" then
            criteria_calls = criteria_calls + 1
        end
    end
    test.assert_equals(1, criteria_calls, "Should only read file once")
end)

test.add_test("Day plan caching", function()
    local cache_manager = core.create_cache_manager()
    local file_calls = {}
    
    local file_reader = function(filename)
        table.insert(file_calls, filename)
        return data.create_mock_file_reader()(filename)
    end
    
    -- Load Monday plan
    local monday1 = cache_manager:load_day_plan("monday", file_reader)
    test.assert_type("table", monday1, "Should return day plan")
    test.assert_not_nil(monday1.red, "Should have red level")
    test.assert_not_nil(monday1.yellow, "Should have yellow level")
    test.assert_not_nil(monday1.green, "Should have green level")
    
    -- Load same day again (should use cache)
    local monday2 = cache_manager:load_day_plan("monday", file_reader)
    test.assert_equals(monday1, monday2, "Should return cached plan")
    
    -- Load different day (should read file)
    cache_manager:load_day_plan("tuesday", file_reader)
    
    -- Check file reading pattern
    local monday_calls = 0
    local tuesday_calls = 0
    for _, call in ipairs(file_calls) do
        if call == "monday.md" then
            monday_calls = monday_calls + 1
        elseif call == "tuesday.md" then
            tuesday_calls = tuesday_calls + 1
        end
    end
    
    test.assert_equals(1, monday_calls, "Should read Monday file once")
    test.assert_equals(1, tuesday_calls, "Should read Tuesday file once")
end)

test.add_test("Symptom data caching", function()
    local cache_manager = core.create_cache_manager()
    local file_calls = {}
    
    local file_reader = function(filename)
        table.insert(file_calls, filename)
        return data.create_mock_file_reader()(filename)
    end
    
    -- First load
    local symptoms1 = cache_manager:load_symptoms(file_reader)
    test.assert_type("table", symptoms1, "Should return symptoms")
    test.assert_true(#symptoms1 > 0, "Should have symptoms")
    test.assert_equals("Other...", symptoms1[#symptoms1], "Should end with Other...")
    
    -- Second load (cached)
    local symptoms2 = cache_manager:load_symptoms(file_reader)
    test.assert_equals(symptoms1, symptoms2, "Should return cached symptoms")
    
    -- Verify caching
    local symptoms_calls = 0
    for _, call in ipairs(file_calls) do
        if call == "symptoms.md" then
            symptoms_calls = symptoms_calls + 1
        end
    end
    test.assert_equals(1, symptoms_calls, "Should only read symptoms file once")
end)

test.add_test("Activity data caching with required items", function()
    local cache_manager = core.create_cache_manager()
    local file_calls = {}
    
    local file_reader = function(filename)
        table.insert(file_calls, filename)
        return data.create_mock_file_reader()(filename)
    end
    
    -- First load
    local activities1, required1 = cache_manager:load_activities(file_reader)
    test.assert_type("table", activities1, "Should return activities")
    test.assert_type("table", required1, "Should return required activities")
    test.assert_true(#activities1 > 0, "Should have activities")
    
    -- Second load (cached)
    local activities2, required2 = cache_manager:load_activities(file_reader)
    test.assert_equals(activities1, activities2, "Should return cached activities")
    test.assert_equals(required1, required2, "Should return cached required activities")
    
    -- Verify file was read only once (efficient parsing of both activities and required from same content)
    local activities_calls = 0
    for _, call in ipairs(file_calls) do
        if call == "activities.md" then
            activities_calls = activities_calls + 1
        end
    end
    test.assert_equals(1, activities_calls, "Should read activities file once and parse both activities and required items")
    
    -- Third load should not read file again
    file_calls = {}
    cache_manager:load_activities(file_reader)
    test.assert_equals(0, #file_calls, "Should not read file on third load")
end)

test.add_test("Intervention data caching", function()
    local cache_manager = core.create_cache_manager()
    local file_calls = {}
    
    local file_reader = function(filename)
        table.insert(file_calls, filename)
        return data.create_mock_file_reader()(filename)
    end
    
    -- Load interventions
    local interventions, required = cache_manager:load_interventions(file_reader)
    test.assert_type("table", interventions, "Should return interventions")
    test.assert_type("table", required, "Should return required interventions")
    
    -- Verify content
    test.assert_contains(interventions, "LDN (4mg)", "Should contain LDN")
    test.assert_contains(interventions, "Other...", "Should end with Other...")
    
    -- Test required interventions structure
    local ldn_found = false
    for _, req in ipairs(required) do
        if req.name == "LDN (4mg)" then
            ldn_found = true
            test.assert_nil(req.days, "LDN should be required all days")
        end
    end
    test.assert_true(ldn_found, "Should find LDN in required list")
end)

test.add_test("Required activities and interventions getters", function()
    local cache_manager = core.create_cache_manager()
    local file_reader = data.create_mock_file_reader()
    
    -- Load data first
    cache_manager:load_activities(file_reader)
    cache_manager:load_interventions(file_reader)
    
    -- Test getters
    local required_activities = cache_manager:get_required_activities()
    local required_interventions = cache_manager:get_required_interventions()
    
    test.assert_type("table", required_activities, "Should return required activities")
    test.assert_type("table", required_interventions, "Should return required interventions")
    test.assert_true(#required_activities > 0, "Should have required activities")
    test.assert_true(#required_interventions > 0, "Should have required interventions")
end)

test.add_test("Cache clearing functionality", function()
    local cache_manager = core.create_cache_manager()
    local file_calls = {}
    
    local file_reader = function(filename)
        table.insert(file_calls, filename)
        return data.create_mock_file_reader()(filename)
    end
    
    -- Load various data types
    cache_manager:load_decision_criteria(file_reader)
    cache_manager:load_day_plan("monday", file_reader)
    cache_manager:load_symptoms(file_reader)
    cache_manager:load_activities(file_reader)
    cache_manager:load_interventions(file_reader)
    
    local initial_calls = #file_calls
    test.assert_true(initial_calls > 0, "Should have made file calls")
    
    -- Clear cache
    cache_manager:clear_cache()
    
    -- Reset file call tracking
    file_calls = {}
    
    -- Load data again - should re-read files
    cache_manager:load_decision_criteria(file_reader)
    cache_manager:load_day_plan("monday", file_reader)
    cache_manager:load_symptoms(file_reader)
    
    test.assert_true(#file_calls > 0, "Should re-read files after cache clear")
    
    -- Verify specific files are re-read
    local criteria_found = false
    local monday_found = false
    local symptoms_found = false
    
    for _, call in ipairs(file_calls) do
        if call == "decision_criteria.md" then criteria_found = true end
        if call == "monday.md" then monday_found = true end
        if call == "symptoms.md" then symptoms_found = true end
    end
    
    test.assert_true(criteria_found, "Should re-read criteria after clear")
    test.assert_true(monday_found, "Should re-read monday plan after clear")
    test.assert_true(symptoms_found, "Should re-read symptoms after clear")
end)

test.add_test("Multiple day plans caching", function()
    local cache_manager = core.create_cache_manager()
    local file_reader = data.create_mock_file_reader({
        ["monday.md"] = data.test_monday_content,
        ["tuesday.md"] = "## RED\n**Work:** Light tasks only",
        ["wednesday.md"] = "## GREEN\n**Work:** Full schedule possible"
    })
    
    -- Load different days
    local monday = cache_manager:load_day_plan("monday", file_reader)
    local tuesday = cache_manager:load_day_plan("tuesday", file_reader)
    local wednesday = cache_manager:load_day_plan("wednesday", file_reader)
    
    test.assert_not_nil(monday, "Should load Monday plan")
    test.assert_not_nil(tuesday, "Should load Tuesday plan")
    test.assert_not_nil(wednesday, "Should load Wednesday plan")
    
    -- Plans should be different
    test.assert_true(monday ~= tuesday, "Monday and Tuesday plans should be different objects")
    test.assert_true(tuesday ~= wednesday, "Tuesday and Wednesday plans should be different objects")
    
    -- Re-loading same day should return cached version
    local monday2 = cache_manager:load_day_plan("monday", file_reader)
    test.assert_equals(monday, monday2, "Should return cached Monday plan")
end)

test.add_test("Error handling with invalid files", function()
    local cache_manager = core.create_cache_manager()
    
    -- File reader that returns empty/invalid content
    local empty_file_reader = function(filename)
        return "" -- Empty content
    end
    
    -- Should handle empty content gracefully
    local criteria = cache_manager:load_decision_criteria(empty_file_reader)
    test.assert_type("table", criteria, "Should handle empty criteria file")
    test.assert_not_nil(criteria.red, "Should have default red criteria structure")
    
    local symptoms = cache_manager:load_symptoms(empty_file_reader)
    test.assert_type("table", symptoms, "Should handle empty symptoms file")
    test.assert_true(#symptoms > 0, "Should have default symptoms")
    
    local activities, required = cache_manager:load_activities(empty_file_reader)
    test.assert_type("table", activities, "Should handle empty activities file")
    test.assert_type("table", required, "Should handle empty required activities")
end)

test.add_test("Cache independence between managers", function()
    local cache_manager1 = core.create_cache_manager()
    local cache_manager2 = core.create_cache_manager()
    
    local file_reader = data.create_mock_file_reader()
    
    -- Load data in first manager
    cache_manager1:load_symptoms(file_reader)
    
    -- Second manager should have empty cache
    test.assert_nil(cache_manager2.cached_symptoms, "Second manager should start with empty cache")
    
    -- Clear first manager shouldn't affect second
    cache_manager1:clear_cache()
    cache_manager2:load_symptoms(file_reader)
    
    test.assert_not_nil(cache_manager2.cached_symptoms, "Second manager should load independently")
end)

-- This file can be run standalone or included by main test runner
if ... == nil then
    test.run_tests("Cache Manager")
    local success = test.print_final_results()
    os.exit(success and 0 or 1)
end