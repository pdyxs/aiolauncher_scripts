-- test_dialog_manager.lua - Tests for dialog manager functionality
-- Tests dialog state management, data loading, and result processing

-- Add paths for imports
package.path = package.path .. ";../my/?.lua;./?.lua"

local test = require "test_framework"
local data = require "test_data"
local core = require "long_covid_core"

test.add_test("Dialog manager creation", function()
    local dialog_manager = core.create_dialog_manager()
    
    test.assert_type("table", dialog_manager, "Should return table")
    test.assert_type("function", dialog_manager.set_dialog_type, "Should have set_dialog_type method")
    test.assert_type("function", dialog_manager.get_dialog_type, "Should have get_dialog_type method")
    test.assert_type("function", dialog_manager.clear_dialog_type, "Should have clear_dialog_type method")
end)

test.add_test("Dialog type management", function()
    local dialog_manager = core.create_dialog_manager()
    
    -- Initial state
    test.assert_nil(dialog_manager:get_dialog_type(), "Should start with no dialog type")
    
    -- Set dialog type
    dialog_manager:set_dialog_type("symptom")
    test.assert_equals("symptom", dialog_manager:get_dialog_type(), "Should store dialog type")
    
    -- Change dialog type
    dialog_manager:set_dialog_type("activity")
    test.assert_equals("activity", dialog_manager:get_dialog_type(), "Should update dialog type")
    
    -- Clear dialog type
    dialog_manager:clear_dialog_type()
    test.assert_nil(dialog_manager:get_dialog_type(), "Should clear dialog type")
end)

