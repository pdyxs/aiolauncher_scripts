#!/usr/bin/env lua

-- Test harness to simulate AIO dialog behavior for debugging dialog stack issues
-- This simulates the exact sequence: selection (15) → cancel (-1)

package.path = package.path .. ";../my/?.lua;../?.lua"

-- Mock AIO environment
local mock_files = {
    ["symptoms.md"] = [[
# Symptoms

## Physical
- Fatigue
- Brain fog
- Headache
- Shortness of breath
- Joint pain
- Muscle aches
- Sleep issues
]]
}

-- Mock AIO APIs that the core module might use
_G.files = {
    read = function(filename) return mock_files[filename] end
}

_G.debug = {
    toast = function(self, message) print("DEBUG TOAST: " .. message) end
}

-- Load the core module
local core = require("long_covid_core")

-- Create managers
local dialog_manager = core.create_dialog_manager()
local dialog_flow_manager = core.create_dialog_flow_manager()

-- Set up the dialog flow manager
dialog_flow_manager:set_data_manager(dialog_manager)
dialog_flow_manager:set_daily_logs({})

print("=== DIALOG FLOW SIMULATION TEST ===")
print()

-- Step 1: Start the symptom flow (like clicking symptom button)
print("1. Starting symptom flow...")
local status1, dialog_config1 = dialog_flow_manager:start_flow("symptom")
print("   Status:", status1)
if status1 == "show_dialog" then
    print("   Dialog Type:", dialog_config1.type)
    print("   Dialog Title:", dialog_config1.title)
    print("   Number of symptoms:", #dialog_config1.data.items)
    print("   First few symptoms:", table.concat({dialog_config1.data.items[1], dialog_config1.data.items[2], dialog_config1.data.items[3]}, ", "))
end
print()

-- Step 2: Simulate selecting a symptom (use item 1 = Fatigue)
print("2. Simulating symptom selection (result = 1 for Fatigue)...")
local status2, flow_result2 = dialog_flow_manager:handle_dialog_result(1)
print("   Status:", status2)
if status2 == "show_dialog" then
    print("   Next Dialog Type:", flow_result2.type)
    print("   Next Dialog Title:", flow_result2.title)
    if flow_result2.data and flow_result2.data.options then
        print("   Number of severity options:", #flow_result2.data.options)
        print("   First few options:", table.concat({flow_result2.data.options[1], flow_result2.data.options[2], flow_result2.data.options[3]}, ", "))
    end
elseif status2 == "error" then
    print("   ERROR:", flow_result2)
end
print()

-- Step 3: Simulate the immediate cancel (result = -1) that AIO sends
print("3. Simulating immediate cancel (result = -1) - this is the problem...")
local status3, flow_result3 = dialog_flow_manager:handle_dialog_result(-1)
print("   Status:", status3)
print("   Flow Result:", flow_result3)
print()

-- Step 4: Check final state
print("4. Final state check...")
local has_dialog = dialog_flow_manager:get_current_dialog() ~= nil
print("   Has active dialog:", has_dialog)
if has_dialog then
    local current = dialog_flow_manager:get_current_dialog()
    print("   Current dialog step:", current.step_name)
    print("   Current dialog type:", current.type)
end
print()

print("=== EXPECTED BEHAVIOR ===")
print("1. Start flow → show_dialog (symptom list)")
print("2. Select symptom (15) → show_dialog (severity dialog)")  
print("3. Cancel (-1) → continue (ignore due to list dialog quirk)")
print("4. Final state → severity dialog still active")
print()

print("=== ACTUAL BEHAVIOR ===")
print("1. Start flow →", status1)
print("2. Select symptom (1) →", status2)
print("3. Cancel (-1) →", status3)
print("4. Final state → has active dialog:", has_dialog)
print()

-- Test the ignore mechanism directly
print("=== TESTING IGNORE MECHANISM ===")
print("Starting fresh flow...")
dialog_flow_manager:reset()
dialog_flow_manager:start_flow("symptom")
dialog_flow_manager:handle_dialog_result(1)  -- This should set ignore_next_cancel = true

print("Checking internal state (if accessible)...")
-- Try to access internal state for debugging
local manager_state = dialog_flow_manager
if manager_state.ignore_next_cancel ~= nil then
    print("ignore_next_cancel flag:", manager_state.ignore_next_cancel)
else
    print("ignore_next_cancel flag: not accessible (private)")
end

print()
print("=== TEST COMPLETE ===")