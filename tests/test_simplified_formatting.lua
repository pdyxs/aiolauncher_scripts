-- test_simplified_formatting.lua - Tests for Phase 3 simplified formatting

-- Add paths for imports
package.path = package.path .. ";../my/?.lua;./?.lua"

local test = require "test_framework"
local data = require "test_data"
local core = require "long_covid_core"

-- Test: Simplified formatting function - symptoms (no requirements)
test.add_test("Simplified formatting - symptoms have no requirements", function()
    local mock_date, original_date = data.mock_os_date("2023-08-30")
    os.date = mock_date
    
    local symptoms = {"Fatigue", "Brain fog", "Joint pain"}
    local daily_logs = {
        ["2023-08-30"] = {
            symptoms = {
                ["Fatigue"] = 2,
                ["Brain fog"] = 1
                -- Joint pain not logged
            }
        }
    }
    
    local result = core.format_list_items(symptoms, "symptom", daily_logs, nil)
    
    test.assert_equals(3, #result, "Should return 3 formatted items")
    test.assert_contains(result, "✓ Fatigue (2)", "Should show completed symptom with count")
    test.assert_contains(result, "✓ Brain fog (1)", "Should show completed symptom with count")
    test.assert_contains(result, "   Joint pain", "Should show unlogged symptom with spaces (no requirements)")
    
    os.date = original_date
end)

-- Test: Simplified formatting function - activities with requirements
test.add_test("Simplified formatting - activities with requirements", function()
    local mock_date, original_date = data.mock_os_date("2023-08-30")
    os.date = mock_date
    
    local activities = {"Work", "Exercise", "Reading"}
    local required_activities = {
        {name = "Work", required = true},
        {name = "Exercise", required = true}
        -- Reading is not required
    }
    local daily_logs = {
        ["2023-08-30"] = {
            activities = {
                ["Work"] = 1
                -- Exercise and Reading not logged
            }
        }
    }
    
    local result = core.format_list_items(activities, "activity", daily_logs, required_activities)
    
    test.assert_equals(3, #result, "Should return 3 formatted items")
    test.assert_contains(result, "✅ Work (1)", "Should show completed required activity with ✅")
    test.assert_contains(result, "⚠️ Exercise", "Should show missing required activity with ⚠️")
    test.assert_contains(result, "   Reading", "Should show non-required activity with spaces")
    
    os.date = original_date
end)

-- Test: Simplified formatting function - interventions with requirements
test.add_test("Simplified formatting - interventions with requirements", function()
    local mock_date, original_date = data.mock_os_date("2023-08-30")
    os.date = mock_date
    
    local interventions = {"LDN (4mg)", "Meditation", "Supplements"}
    local required_interventions = {
        {name = "LDN (4mg)", required = true},
        {name = "Supplements", weekly_required = true}
        -- Meditation is not required
    }
    local daily_logs = {
        ["2023-08-30"] = {
            interventions = {
                ["LDN (4mg)"] = 1,
                ["Meditation"] = 1
                -- Supplements not logged (and it's weekly required)
            }
        }
    }
    
    local result = core.format_list_items(interventions, "intervention", daily_logs, required_interventions)
    
    test.assert_equals(3, #result, "Should return 3 formatted items")
    test.assert_contains(result, "✅ LDN (4mg) (1)", "Should show completed required intervention with ✅")
    test.assert_contains(result, "✓ Meditation (1)", "Should show completed non-required intervention with ✓")
    test.assert_contains(result, "⚠️ Supplements", "Should show missing weekly required intervention with ⚠️")
    
    os.date = original_date
end)

-- Test: Simplified formatting handles option variants
test.add_test("Simplified formatting - handles option variants", function()
    local mock_date, original_date = data.mock_os_date("2023-08-30")
    os.date = mock_date
    
    local activities = {"Work", "Exercise"}
    local required_activities = {
        {name = "Work", required = true},
        {name = "Exercise", required = true}
    }
    local daily_logs = {
        ["2023-08-30"] = {
            activities = {
                ["Work: From Home"] = 1,  -- Option variant should count for "Work"
                ["Exercise: Light"] = 1   -- Option variant should count for "Exercise"
            }
        }
    }
    
    local result = core.format_list_items(activities, "activity", daily_logs, required_activities)
    
    test.assert_equals(2, #result, "Should return 2 formatted items")
    test.assert_contains(result, "✅ Work (1)", "Should count option variant for Work")
    test.assert_contains(result, "✅ Exercise (1)", "Should count option variant for Exercise")
    
    os.date = original_date
end)

-- Test: Simplified formatting handles multiple option variants
test.add_test("Simplified formatting - multiple option variants", function()
    local mock_date, original_date = data.mock_os_date("2023-08-30")
    os.date = mock_date
    
    local activities = {"Work"}
    local required_activities = {
        {name = "Work", required = true}
    }
    local daily_logs = {
        ["2023-08-30"] = {
            activities = {
                ["Work"] = 1,              -- Exact match
                ["Work: From Home"] = 2,   -- Option variant
                ["Work: In Office"] = 1    -- Another option variant
            }
        }
    }
    
    local result = core.format_list_items(activities, "activity", daily_logs, required_activities)
    
    test.assert_equals(1, #result, "Should return 1 formatted item")
    test.assert_contains(result, "✅ Work (4)", "Should sum all variants: 1 + 2 + 1 = 4")
    
    os.date = original_date
end)

-- Test: Configuration-driven behavior for unknown item types
test.add_test("Simplified formatting - unknown item type fallback", function()
    local items = {"Unknown1", "Unknown2"}
    local daily_logs = {}
    
    local result = core.format_list_items(items, "unknown_type", daily_logs, nil)
    
    -- Should return items as-is for unknown types
    test.assert_equals(items, result, "Should return original items for unknown type")
end)

-- Legacy compatibility tests removed - only one implementation now exists

-- Test: Configuration-driven design principles
test.add_test("Configuration-driven design - item type configurations", function()
    -- This test verifies the configuration mapping works correctly
    local mock_date, original_date = data.mock_os_date("2023-08-30")
    os.date = mock_date
    
    local daily_logs = {
        ["2023-08-30"] = {
            symptoms = {["Fatigue"] = 1},
            activities = {["Work"] = 1},
            interventions = {["LDN (4mg)"] = 1}
        }
    }
    
    -- Test symptom configuration (no requirements support)
    local symptom_result = core.format_list_items({"Fatigue"}, "symptom", daily_logs, {})
    test.assert_contains(symptom_result, "✓ Fatigue (1)", "Symptoms should use ✓ (never required)")
    
    -- Test activity configuration (requirements support)
    local required_activities = {{name = "Work", required = true}}
    local activity_result = core.format_list_items({"Work"}, "activity", daily_logs, required_activities)
    test.assert_contains(activity_result, "✅ Work (1)", "Required activities should use ✅")
    
    -- Test intervention configuration (requirements support)
    local required_interventions = {{name = "LDN (4mg)", required = true}}
    local intervention_result = core.format_list_items({"LDN (4mg)"}, "intervention", daily_logs, required_interventions)
    test.assert_contains(intervention_result, "✅ LDN (4mg) (1)", "Required interventions should use ✅")
    
    os.date = original_date
end)

-- Test: Simplified health tracking buttons
test.add_test("Simplified health tracking buttons - all completed", function()
    local mock_date, original_date = data.mock_os_date("2023-08-30")
    os.date = mock_date
    
    local required_items_config = {
        activities = {{name = "Work", required = true}},
        interventions = {{name = "LDN (4mg)", required = true}}
    }
    
    local daily_logs = {
        ["2023-08-30"] = {
            activities = {["Work"] = 1},
            interventions = {["LDN (4mg)"] = 1},
            energy_levels = {["8"] = 1}  -- High energy
        }
    }
    
    local ui_generator = core.create_ui_generator()
    local buttons = ui_generator:create_health_tracking_buttons(daily_logs, required_items_config)
    
    -- Find the activity and intervention buttons
    local activity_button = buttons[4] -- fa:running button
    local intervention_button = buttons[5] -- fa:pills button
    
    test.assert_equals("#28a745", activity_button[3].color, "Activities button should be green when completed")
    test.assert_equals("#007bff", intervention_button[3].color, "Interventions button should be blue when completed")
    
    os.date = original_date
end)

test.add_test("Simplified health tracking buttons - incomplete requirements", function()
    local mock_date, original_date = data.mock_os_date("2023-08-30")
    os.date = mock_date
    
    local required_items_config = {
        activities = {{name = "Work", required = true}, {name = "Exercise", required = true}},
        interventions = {{name = "LDN (4mg)", required = true}}
    }
    
    local daily_logs = {
        ["2023-08-30"] = {
            activities = {["Work"] = 1}, -- Exercise missing
            interventions = {} -- LDN missing
        }
    }
    
    local ui_generator = core.create_ui_generator()
    local buttons = ui_generator:create_health_tracking_buttons(daily_logs, required_items_config)
    
    local activity_button = buttons[4] 
    local intervention_button = buttons[5]
    
    test.assert_equals("#dc3545", activity_button[3].color, "Activities button should be red when incomplete")
    test.assert_equals("#dc3545", intervention_button[3].color, "Interventions button should be red when incomplete")
    
    os.date = original_date
end)

test.add_test("Simplified health tracking buttons - configuration driven", function()
    local ui_generator = core.create_ui_generator()
    local buttons = ui_generator:create_health_tracking_buttons({}, {})
    
    -- Should return 5 elements: heart-pulse, lightning, spacer, running, pills
    test.assert_equals(5, #buttons, "Should return 5 button elements")
    test.assert_equals("fa:heart-pulse", buttons[1][2], "First button should be heart-pulse")
    test.assert_equals("fa:bolt-lightning", buttons[2][2], "Second button should be lightning")
    test.assert_equals("spacer", buttons[3][1], "Third element should be spacer")
    test.assert_equals("fa:running", buttons[4][2], "Fourth button should be running")
    test.assert_equals("fa:pills", buttons[5][2], "Fifth button should be pills")
end)

-- Legacy compatibility tests for health tracking buttons removed - only one implementation now exists

-- Individual runner pattern
if ... == nil then
    test.run_tests("Simplified Formatting")
    local success = test.print_final_results()
    os.exit(success and 0 or 1)
end