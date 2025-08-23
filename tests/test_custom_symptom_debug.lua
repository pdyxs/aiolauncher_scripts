#!/usr/bin/env lua

-- Test harness to debug custom symptom input flow
-- Should test: List → "Other..." → Custom Input → Severity → Complete

package.path = package.path .. ";../my/?.lua;../?.lua"

-- Mock AIO environment
local mock_files = {
    ["symptoms.md"] = [[
# Symptoms
## Physical
- Fatigue
- Brain fog
- Headache
- Other...
]]
}

_G.files = {
    read = function(filename) return mock_files[filename] end
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

print("=== CUSTOM SYMPTOM FLOW DEBUG ===")
print()

-- Step 1: Start the symptom flow
print("1. Starting symptom flow...")
local status1, dialog_config1 = dialog_flow_manager:start_flow("symptom")
print("   Status:", status1)
print("   Dialog Type:", dialog_config1.type)
print("   Items available:", #dialog_config1.data.items)
-- Find "Other..." in the list
local other_index = nil
for i, item in ipairs(dialog_config1.data.items) do
    print("   [" .. i .. "]", item)
    if item:find("Other%.%.%.") then
        other_index = i
    end
end
print("   'Other...' found at index:", other_index)
print()

-- Step 2: Select "Other..." from the list
print("2. Selecting 'Other...' (index " .. other_index .. ")...")
local status2, flow_result2 = dialog_flow_manager:handle_dialog_result(other_index)
print("   Status:", status2)
if status2 == "show_dialog" then
    print("   Next Dialog Type:", flow_result2.type)
    print("   Next Dialog Title:", flow_result2.title)
    if flow_result2.data then
        print("   Dialog Prompt:", flow_result2.data.prompt or "none")
        print("   Default Text:", flow_result2.data.default_text or "none")
    end
elseif status2 == "error" then
    print("   ERROR:", flow_result2)
end
print()

-- Step 3: Enter custom symptom name
print("3. Entering custom symptom 'My Test Symptom'...")
local status3, flow_result3 = dialog_flow_manager:handle_dialog_result("My Test Symptom")
print("   Status:", status3)
if status3 == "show_dialog" then
    print("   Next Dialog Type:", flow_result3.type)
    print("   Next Dialog Title:", flow_result3.title)
    if flow_result3.data and flow_result3.data.options then
        print("   Severity options available:", #flow_result3.data.options)
        print("   First few:", table.concat({flow_result3.data.options[1], flow_result3.data.options[2], flow_result3.data.options[3]}, ", "))
    end
elseif status3 == "error" then
    print("   ERROR:", flow_result3)
elseif status3 == "flow_complete" then
    print("   UNEXPECTED: Flow completed without severity selection!")
    print("   Result:", flow_result3)
end
print()

-- Step 4: Select severity (if we got that far)
if status3 == "show_dialog" then
    print("4. Selecting severity level 7...")
    local status4, flow_result4 = dialog_flow_manager:handle_dialog_result(7)
    print("   Status:", status4)
    if status4 == "flow_complete" then
        print("   Item logged:", flow_result4.item)
        print("   Severity:", flow_result4.metadata and flow_result4.metadata.severity)
    elseif status4 == "error" then
        print("   ERROR:", flow_result4)
    end
    print()
else
    print("4. SKIPPED - Severity dialog never appeared")
    print()
end

-- Check final state
print("5. Final state check...")
local has_dialog = dialog_flow_manager:get_current_dialog() ~= nil
print("   Has active dialog:", has_dialog)
print()

print("=== EXPECTED FLOW ===")
print("1. Start → show_dialog (symptom list)")
print("2. Select 'Other...' → show_dialog (custom input)")  
print("3. Enter custom text → show_dialog (severity)")
print("4. Select severity → flow_complete (logged with severity)")
print()

print("=== ACTUAL RESULTS ===")
print("1. Start →", status1)
print("2. Select 'Other...' →", status2)
print("3. Enter custom text →", status3)
if status3 == "show_dialog" then
    print("4. Select severity →", status4 or "not reached")
end
print()