test.add_test("Symptom data loading and caching", function()
    local dialog_manager = core.create_dialog_manager()
    local file_reader = data.create_mock_file_reader()
    local file_calls = {}
    
    -- Track file reader calls
    local tracked_reader = function(filename)
        table.insert(file_calls, filename)
        return file_reader(filename)
    end
    
    -- First load
    local symptoms1 = dialog_manager:load_symptoms(tracked_reader)
    test.assert_type("table", symptoms1, "Should return symptoms table")
    test.assert_true(#symptoms1 > 0, "Should have symptoms")
    test.assert_equals("Other...", symptoms1[#symptoms1], "Should end with Other...")
    
    -- Second load (should use cache)
    local symptoms2 = dialog_manager:load_symptoms(tracked_reader)
    test.assert_equals(symptoms1, symptoms2, "Should return cached symptoms")
    
    -- Check file reader was only called once
    local symptoms_calls = 0
    for _, call in ipairs(file_calls) do
        if call == "symptoms.md" then
            symptoms_calls = symptoms_calls + 1
        end
    end
    test.assert_equals(1, symptoms_calls, "Should only read file once due to caching")
end)

test.add_test("Activity data loading with required items", function()
    local dialog_manager = core.create_dialog_manager()
    local file_reader = data.create_mock_file_reader()
    
    local activities, required_activities = dialog_manager:load_activities(file_reader)
    
    test.assert_type("table", activities, "Should return activities table")
    test.assert_type("table", required_activities, "Should return required activities")
    test.assert_true(#activities > 0, "Should have activities")
    test.assert_true(#required_activities > 0, "Should have required activities")
    
    -- Check for expected items
    test.assert_contains(activities, "Light walk", "Should contain light walk")
    
    -- Check required activities structure
    local physio_found = false
    for _, req in ipairs(required_activities) do
        if req.name and req.name:find("Physio") then
            physio_found = true
            test.assert_type("table", req.days, "Physio should have specific days")
        end
    end
    test.assert_true(physio_found, "Should find Physio in required activities")
end)

test.add_test("Intervention data loading", function()
    local dialog_manager = core.create_dialog_manager()
    local file_reader = data.create_mock_file_reader()
    
    local interventions, required_interventions = dialog_manager:load_interventions(file_reader)
    
    test.assert_type("table", interventions, "Should return interventions table")
    test.assert_type("table", required_interventions, "Should return required interventions")
    test.assert_true(#interventions > 0, "Should have interventions")
    
    -- Check for expected items
    test.assert_contains(interventions, "LDN (4mg)", "Should contain LDN")
    test.assert_contains(interventions, "Other...", "Should end with Other...")
end)

test.add_test("Energy levels generation", function()
    local dialog_manager = core.create_dialog_manager()
    
    local energy_levels = dialog_manager:get_energy_levels()
    
    test.assert_type("table", energy_levels, "Should return table")
    test.assert_equals(10, #energy_levels, "Should have 10 energy levels")
    test.assert_equals("1 - Completely drained", energy_levels[1], "Should start with level 1")
    test.assert_equals("10 - Peak energy", energy_levels[10], "Should end with level 10")
end)

test.add_test("Dialog result handling - cancellation", function()
    local dialog_manager = core.create_dialog_manager()
    local file_reader = data.create_mock_file_reader()
    local daily_logs = {}
    local callbacks = data.create_mock_callbacks()
    
    dialog_manager:set_dialog_type("symptom")
    
    local action = dialog_manager:handle_dialog_result(-1, daily_logs, file_reader, callbacks.log)
    
    test.assert_equals("cancelled", action, "Should return cancelled for result -1")
    test.assert_nil(dialog_manager:get_dialog_type(), "Should clear dialog type on cancel")
end)

test.add_test("Dialog result handling - symptom selection", function()
    local dialog_manager = core.create_dialog_manager()
    local file_reader = data.create_mock_file_reader()
    local daily_logs = {}
    local callbacks = data.create_mock_callbacks()
    
    dialog_manager:set_dialog_type("symptom")
    
    -- Simulate selecting first symptom (index 1)
    local action, selected_item = dialog_manager:handle_dialog_result(1, daily_logs, file_reader, callbacks.log)
    
    test.assert_equals("logged", action, "Should return logged for valid selection")
    test.assert_equals(1, #callbacks.calls, "Should make one callback")
    test.assert_equals("log", callbacks.calls[1].type, "Should call log callback")
    test.assert_equals("symptom", callbacks.calls[1].item_type, "Should log symptom type")
end)

test.add_test("Dialog result handling - Other selection", function()
    local dialog_manager = core.create_dialog_manager()
    local file_reader = data.create_mock_file_reader()
    local daily_logs = {}
    local callbacks = data.create_mock_callbacks()
    
    dialog_manager:set_dialog_type("symptom")
    
    -- Load symptoms to get the count
    local symptoms = dialog_manager:load_symptoms(file_reader)
    local formatted_symptoms = core.format_list_items(symptoms, "symptom", daily_logs, {}, {})
    local other_index = #formatted_symptoms  -- "Other..." should be last
    
    local action, param1, param2, param3 = dialog_manager:handle_dialog_result(other_index, daily_logs, file_reader, callbacks.log)
    
    test.assert_equals("edit_dialog", action, "Should request edit dialog for Other...")
    test.assert_equals("Custom Symptom", param1, "Should have correct dialog title")
    test.assert_equals("Enter symptom name:", param2, "Should have correct prompt")
    test.assert_equals("", param3, "Should have empty default text")
    test.assert_equals("symptom_edit", dialog_manager:get_dialog_type(), "Should update to edit dialog type")
end)

test.add_test("Dialog result handling - custom text entry", function()
    local dialog_manager = core.create_dialog_manager()
    local file_reader = data.create_mock_file_reader()
    local daily_logs = {}
    local callbacks = data.create_mock_callbacks()
    
    dialog_manager:set_dialog_type("symptom_edit")
    
    local action = dialog_manager:handle_dialog_result("Custom headache", daily_logs, file_reader, callbacks.log)
    
    test.assert_equals("logged", action, "Should log custom text")
    test.assert_equals("symptom", dialog_manager:get_dialog_type(), "Should return to main dialog type")
    test.assert_equals(1, #callbacks.calls, "Should make one log call")
    test.assert_equals("Custom headache", callbacks.calls[1].item_value, "Should log custom value")
end)

test.add_test("Dialog result handling - empty text entry", function()
    local dialog_manager = core.create_dialog_manager()
    local file_reader = data.create_mock_file_reader()
    local daily_logs = {}
    local callbacks = data.create_mock_callbacks()
    
    dialog_manager:set_dialog_type("activity_edit")
    
    local action = dialog_manager:handle_dialog_result("", daily_logs, file_reader, callbacks.log)
    
    test.assert_equals("return_to_list", action, "Should return to list for empty text")
    test.assert_equals("activity", dialog_manager:get_dialog_type(), "Should return to main dialog type")
    test.assert_equals(0, #callbacks.calls, "Should not make any log calls")
end)

test.add_test("Dialog result handling - energy selection", function()
    local dialog_manager = core.create_dialog_manager()
    local file_reader = data.create_mock_file_reader()
    local daily_logs = {}
    local callbacks = data.create_mock_callbacks()
    
    dialog_manager:set_dialog_type("energy")
    
    -- Select energy level 7 (index 7)
    local action = dialog_manager:handle_dialog_result(7, daily_logs, file_reader, callbacks.log)
    
    test.assert_equals("logged", action, "Should log energy selection")
    test.assert_equals(1, #callbacks.calls, "Should make one callback")
    test.assert_equals("energy", callbacks.calls[1].item_type, "Should log energy type")
    test.assert_equals(7, callbacks.calls[1].item_value, "Should log correct energy level")
end)

test.add_test("Dialog result handling - activity with required items", function()
    local dialog_manager = core.create_dialog_manager()
    local file_reader = data.create_mock_file_reader()
    local daily_logs = data.create_sample_daily_logs()
    local callbacks = data.create_mock_callbacks()
    
    dialog_manager:set_dialog_type("activity")
    
    -- Load activities to get formatted list
    local activities, required_activities = dialog_manager:load_activities(file_reader)
    local mock_date, original_date = data.mock_os_date("2023-01-01")
    os.date = mock_date
    
    -- Select first activity (should be formatted)
    local action = dialog_manager:handle_dialog_result(1, daily_logs, file_reader, callbacks.log)
    
    test.assert_equals("logged", action, "Should log activity selection")
    test.assert_equals("activity", callbacks.calls[1].item_type, "Should log activity type")
    
    os.date = original_date
end)

test.add_test("Multiple dialog types in sequence", function()
    local dialog_manager = core.create_dialog_manager()
    local file_reader = data.create_mock_file_reader()
    local daily_logs = {}
    local callbacks = data.create_mock_callbacks()
    
    -- Test symptom -> activity -> intervention sequence
    dialog_manager:set_dialog_type("symptom")
    local symptoms = dialog_manager:load_symptoms(file_reader)
    test.assert_true(#symptoms > 0, "Should load symptoms")
    
    dialog_manager:set_dialog_type("activity")
    local activities, req_activities = dialog_manager:load_activities(file_reader)
    test.assert_true(#activities > 0, "Should load activities")
    
    dialog_manager:set_dialog_type("intervention")
    local interventions, req_interventions = dialog_manager:load_interventions(file_reader)
    test.assert_true(#interventions > 0, "Should load interventions")
    
    -- All data should still be cached
    test.assert_not_nil(dialog_manager.cached_symptoms, "Should cache symptoms")
    test.assert_not_nil(dialog_manager.cached_activities, "Should cache activities")
    test.assert_not_nil(dialog_manager.cached_interventions, "Should cache interventions")
end)

-- This file can be run standalone or included by main test runner
if ... == nil then
    test.run_tests("Dialog Manager")
    local success = test.print_final_results()
    os.exit(success and 0 or 1)
end