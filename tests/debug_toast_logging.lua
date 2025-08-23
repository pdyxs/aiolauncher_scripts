-- Debug script to test the exact Test 1.3 scenario
-- Focus: Why no toast confirmation and logging after severity selection

package.path = package.path .. ";../my/?.lua;../?.lua"

-- Mock comprehensive AIO environment for Test 1.3
_G.files = { read = function(filename) return nil end }
_G.debug = { toast = function(self, message) print("DEBUG: " .. message) end }

-- Mock UI and Tasker to isolate logging issues
local toast_calls = {}
local tasker_calls = {}
local logged_items = {}

_G.ui = {
    show_toast = function(message) 
        table.insert(toast_calls, message)
        print("UI TOAST TYPE: " .. type(message))
        print("UI TOAST VALUE: " .. tostring(message))
        if type(message) == "string" then
            print("UI TOAST: " .. message)
        else
            print("ERROR: message is not a string!")
        end
    end
}

_G.tasker = {
    run_task = function(self, task_name, params)
        table.insert(tasker_calls, {task = task_name, params = params})
        print("TASKER CALL: " .. task_name .. " with " .. tostring(params.value))
    end
}

-- Load the core module and simulate widget environment
local core = require("long_covid_core")
local dialog_manager = core.create_dialog_manager()  
local dialog_flow_manager = core.create_dialog_flow_manager()

dialog_flow_manager:set_data_manager(dialog_manager)
dialog_flow_manager:set_daily_logs({})

-- Simulate the log_item function from the widget
local function log_item(item_type, item_value, metadata)
    print("LOG_ITEM CALLED: type=" .. item_type .. " value=" .. item_value)
    
    local tasker_callback = function(params)
        if tasker then
            tasker:run_task("LongCovid_LogEvent", params)
        end
    end
    
    local ui_callback = function(message)
        ui:show_toast(message)
    end
    
    -- Add to our tracking
    table.insert(logged_items, {type = item_type, value = item_value, metadata = metadata})
    
    local success = core.log_item_with_tasker({}, item_type, item_value, tasker_callback, ui_callback)
    print("LOG_ITEM SUCCESS: " .. tostring(success))
    return success
end

print("=== TEST 1.3 SIMULATION: Basic Symptoms Flow ===")
print()

-- Step 1: Start symptom flow  
print("1. Start symptom flow...")
local status1, config1 = dialog_flow_manager:start_flow("symptom")
print("   Status:", status1)
print()

-- Step 2: Select Fatigue (symptom 1)
print("2. Select 'Fatigue' from list...")
local status2, config2 = dialog_flow_manager:handle_dialog_result(1)
print("   Status:", status2)
print("   Next dialog type:", config2 and config2.type or "none")
print()

-- Step 3: Handle spurious cancel (should be ignored)
print("3. Handle spurious cancel after symptom selection...")
local status3, config3 = dialog_flow_manager:handle_dialog_result(-1)
print("   Status:", status3, "(should be 'continue')")
print()

-- Step 4: Select severity level 5
print("4. Select severity level 5...")
local status4, result4 = dialog_flow_manager:handle_dialog_result(5)
print("   Status:", status4)
if status4 == "flow_complete" then
    print("   Item:", result4.item)
    print("   Severity:", result4.metadata and result4.metadata.severity)
    print()
    
    -- Step 5: Call log_item (this is where the problem might be)
    print("5. Calling log_item function...")
    local success, error_msg = pcall(function()
        log_item(result4.category, result4.item, result4.metadata)
    end)
    
    if not success then
        print("   ERROR in log_item function: " .. tostring(error_msg))
    else
        print("   log_item completed successfully")
    end
else
    print("   ERROR: Expected flow_complete, got:", status4)
end

print()
print("=== RESULTS SUMMARY ===")
print("Toast calls:", #toast_calls)
for i, toast in ipairs(toast_calls) do
    print("  " .. i .. ": " .. tostring(toast))
end
print("Tasker calls:", #tasker_calls)  
for i, call in ipairs(tasker_calls) do
    print("  " .. i .. ": " .. call.task .. " -> " .. (call.params.value or "no value"))
end
print("Logged items:", #logged_items)
for i, item in ipairs(logged_items) do
    print("  " .. i .. ": " .. item.type .. " = " .. item.value)
end

print()
print("=== DIAGNOSTIC QUESTIONS ===")
print("1. Does flow complete successfully?", status4 == "flow_complete")
print("2. Does log_item get called without errors?", #logged_items > 0)
print("3. Are toast messages generated?", #toast_calls > 0)
print("4. Are Tasker calls made?", #tasker_calls > 0)
print()
print("If any of these are 'false', that's where the bug is.")