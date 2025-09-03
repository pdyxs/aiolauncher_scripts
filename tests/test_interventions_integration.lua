-- test_interventions_integration.lua
-- Integration tests for Interventions Dialog Flow

-- Set path first
package.path = package.path .. ";../my/?.lua"

-- Mock AIO dependencies BEFORE loading core
files = {
    read = function(filename)
        if filename == "interventions.md" then
            return [[## Test Interventions

## Medications
- LDN (4mg) {Required}
- LDN (4.5mg)
- Claratyne

## Supplements
- Salvital {Options: Morning, Evening}

## Treatments
- Meditation
- Physio {Required: Mon,Wed,Fri}]]
        elseif filename == "activities.md" then
            return [[## Work
- Work]]
        end
        return nil
    end
}

prefs = {}
ui = { toast = function() end, show_text = function() end }
dialogs = {}
tasker = {}

-- Import core module AFTER setting up mocks
local core_module = "long_covid_core"
local core = require(core_module)

-- Import the test framework
local test = require "test_framework"
    
-- Test intervention flow initialization
test.add_test("Intervention flow initialization", function()
    local flow_manager = core.create_dialog_flow_manager()
    local data_manager = core.create_dialog_manager()
    
    flow_manager:set_data_manager(data_manager)
    flow_manager:set_daily_logs({["2025-01-21"] = {interventions = {}}})
    
    local status, data = flow_manager:start_flow("intervention")
    test.assert_equals("show_dialog", status, "Should return show_dialog status")
    test.assert_equals("radio", data.type, "Should be radio dialog")
    test.assert_equals("Log Intervention", data.title, "Should have correct title")
    test.assert_contains(data.data.options, "⚠️ LDN (4mg)", "Should contain LDN option with warning (required but not logged)")
    test.assert_contains(data.data.options, "   Salvital", "Should contain Salvital option")
    test.assert_contains(data.data.options, "   Other...", "Should contain Other option")
end)
    
-- Test intervention without options - direct completion  
test.add_test("Intervention without options - direct completion", function()
    local flow_manager = core.create_dialog_flow_manager()
    local data_manager = core.create_dialog_manager()
    
    flow_manager:set_data_manager(data_manager)
    flow_manager:set_daily_logs({["2025-01-21"] = {interventions = {}}})
    
    -- Start flow and select intervention
    flow_manager:start_flow("intervention")
    
    -- Simulate selecting "Meditation" (no options) - index 6 in fallback data
    local status, result = flow_manager:handle_dialog_result(6) -- Meditation is index 6
    test.assert_equals("flow_complete", status, "Should complete flow directly")
    test.assert_equals("intervention", result.category, "Should be intervention category")
    test.assert_equals("Meditation", result.item, "Should log correct item")
end)
    
-- Test intervention with options - two-step flow
test.add_test("Intervention with options - two-step flow", function()
    local flow_manager = core.create_dialog_flow_manager()
    local data_manager = core.create_dialog_manager()
    
    flow_manager:set_data_manager(data_manager)
    flow_manager:set_daily_logs({["2025-01-21"] = {interventions = {}}})
    
    -- Start flow and select "Salvital" (has options) - index 3 in fallback data
    flow_manager:start_flow("intervention")
    local status, data = flow_manager:handle_dialog_result(3) -- Salvital is index 3
    
    test.assert_equals("show_dialog", status, "Should show options dialog")
    test.assert_equals("Select Option", data.title, "Should have options dialog title")
    test.assert_contains(data.data.options, "Morning", "Should have Morning option")
    test.assert_contains(data.data.options, "Evening", "Should have Evening option")
    
    -- Select "Evening" option
    local final_status, result = flow_manager:handle_dialog_result(2) -- Evening
    test.assert_equals("flow_complete", final_status, "Should complete flow")
    test.assert_equals("intervention", result.category, "Should be intervention category")
    test.assert_equals("Salvital: Evening", result.item, "Should log combined item")
end)
    
-- Test custom intervention input
test.add_test("Custom intervention input flow", function()
    local flow_manager = core.create_dialog_flow_manager()
    local data_manager = core.create_dialog_manager()
    
    flow_manager:set_data_manager(data_manager)
    flow_manager:set_daily_logs({["2025-01-21"] = {interventions = {}}})
    
    -- Start flow and select "Other..." (index 7 in fallback data)
    flow_manager:start_flow("intervention")
    local status, data = flow_manager:handle_dialog_result(9) -- "Other..." is index 9
    
    test.assert_equals("show_dialog", status, "Should show custom input dialog")
    test.assert_equals("edit", data.type, "Should be edit dialog")
    test.assert_equals("Custom Intervention", data.title, "Should have custom input title")
    
    -- Enter custom intervention
    local final_status, result = flow_manager:handle_dialog_result("CBD Oil")
    test.assert_equals("flow_complete", final_status, "Should complete flow")
    test.assert_equals("intervention", result.category, "Should be intervention category")
    test.assert_equals("CBD Oil", result.item, "Should log custom item")
end)
    
-- Test options parsing functionality
test.add_test("Options parsing from interventions content", function()
    local interventions_content = files.read("interventions.md")
    
    -- Test Salvital options
    local salvital_options = core.parse_item_options(interventions_content, "Salvital")
    test.assert_equals(2, #salvital_options, "Salvital should have 2 options")
    test.assert_contains(salvital_options, "Morning", "Should contain Morning")
    test.assert_contains(salvital_options, "Evening", "Should contain Evening")
    
    -- Test intervention without options
    local meditation_options = core.parse_item_options(interventions_content, "Meditation")
    test.assert_equals(nil, meditation_options, "Meditation should have no options")
end)
    
-- Test empty custom input handling
test.add_test("Empty custom intervention input", function()
    local flow_manager = core.create_dialog_flow_manager()
    local data_manager = core.create_dialog_manager()
    
    flow_manager:set_data_manager(data_manager)
    flow_manager:set_daily_logs({["2025-01-21"] = {interventions = {}}})
    
    -- Start flow and select "Other..." (index 7) 
    flow_manager:start_flow("intervention")
    flow_manager:handle_dialog_result(9) -- "Other..." is index 9
    
    -- Enter empty text (should be handled like cancel - AIO quirk returns continue)
    local status = flow_manager:handle_dialog_result("")
    test.assert_equals("continue", status, "Empty input handled as cancel (AIO quirk)")
end)
    
-- Test intervention flow cancellation
test.add_test("Intervention flow cancellation", function()
    local flow_manager = core.create_dialog_flow_manager()
    local data_manager = core.create_dialog_manager()
    
    flow_manager:set_data_manager(data_manager)
    flow_manager:set_daily_logs({["2025-01-21"] = {interventions = {}}})
    
    -- Start flow and cancel (accounts for AIO dialog quirk)
    flow_manager:start_flow("intervention")
    local first_cancel = flow_manager:handle_cancel()
    test.assert_equals("continue", first_cancel, "First cancel should be ignored (AIO quirk)")
    
    -- Second cancel should actually cancel
    local second_cancel = flow_manager:handle_cancel()
    test.assert_equals("flow_cancelled", second_cancel, "Second cancel should cancel flow")
end)
    
-- Individual runner pattern
if ... == nil then
    test.run_tests("Interventions Dialog Flow Integration")
    local success = test.print_final_results()
    os.exit(success and 0 or 1)
end