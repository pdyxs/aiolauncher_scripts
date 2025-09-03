#!/usr/bin/env lua

-- Test Suite for Dialog Stack System
-- Tests the new dialog flow management system for multi-level dialogs
-- Run with: lua test_dialog_stack.lua

-- Add the 'my' directory to the Lua path so we can import the core module
package.path = package.path .. ";../my/?.lua"

-- Import dependencies
local core = require "long_covid_core"
local test_framework = require "test_framework"

-- Mock data manager for testing  
local function create_mock_data_manager()
    return {
        load_symptoms = function()
            return {
                "Fatigue",
                "Brain fog", 
                "Heart palpitations",
                "Other..."
            }
        end
    }
end

-- Mock daily logs for testing
local function create_mock_daily_logs()
    return {}
end

-- Test DialogStack basic operations
test_framework.add_test("DialogStack creation and basic operations", function()
    local stack = core.create_dialog_stack("symptom")
    
    test_framework.assert_equals("symptom", stack.category)
    test_framework.assert_true(stack:is_empty())
    test_framework.assert_nil(stack:get_current_dialog())
    
    -- Test push operation
    local dialog_config = {
        type = "radio",
        name = "main_list",
        data = {options = {"option1", "option2"}}
    }
    
    stack:push_dialog(dialog_config)
    test_framework.assert_false(stack:is_empty())
    
    local current = stack:get_current_dialog()
    test_framework.assert_equals("radio", current.type)
    test_framework.assert_equals("main_list", current.name)
end)

test_framework.add_test("DialogStack context aggregation", function()
    local stack = core.create_dialog_stack("symptom")
    
    -- Push first dialog with some data
    stack:push_dialog({
        type = "radio",
        name = "main_list", 
        data = {selected_item = "Fatigue", options = {"Fatigue", "Other..."}}
    })
    
    -- Push second dialog with more data
    stack:push_dialog({
        type = "radio", 
        name = "severity",
        data = {selected_option = "5 - Moderate-High", options = {"1 - Minimal", "5 - Moderate-High"}}
    })
    
    local context = stack:get_full_context()
    test_framework.assert_equals("Fatigue", context.selected_item)
    test_framework.assert_equals("5 - Moderate-High", context.selected_option)
    -- Context should contain options from the latest dialog (severity), not the first dialog
    test_framework.assert_contains(context.options, "1 - Minimal")
end)

test_framework.add_test("DialogStack pop operations", function()
    local stack = core.create_dialog_stack("symptom")
    
    local dialog1 = {type = "radio", name = "main_list", data = {}}
    local dialog2 = {type = "radio", name = "severity", data = {}}
    
    stack:push_dialog(dialog1)
    stack:push_dialog(dialog2)
    
    -- Pop should return the last dialog
    local popped = stack:pop_dialog()
    test_framework.assert_equals("severity", popped.name)
    
    -- Current dialog should now be the first one
    local current = stack:get_current_dialog()
    test_framework.assert_equals("main_list", current.name)
    
    -- Pop again
    stack:pop_dialog()
    test_framework.assert_true(stack:is_empty())
end)

-- Test Dialog Flow Manager creation and setup
test_framework.add_test("Dialog Flow Manager creation", function()
    local manager = core.create_dialog_flow_manager()
    
    test_framework.assert_type("table", manager)
    test_framework.assert_nil(manager.current_stack)
    test_framework.assert_type("table", manager.flow_definitions)
    test_framework.assert_type("table", manager.flow_definitions.symptom)
end)

test_framework.add_test("Dialog Flow Manager start_flow", function()
    local manager = core.create_dialog_flow_manager()
    local data_manager = create_mock_data_manager()
    local daily_logs = create_mock_daily_logs()
    manager:set_data_manager(data_manager)
    manager:set_daily_logs(daily_logs)
    
    local status, result = manager:start_flow("symptom")
    
    test_framework.assert_equals("show_dialog", status)
    test_framework.assert_type("table", result)
    test_framework.assert_equals("radio", result.type)
    test_framework.assert_equals("main_list", result.name)
    test_framework.assert_contains(result.data.options, "   Fatigue")
    
    -- Should have created a stack
    test_framework.assert_not_nil(manager.current_stack)
    test_framework.assert_equals("symptom", manager.current_stack.category)
end)

test_framework.add_test("Dialog Flow Manager handle invalid flow", function()
    local manager = core.create_dialog_flow_manager()
    
    local status, error_msg = manager:start_flow("invalid_category")
    test_framework.assert_equals("error", status)
    test_framework.assert_contains(error_msg, "Unknown flow category")
end)

test_framework.add_test("Dialog Flow Manager handle list selection", function()
    local manager = core.create_dialog_flow_manager()
    local data_manager = create_mock_data_manager()
    local daily_logs = create_mock_daily_logs()
    manager:set_data_manager(data_manager)
    manager:set_daily_logs(daily_logs)
    
    -- Start flow
    manager:start_flow("symptom")
    
    -- Simulate selecting first item (Fatigue)
    local status, result = manager:handle_dialog_result(1)
    
    test_framework.assert_equals("show_dialog", status)
    test_framework.assert_equals("severity", result.name)
    test_framework.assert_equals("radio", result.type)
    test_framework.assert_contains(result.data.options, "1 - Minimal")
    
    -- Check context was preserved
    local context = manager.current_stack:get_full_context()
    test_framework.assert_equals("Fatigue", context.selected_item)
end)

