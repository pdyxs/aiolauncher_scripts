#!/usr/bin/env lua

-- Integration Test Suite for Symptoms Dialog Flow
-- Tests the complete integration between dialog flow manager and widget
-- Run with: lua test_symptoms_integration.lua

-- Add the 'my' directory to the Lua path so we can import the core module
package.path = package.path .. ";../my/?.lua"

-- Import dependencies
local core = require "long_covid_core"
local test_framework = require "test_framework"

-- Mock AIO environment
local mock_dialogs = {
    calls = {}
}

function mock_dialogs:show_list_dialog(config)
    table.insert(self.calls, {"list", config.title, config.lines})
end

function mock_dialogs:show_radio_dialog(title, options, selected)
    table.insert(self.calls, {"radio", title, options, selected})
end

function mock_dialogs:show_edit_dialog(title, prompt, default)
    table.insert(self.calls, {"edit", title, prompt, default})
end

function mock_dialogs:reset()
    self.calls = {}
end

-- Mock widget environment
local mock_widget = {
    dialog_manager = nil,
    dialog_flow_manager = nil,
    daily_logs = {},
    logged_items = {}
}

function mock_widget:setup()
    self.dialog_manager = core.create_dialog_manager()
    self.dialog_flow_manager = core.create_dialog_flow_manager()
    
    -- Mock file reader for dialog manager
    local mock_file_reader = function(filename)
        if filename == "symptoms.md" then
            return nil -- Will use default symptoms
        end
        return nil
    end
    
    -- Pre-load symptoms into dialog manager cache
    self.dialog_manager:load_symptoms(mock_file_reader)
    
    -- Initialize flow manager
    self.dialog_flow_manager:set_data_manager(self.dialog_manager)
    self.dialog_flow_manager:set_daily_logs(self.daily_logs)
end

function mock_widget:show_aio_dialog(dialog_config)
    if dialog_config.type == "list" then
        mock_dialogs:show_list_dialog({
            title = dialog_config.title,
            lines = dialog_config.data.items,
            search = true,
            zebra = true
        })
    elseif dialog_config.type == "radio" then
        mock_dialogs:show_radio_dialog(dialog_config.title, dialog_config.data.options, 0)
    elseif dialog_config.type == "edit" then
        mock_dialogs:show_edit_dialog(dialog_config.title, dialog_config.data.prompt, dialog_config.data.default_text or "")
    end
end

function mock_widget:start_symptom_flow()
    local status, dialog_config = self.dialog_flow_manager:start_flow("symptom")
    
    if status == "show_dialog" then
        self:show_aio_dialog(dialog_config)
        return "dialog_shown"
    else
        return status
    end
end

function mock_widget:handle_dialog_action(result)
    if self.dialog_flow_manager:get_current_dialog() then
        local status, flow_result = self.dialog_flow_manager:handle_dialog_result(result)
        
        if status == "show_dialog" then
            self:show_aio_dialog(flow_result)
            return "dialog_shown"
        elseif status == "flow_complete" then
            self:log_item(flow_result.category, flow_result.item, flow_result.metadata)
            return "flow_complete"
        elseif status == "flow_cancelled" then
            return "flow_cancelled"
        elseif status == "continue" then
            return "continue"
        elseif status == "error" then
            return "error"
        end
    end
    return "no_active_flow"
end

function mock_widget:log_item(item_type, item_value, metadata)
    local logged_value = item_value
    
    -- Handle metadata (same logic as in the widget)
    if metadata and metadata.severity then
        logged_value = item_value .. " (severity: " .. metadata.severity .. ")"
    end
    
    table.insert(self.logged_items, {
        type = item_type,
        value = logged_value,
        metadata = metadata
    })
end

