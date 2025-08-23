#!/usr/bin/env lua

-- Test to verify if flow_complete is being returned and handled correctly
package.path = package.path .. ";../my/?.lua;../?.lua"

_G.files = { read = function(filename) return nil end }
_G.debug = { toast = function(self, message) print("DEBUG: " .. message) end }

local core = require("long_covid_core")
local dialog_manager = core.create_dialog_manager()
local dialog_flow_manager = core.create_dialog_flow_manager()

dialog_flow_manager:set_data_manager(dialog_manager)
dialog_flow_manager:set_daily_logs({})

-- Track what the widget's on_dialog_action would receive
local function simulate_on_dialog_action(result)
    print("=== SIMULATING on_dialog_action(" .. tostring(result) .. ") ===")
    
    if dialog_flow_manager:get_current_dialog() then
        local status, flow_result = dialog_flow_manager:handle_dialog_result(result)
        print("Status returned:", status)
        
        if status == "show_dialog" then
            print("Would call: show_aio_dialog()")
        elseif status == "flow_complete" then
            print("FLOW COMPLETE - Should call log_item:")
            print("  Category:", flow_result.category)
            print("  Item:", flow_result.item) 
            print("  Severity:", flow_result.metadata and flow_result.metadata.severity)
            print("  ** log_item should be called here **")
            return "logged"
        elseif status == "flow_cancelled" then
            print("Would call: render_widget()")
        elseif status == "continue" then
            print("Dialog system quirk - do nothing")
        elseif status == "error" then
            print("ERROR:", flow_result)
        end
    else
        print("No current dialog - would fall to legacy system")
    end
    
    return status
end

print("=== FULL SYMPTOM FLOW TEST ===")
print()

-- Step 1: Start flow
print("1. Start symptom flow...")
dialog_flow_manager:start_flow("symptom")

-- Step 2: Select symptom 
print("2. User selects Fatigue...")
local result2 = simulate_on_dialog_action(1)

-- Step 3: Handle spurious cancel (if applicable)
if result2 == "show_dialog" then
    print("3. Handle spurious cancel...")
    local result3 = simulate_on_dialog_action(-1)
    print("   Spurious cancel result:", result3)
end

-- Step 4: User selects severity
print("4. User selects severity 5...")
local result4 = simulate_on_dialog_action(5)
print("   Final result:", result4)

print()
print("=== DIAGNOSIS ===")
if result4 == "logged" then
    print("✅ Flow completes correctly - log_item SHOULD be called")
    print("❌ But it's not being called on device")
    print("🔍 Issue is likely:")
    print("   - AIO not calling on_dialog_action for severity selection")
    print("   - on_dialog_action function has error before log_item")
    print("   - log_item function has error and fails silently")
else
    print("❌ Flow doesn't complete - issue is in dialog flow logic")
    print("   Expected: logged")
    print("   Actual:", result4)
end