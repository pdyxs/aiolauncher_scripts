#!/usr/bin/env lua

-- Test harness to debug cancellation state bug
-- Issue: After cancelling severity dialog, next symptom selection causes severity dialog to open/close immediately

package.path = package.path .. ";../my/?.lua;../?.lua"

-- Mock AIO environment
_G.files = {
    read = function(filename) return nil end  -- Use default symptoms
}

_G.debug = {
    toast = function(self, message) print("DEBUG: " .. message) end
}

-- Load the core module
local core = require("long_covid_core")
local dialog_manager = core.create_dialog_manager()
local dialog_flow_manager = core.create_dialog_flow_manager()

dialog_flow_manager:set_data_manager(dialog_manager)
dialog_flow_manager:set_daily_logs({})

print("=== CANCELLATION STATE BUG TEST ===")
print()

-- Scenario: Cancel at severity dialog, then try another symptom
print("SCENARIO 1: Cancel at severity level")
print("1. Start symptom flow → select symptom → reach severity dialog → cancel → try another symptom")
print()

-- Step 1: Start and get to severity dialog
print("1a. Starting symptom flow and selecting Fatigue...")
dialog_flow_manager:start_flow("symptom")
local status1, result1 = dialog_flow_manager:handle_dialog_result(1)  -- Select Fatigue
print("   Status after Fatigue selection:", status1)

-- Step 2: Cancel the severity dialog
print("1b. Cancelling severity dialog...")
local status2, result2 = dialog_flow_manager:handle_dialog_result(-1)  -- Cancel
print("   Status after cancel:", status2)
print("   Has active dialog:", dialog_flow_manager:get_current_dialog() ~= nil)
if dialog_flow_manager:get_current_dialog() then
    local current = dialog_flow_manager:get_current_dialog()
    print("   Current dialog type:", current.type)
    print("   Current step name:", current.step_name)
end

-- Step 3: Try to select another symptom (this should work normally)
print("1c. Selecting Brain fog (item 2)...")
local status3, result3 = dialog_flow_manager:handle_dialog_result(2)  -- Select Brain fog
print("   Status after Brain fog selection:", status3)
if status3 == "show_dialog" then
    print("   Next dialog type:", result3.type)
    print("   Next dialog title:", result3.title)
else
    print("   ERROR: Expected show_dialog, got:", status3)
end

-- Step 4: Simulate the immediate cancel that happens on device  
print("1d. Simulating immediate cancel (the bug)...")
print("   ignore_next_cancel flag before cancel:", dialog_flow_manager.ignore_next_cancel)
local status4, result4 = dialog_flow_manager:handle_dialog_result(-1)  -- Immediate cancel
print("   Status after immediate cancel:", status4)
print("   ignore_next_cancel flag after cancel:", dialog_flow_manager.ignore_next_cancel)
print("   Final state - has active dialog:", dialog_flow_manager:get_current_dialog() ~= nil)
print()

print("=== EXPECTED vs ACTUAL ===")
print("Expected:")
print("  1c. Select Brain fog → show_dialog (severity)")
print("  1d. Immediate cancel → continue (ignore)")
print("  Final: Severity dialog stays open")
print()
print("Actual:")
print("  1c. Select Brain fog →", status3)
print("  1d. Immediate cancel →", status4)
print("  Final: Dialog active =", dialog_flow_manager:get_current_dialog() ~= nil)
print()

-- Clean slate test for comparison
print("=== CLEAN SLATE COMPARISON ===")
print("Testing same sequence with fresh dialog manager...")
local fresh_manager = core.create_dialog_flow_manager()
fresh_manager:set_data_manager(dialog_manager)
fresh_manager:set_daily_logs({})

fresh_manager:start_flow("symptom")
local fresh_status1, fresh_result1 = fresh_manager:handle_dialog_result(2)  -- Select Brain fog
print("Fresh manager - Brain fog selection:", fresh_status1)
local fresh_status2, fresh_result2 = fresh_manager:handle_dialog_result(-1)  -- Cancel
print("Fresh manager - immediate cancel:", fresh_status2)
print("Fresh manager - final state:", fresh_manager:get_current_dialog() ~= nil)
print()

print("=== DIAGNOSIS ===")
print("If fresh manager works but post-cancellation manager doesn't,")
print("then the issue is that cancellation leaves the dialog manager in a bad state.")