-- Integration tests
test_framework.add_test("Widget symptoms flow initialization", function()
    mock_widget:setup()
    mock_dialogs:reset()
    
    local status = mock_widget:start_symptom_flow()
    
    test_framework.assert_equals("dialog_shown", status)
    test_framework.assert_equals(1, #mock_dialogs.calls)
    
    local call = mock_dialogs.calls[1]
    test_framework.assert_equals("list", call[1])
    test_framework.assert_equals("Select Symptom", call[2])
    test_framework.assert_contains(call[3], "   Fatigue")
end)

test_framework.add_test("Complete symptoms flow - direct selection", function()
    mock_widget:setup()
    mock_dialogs:reset()
    mock_widget.logged_items = {}
    
    -- Start flow
    mock_widget:start_symptom_flow()
    
    -- Select "Fatigue" (index 1)
    local status = mock_widget:handle_dialog_action(1)
    test_framework.assert_equals("dialog_shown", status)
    
    -- Should now show severity dialog
    test_framework.assert_equals(2, #mock_dialogs.calls)
    local severity_call = mock_dialogs.calls[2]
    test_framework.assert_equals("radio", severity_call[1])
    test_framework.assert_equals("Symptom Severity", severity_call[2])
    test_framework.assert_contains(severity_call[3], "5 - Moderate-High")
    
    -- Select severity level 5
    status = mock_widget:handle_dialog_action(5)
    test_framework.assert_equals("flow_complete", status)
    
    -- Check that item was logged with severity
    test_framework.assert_equals(1, #mock_widget.logged_items)
    local logged = mock_widget.logged_items[1]
    test_framework.assert_equals("symptom", logged.type)
    test_framework.assert_equals("Fatigue (severity: 5)", logged.value)
    test_framework.assert_equals(5, logged.metadata.severity)
end)

test_framework.add_test("Complete symptoms flow - custom input", function()
    mock_widget:setup()
    mock_dialogs:reset()
    mock_widget.logged_items = {}
    
    -- Start flow
    mock_widget:start_symptom_flow()
    
    -- Select "Other..." (index 8)
    local status = mock_widget:handle_dialog_action(8)
    test_framework.assert_equals("dialog_shown", status)
    
    -- Should now show custom input dialog
    test_framework.assert_equals(2, #mock_dialogs.calls)
    local edit_call = mock_dialogs.calls[2]
    test_framework.assert_equals("edit", edit_call[1])
    test_framework.assert_equals("Custom Symptom", edit_call[2])
    test_framework.assert_equals("Enter symptom name:", edit_call[3])
    
    -- Enter custom symptom
    status = mock_widget:handle_dialog_action("Custom Fatigue")
    test_framework.assert_equals("dialog_shown", status)
    
    -- Should now show severity dialog
    test_framework.assert_equals(3, #mock_dialogs.calls)
    local severity_call = mock_dialogs.calls[3]
    test_framework.assert_equals("radio", severity_call[1])
    test_framework.assert_equals("Symptom Severity", severity_call[2])
    
    -- Select severity level 3
    status = mock_widget:handle_dialog_action(3)
    test_framework.assert_equals("flow_complete", status)
    
    -- Check that custom item was logged with severity
    test_framework.assert_equals(1, #mock_widget.logged_items)
    local logged = mock_widget.logged_items[1]
    test_framework.assert_equals("symptom", logged.type)
    test_framework.assert_equals("Custom Fatigue (severity: 3)", logged.value)
    test_framework.assert_equals(3, logged.metadata.severity)
end)

test_framework.add_test("Cancel symptoms flow at severity level", function()
    mock_widget:setup()
    mock_dialogs:reset()
    mock_widget.logged_items = {}
    
    -- Start flow and select symptom
    mock_widget:start_symptom_flow()
    mock_widget:handle_dialog_action(1) -- "Fatigue"
    
    -- Cancel at severity level
    local status = mock_widget:handle_dialog_action(-1)
    test_framework.assert_equals("dialog_shown", status)
    
    -- Should be back at main list
    test_framework.assert_equals(3, #mock_dialogs.calls)
    local back_to_list = mock_dialogs.calls[3]
    test_framework.assert_equals("list", back_to_list[1])
    test_framework.assert_equals("Select Symptom", back_to_list[2])
    
    -- Nothing should be logged
    test_framework.assert_equals(0, #mock_widget.logged_items)
end)

test_framework.add_test("Cancel symptoms flow completely", function()
    mock_widget:setup()
    mock_dialogs:reset()
    mock_widget.logged_items = {}
    
    -- Start flow
    mock_widget:start_symptom_flow()
    
    -- First cancel (list dialog quirk)
    local status = mock_widget:handle_dialog_action(-1)
    test_framework.assert_equals("continue", status)
    
    -- Second cancel (actual cancel)
    status = mock_widget:handle_dialog_action(-1)
    test_framework.assert_equals("flow_cancelled", status)
    
    -- Nothing should be logged
    test_framework.assert_equals(0, #mock_widget.logged_items)
end)

test_framework.add_test("Empty custom input returns to main list", function()
    mock_widget:setup()
    mock_dialogs:reset()
    mock_widget.logged_items = {}
    
    -- Start flow and select Other...
    mock_widget:start_symptom_flow()
    mock_widget:handle_dialog_action(8) -- "Other..."
    
    -- Enter empty string
    local status = mock_widget:handle_dialog_action("")
    test_framework.assert_equals("dialog_shown", status)
    
    -- Should be back at main list
    test_framework.assert_equals(3, #mock_dialogs.calls)
    local back_to_list = mock_dialogs.calls[3]
    test_framework.assert_equals("list", back_to_list[1])
    test_framework.assert_equals("Select Symptom", back_to_list[2])
    
    -- Nothing should be logged
    test_framework.assert_equals(0, #mock_widget.logged_items)
end)

-- Run the integration tests
local success = test_framework.run_tests("Symptoms Dialog Flow Integration Tests")

if success then
    print("\nSymptoms dialog flow integration is working correctly!")
    print("The new dialog stack system is ready for use.")
else
    print("\nSome integration tests failed. Please review the implementation.")
    os.exit(1)
end