#!/usr/bin/env lua

-- Test the real user cancel flow to understand the re-showing behavior
package.path = package.path .. ";../my/?.lua;../?.lua"

_G.files = { read = function(filename) return nil end }
_G.debug = { toast = function(self, message) print("DEBUG: " .. message) end }

local core = require("long_covid_core")
local dialog_manager = core.create_dialog_manager()
local dialog_flow_manager = core.create_dialog_flow_manager()

dialog_flow_manager:set_data_manager(dialog_manager)
dialog_flow_manager:set_daily_logs({})

print("=== REAL USER CANCEL FLOW TEST ===")
print()

-- Step 1: Get to severity dialog
print("1. Start flow and get to severity dialog...")
dialog_flow_manager:start_flow("symptom")
print("   ignore_next_cancel after start:", dialog_flow_manager.ignore_next_cancel)

local status1, result1 = dialog_flow_manager:handle_dialog_result(1)  -- Select Fatigue
print("   Status after Fatigue selection:", status1)
print("   ignore_next_cancel after selection:", dialog_flow_manager.ignore_next_cancel)
print("   Current dialog type:", dialog_flow_manager:get_current_dialog().type)
print()

-- Step 2: Simulate the spurious cancel that comes right after selection
print("2. Handle the spurious cancel from list selection...")
local status2, result2 = dialog_flow_manager:handle_dialog_result(-1)  -- Spurious cancel
print("   Status after spurious cancel:", status2)
print("   ignore_next_cancel after spurious cancel:", dialog_flow_manager.ignore_next_cancel)
print("   Current dialog type:", dialog_flow_manager:get_current_dialog().type)
print()

-- Step 3: Now simulate REAL user cancel of severity dialog
print("3. User presses back to cancel severity dialog (REAL cancel)...")
local status3, result3 = dialog_flow_manager:handle_dialog_result(-1)  -- Real user cancel
print("   Status after real cancel:", status3)
print("   ignore_next_cancel after real cancel:", dialog_flow_manager.ignore_next_cancel)
if dialog_flow_manager:get_current_dialog() then
    print("   Current dialog type:", dialog_flow_manager:get_current_dialog().type)
else
    print("   No current dialog")
end
print()

-- Step 4: If we got show_dialog, that means list is re-shown, now test selection
if status3 == "show_dialog" then
    print("4. List dialog re-shown, user selects Brain fog...")
    local status4, result4 = dialog_flow_manager:handle_dialog_result(2)  -- Select Brain fog
    print("   Status after Brain fog selection:", status4)
    print("   ignore_next_cancel after Brain fog selection:", dialog_flow_manager.ignore_next_cancel)
    if dialog_flow_manager:get_current_dialog() then
        print("   Current dialog type:", dialog_flow_manager:get_current_dialog().type)
    end
    print()
    
    -- Step 5: Handle the spurious cancel that should come after Brain fog selection
    print("5. Handle spurious cancel after Brain fog selection...")
    local status5, result5 = dialog_flow_manager:handle_dialog_result(-1)  -- Spurious cancel
    print("   Status after spurious cancel:", status5)
    print("   Should be 'continue' to ignore it")
    print()
else
    print("4. SKIPPED - List dialog was not re-shown")
    print()
end

print("=== DIAGNOSIS ===")
print("The flow should be:")
print("1. Start → list (ignore=true)")
print("2. Select Fatigue → severity (spurious cancel ignored)")  
print("3. Real cancel → re-show list (ignore=true again)")
print("4. Select Brain fog → severity (spurious cancel should be ignored)")
print()
print("If step 5 shows 'continue', the fix is working.")
print("If step 5 shows anything else, there's still a bug.")