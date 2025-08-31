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

-- Test suite
local function run_interventions_integration_tests()
    print("Running Interventions Dialog Flow Integration Tests...")
    print("============================================================")
    
    local tests_passed = 0
    local tests_total = 0
    
    local function test(name, test_func)
        tests_total = tests_total + 1
        local success, error_msg = pcall(test_func)
        if success then
            print("✓ " .. name)
            tests_passed = tests_passed + 1
        else
            print("✗ " .. name .. " - " .. tostring(error_msg))
        end
    end
    
    local function assert_equals(actual, expected, message)
        if actual ~= expected then
            error(message .. " - Expected: " .. tostring(expected) .. ", Got: " .. tostring(actual))
        end
    end
    
    local function assert_contains(table_or_string, value, message)
        if type(table_or_string) == "table" then
            for _, v in ipairs(table_or_string) do
                if v == value then return end
            end
            error(message .. " - Table does not contain: " .. tostring(value))
        else
            if not string.find(table_or_string, value, 1, true) then
                error(message .. " - String does not contain: " .. tostring(value))
            end
        end
    end
    
    -- Test intervention flow initialization
    test("Intervention flow initialization", function()
        local flow_manager = core.create_dialog_flow_manager()
        local data_manager = core.create_dialog_manager()
        
        flow_manager:set_data_manager(data_manager)
        flow_manager:set_daily_logs({["2025-01-21"] = {interventions = {}}})
        
        local status, data = flow_manager:start_flow("intervention")
        assert_equals(status, "show_dialog", "Should return show_dialog status")
        assert_equals(data.type, "radio", "Should be radio dialog")
        assert_equals(data.title, "Log Intervention", "Should have correct title")
        assert_contains(data.data.options, "   LDN (4mg)", "Should contain LDN option")
        assert_contains(data.data.options, "   Salvital", "Should contain Salvital option")
        assert_contains(data.data.options, "   Other...", "Should contain Other option")
    end)
    
    -- Test intervention without options - direct completion  
    test("Intervention without options - direct completion", function()
        local flow_manager = core.create_dialog_flow_manager()
        local data_manager = core.create_dialog_manager()
        
        flow_manager:set_data_manager(data_manager)
        flow_manager:set_daily_logs({["2025-01-21"] = {interventions = {}}})
        
        -- Start flow and select intervention
        flow_manager:start_flow("intervention")
        
        -- Simulate selecting "Meditation" (no options) - index 6 in fallback data
        local status, result = flow_manager:handle_dialog_result(6) -- Meditation is index 6
        assert_equals(status, "flow_complete", "Should complete flow directly")
        assert_equals(result.category, "intervention", "Should be intervention category")
        assert_equals(result.item, "Meditation", "Should log correct item")
    end)
    
    -- Test intervention with options - two-step flow
    test("Intervention with options - two-step flow", function()
        local flow_manager = core.create_dialog_flow_manager()
        local data_manager = core.create_dialog_manager()
        
        flow_manager:set_data_manager(data_manager)
        flow_manager:set_daily_logs({["2025-01-21"] = {interventions = {}}})
        
        -- Start flow and select "Salvital" (has options) - index 3 in fallback data
        flow_manager:start_flow("intervention")
        local status, data = flow_manager:handle_dialog_result(3) -- Salvital is index 3
        
        assert_equals(status, "show_dialog", "Should show options dialog")
        assert_equals(data.title, "Select Option", "Should have options dialog title")
        assert_contains(data.data.options, "Morning", "Should have Morning option")
        assert_contains(data.data.options, "Evening", "Should have Evening option")
        
        -- Select "Evening" option
        local final_status, result = flow_manager:handle_dialog_result(2) -- Evening
        assert_equals(final_status, "flow_complete", "Should complete flow")
        assert_equals(result.category, "intervention", "Should be intervention category")
        assert_equals(result.item, "Salvital: Evening", "Should log combined item")
    end)
    
    -- Test custom intervention input
    test("Custom intervention input flow", function()
        local flow_manager = core.create_dialog_flow_manager()
        local data_manager = core.create_dialog_manager()
        
        flow_manager:set_data_manager(data_manager)
        flow_manager:set_daily_logs({["2025-01-21"] = {interventions = {}}})
        
        -- Start flow and select "Other..." (index 7 in fallback data)
        flow_manager:start_flow("intervention")
        local status, data = flow_manager:handle_dialog_result(9) -- "Other..." is index 9
        
        assert_equals(status, "show_dialog", "Should show custom input dialog")
        assert_equals(data.type, "edit", "Should be edit dialog")
        assert_equals(data.title, "Custom Intervention", "Should have custom input title")
        
        -- Enter custom intervention
        local final_status, result = flow_manager:handle_dialog_result("CBD Oil")
        assert_equals(final_status, "flow_complete", "Should complete flow")
        assert_equals(result.category, "intervention", "Should be intervention category")
        assert_equals(result.item, "CBD Oil", "Should log custom item")
    end)
    
    -- Test options parsing functionality
    test("Options parsing from interventions content", function()
        local interventions_content = files.read("interventions.md")
        
        -- Test Salvital options
        local salvital_options = core.parse_item_options(interventions_content, "Salvital")
        assert_equals(#salvital_options, 2, "Salvital should have 2 options")
        assert_contains(salvital_options, "Morning", "Should contain Morning")
        assert_contains(salvital_options, "Evening", "Should contain Evening")
        
        -- Test intervention without options
        local meditation_options = core.parse_item_options(interventions_content, "Meditation")
        assert_equals(meditation_options, nil, "Meditation should have no options")
    end)
    
    -- Test empty custom input handling
    test("Empty custom intervention input", function()
        local flow_manager = core.create_dialog_flow_manager()
        local data_manager = core.create_dialog_manager()
        
        flow_manager:set_data_manager(data_manager)
        flow_manager:set_daily_logs({["2025-01-21"] = {interventions = {}}})
        
        -- Start flow and select "Other..." (index 7) 
        flow_manager:start_flow("intervention")
        flow_manager:handle_dialog_result(9) -- "Other..." is index 9
        
        -- Enter empty text (should be handled like cancel - AIO quirk returns continue)
        local status = flow_manager:handle_dialog_result("")
        assert_equals(status, "continue", "Empty input handled as cancel (AIO quirk)")
    end)
    
    -- Test intervention flow cancellation
    test("Intervention flow cancellation", function()
        local flow_manager = core.create_dialog_flow_manager()
        local data_manager = core.create_dialog_manager()
        
        flow_manager:set_data_manager(data_manager)
        flow_manager:set_daily_logs({["2025-01-21"] = {interventions = {}}})
        
        -- Start flow and cancel (accounts for AIO dialog quirk)
        flow_manager:start_flow("intervention")
        local first_cancel = flow_manager:handle_cancel()
        assert_equals(first_cancel, "continue", "First cancel should be ignored (AIO quirk)")
        
        -- Second cancel should actually cancel
        local second_cancel = flow_manager:handle_cancel()
        assert_equals(second_cancel, "flow_cancelled", "Second cancel should cancel flow")
    end)
    
    print("Suite Results: " .. tests_passed .. "/" .. tests_total .. " tests passed")
    
    if tests_passed == tests_total then
        print("\nInterventions dialog flow integration is working correctly!")
        print("The new dialog stack system is ready for interventions.")
        return true
    else
        print("\n" .. (tests_total - tests_passed) .. " test(s) failed!")
        return false
    end
end

-- Run tests if called directly
if not TEST_RUNNER then
    run_interventions_integration_tests()
else
    return {
        name = "Interventions Integration", 
        run = run_interventions_integration_tests
    }
end