test_framework.add_test("Dialog Flow Manager handle Other... selection", function()
    local manager = core.create_dialog_flow_manager()
    local data_manager = create_mock_data_manager()
    local daily_logs = create_mock_daily_logs()
    manager:set_data_manager(data_manager)
    manager:set_daily_logs(daily_logs)
    
    -- Start flow
    manager:start_flow("symptom")
    
    -- Simulate selecting "Other..." (index 4)
    local status, result = manager:handle_dialog_result(4)
    
    test_framework.assert_equals("show_dialog", status)
    test_framework.assert_equals("custom_input", result.name)
    test_framework.assert_equals("edit", result.type)
    test_framework.assert_equals("Enter symptom name:", result.data.prompt)
end)

test_framework.add_test("Dialog Flow Manager custom input to severity", function()
    local manager = core.create_dialog_flow_manager()
    local data_manager = create_mock_data_manager()
    local daily_logs = create_mock_daily_logs()
    manager:set_data_manager(data_manager)
    manager:set_daily_logs(daily_logs)
    
    -- Start flow and go to custom input
    manager:start_flow("symptom")
    manager:handle_dialog_result(4) -- "Other..."
    
    -- Enter custom symptom
    local status, result = manager:handle_dialog_result("My Custom Symptom")
    
    test_framework.assert_equals("show_dialog", status)
    test_framework.assert_equals("severity", result.name)
    
    -- Check custom input was preserved
    local context = manager.current_stack:get_full_context()
    test_framework.assert_equals("My Custom Symptom", context.custom_input)
end)

test_framework.add_test("Dialog Flow Manager severity completion", function()
    local manager = core.create_dialog_flow_manager()
    local data_manager = create_mock_data_manager()
    local daily_logs = create_mock_daily_logs()
    manager:set_data_manager(data_manager)
    manager:set_daily_logs(daily_logs)
    
    -- Start flow, select symptom, go to severity
    manager:start_flow("symptom")
    manager:handle_dialog_result(1) -- "Fatigue"
    
    -- Select severity level 5
    local status, result = manager:handle_dialog_result(5) -- "5 - Moderate-High"
    
    test_framework.assert_equals("flow_complete", status)
    test_framework.assert_equals("symptom", result.category)
    test_framework.assert_equals("Fatigue", result.item)
    test_framework.assert_equals(5, result.metadata.severity)
    
    -- Stack should be reset
    test_framework.assert_nil(manager.current_stack)
end)

test_framework.add_test("Dialog Flow Manager custom symptom completion", function()
    local manager = core.create_dialog_flow_manager()
    local data_manager = create_mock_data_manager()
    local daily_logs = create_mock_daily_logs()
    manager:set_data_manager(data_manager)
    manager:set_daily_logs(daily_logs)
    
    -- Start flow, select Other..., enter custom, select severity
    manager:start_flow("symptom")
    manager:handle_dialog_result(4) -- "Other..."
    manager:handle_dialog_result("Custom Symptom") -- custom input
    
    -- Select severity level 3
    local status, result = manager:handle_dialog_result(3) -- "3 - Mild-Moderate"
    
    test_framework.assert_equals("flow_complete", status)
    test_framework.assert_equals("symptom", result.category) 
    test_framework.assert_equals("Custom Symptom", result.item)
    test_framework.assert_equals(3, result.metadata.severity)
end)

test_framework.add_test("Dialog Flow Manager cancellation handling", function()
    local manager = core.create_dialog_flow_manager()
    local data_manager = create_mock_data_manager()
    local daily_logs = create_mock_daily_logs()
    manager:set_data_manager(data_manager)
    manager:set_daily_logs(daily_logs)
    
    -- Start flow
    manager:start_flow("symptom")
    
    -- Cancel should handle list dialog quirk first
    local status = manager:handle_dialog_result(-1)
    test_framework.assert_equals("continue", status)
    
    -- Second cancel should actually cancel the flow
    status = manager:handle_dialog_result(-1)
    test_framework.assert_equals("flow_cancelled", status)
    test_framework.assert_nil(manager.current_stack)
end)

test_framework.add_test("Dialog Flow Manager empty custom input", function()
    local manager = core.create_dialog_flow_manager()
    local data_manager = create_mock_data_manager()
    local daily_logs = create_mock_daily_logs()
    manager:set_data_manager(data_manager)
    manager:set_daily_logs(daily_logs)
    
    -- Start flow and go to custom input
    manager:start_flow("symptom")
    manager:handle_dialog_result(4) -- "Other..."
    
    -- Enter empty string (should be treated as cancel with ignore flag active)
    local status = manager:handle_dialog_result("")
    -- With ignore cancellation system, empty edit should return "continue"
    test_framework.assert_equals("continue", status)
    
    -- Should still be on custom input dialog (cancel was ignored)
    local current = manager:get_current_dialog()
    test_framework.assert_equals("custom_input", current.name)
end)

-- Run tests if this file is executed directly
if ... == nil then
    local success = test_framework.run_tests("Dialog Stack System Tests")
    local final_success = test_framework.print_final_results()
    os.exit(final_success and 0 or 1)
end