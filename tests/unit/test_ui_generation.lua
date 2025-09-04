-- Add paths for imports
package.path = package.path .. ";../my/?.lua;./?.lua"

local test = require "test_framework"

-- Load the UI module
local ui = require "long_covid_ui"

-- Test button mapper functionality
test.add_test("UI module button mapper creation", function()
    local mapper = ui.create_button_mapper()
    
    test.assert_type("table", mapper, "Should return table")
    test.assert_type("function", mapper.identify_button_action, "Should have identify_button_action method")
    test.assert_type("function", mapper.can_select_level, "Should have can_select_level method")
end)

test.add_test("UI module button mapper identification", function()
    local mapper = ui.create_button_mapper()
    
    local action, level = mapper:identify_button_action("%%fa:bed%% Recovering")
    test.assert_equals("capacity_level", action, "Should identify capacity level button")
    test.assert_equals(1, level, "Should return correct level")
    
    local action2, level2 = mapper:identify_button_action("fa:rocket-launch")
    test.assert_equals("capacity_level", action2, "Should identify rocket launch button")
    test.assert_equals(3, level2, "Should return level 3")
end)

-- Test dialog manager functionality
test.add_test("UI module dialog manager creation", function()
    local dialog_manager = ui.create_dialog_manager()
    
    test.assert_type("table", dialog_manager, "Should return table")
    test.assert_type("function", dialog_manager.load_symptoms, "Should have load_symptoms method")
    test.assert_type("function", dialog_manager.load_activities, "Should have load_activities method")
    test.assert_type("function", dialog_manager.get_energy_levels, "Should have get_energy_levels method")
end)

test.add_test("UI module dialog manager energy levels", function()
    local dialog_manager = ui.create_dialog_manager()
    local energy_levels = dialog_manager:get_energy_levels()
    
    test.assert_type("table", energy_levels, "Should return table")
    test.assert_equals(10, #energy_levels, "Should have 10 energy levels")
    test.assert_contains(energy_levels, "5 - Average", "Should include middle energy level")
end)

if ... == nil then
    test.run_tests("UI Generation Tests")
    local success = test.print_final_results()
    os.exit(success and 0 or 1)
end