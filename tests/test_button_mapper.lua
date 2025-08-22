-- test_button_mapper.lua - Tests for button mapper functionality
-- Tests button action identification and level selection validation

-- Add paths for imports
package.path = package.path .. ";../my/?.lua;./?.lua"

local test = require "test_framework"
local data = require "test_data"
local core = require "long_covid_core"

test.add_test("Button mapper creation", function()
    local button_mapper = core.create_button_mapper()
    
    test.assert_type("table", button_mapper, "Should return table")
    test.assert_type("function", button_mapper.identify_button_action, "Should have identify_button_action method")
    test.assert_type("function", button_mapper.can_select_level, "Should have can_select_level method")
end)

test.add_test("Capacity level button identification - icon only", function()
    local button_mapper = core.create_button_mapper()
    
    -- Test bed icon (level 1)
    local action_type, level = button_mapper:identify_button_action("fa:bed")
    test.assert_equals("capacity_level", action_type, "Should identify bed as capacity level")
    test.assert_equals(1, level, "Should identify level 1")
    
    -- Test walking icon (level 2) 
    action_type, level = button_mapper:identify_button_action("fa:walking")
    test.assert_equals("capacity_level", action_type, "Should identify walking as capacity level")
    test.assert_equals(2, level, "Should identify level 2")
    
    -- Test rocket-launch icon (level 3)
    action_type, level = button_mapper:identify_button_action("fa:rocket-launch")
    test.assert_equals("capacity_level", action_type, "Should identify rocket-launch as capacity level")
    test.assert_equals(3, level, "Should identify level 3")
end)

test.add_test("Capacity level button identification - with text", function()
    local button_mapper = core.create_button_mapper()
    
    -- Test with FontAwesome formatting and text
    local action_type, level = button_mapper:identify_button_action("%%fa:bed%% Recovering")
    test.assert_equals("capacity_level", action_type, "Should identify bed with text")
    test.assert_equals(1, level, "Should identify level 1")
    
    action_type, level = button_mapper:identify_button_action("%%fa:walking%% Maintaining")
    test.assert_equals("capacity_level", action_type, "Should identify walking with text")
    test.assert_equals(2, level, "Should identify level 2")
    
    action_type, level = button_mapper:identify_button_action("%%fa:rocket-launch%% Engaging")
    test.assert_equals("capacity_level", action_type, "Should identify rocket-launch with text")
    test.assert_equals(3, level, "Should identify level 3")
end)

test.add_test("Reset button identification", function()
    local button_mapper = core.create_button_mapper()
    
    -- Test various reset button formats
    local action_type = button_mapper:identify_button_action("fa:rotate-right")
    test.assert_equals("reset", action_type, "Should identify rotate-right icon as reset")
    
    action_type = button_mapper:identify_button_action("%%fa:rotate-right%% Reset")
    test.assert_equals("reset", action_type, "Should identify reset with text")
    
    action_type = button_mapper:identify_button_action("Reset")
    test.assert_equals("reset", action_type, "Should identify Reset text")
end)

test.add_test("Sync button identification", function()
    local button_mapper = core.create_button_mapper()
    
    local action_type = button_mapper:identify_button_action("fa:sync")
    test.assert_equals("sync", action_type, "Should identify sync icon")
    
    action_type = button_mapper:identify_button_action("%%fa:sync%% Sync Files")
    test.assert_equals("sync", action_type, "Should identify sync with text")
end)

test.add_test("Health tracking button identification", function()
    local button_mapper = core.create_button_mapper()
    
    -- Symptom dialog button
    local action_type = button_mapper:identify_button_action("fa:heart-pulse")
    test.assert_equals("symptom_dialog", action_type, "Should identify heart-pulse as symptom dialog")
    
    -- Energy dialog button
    action_type = button_mapper:identify_button_action("fa:bolt-lightning")
    test.assert_equals("energy_dialog", action_type, "Should identify bolt-lightning as energy dialog")
    
    -- Activity dialog button
    action_type = button_mapper:identify_button_action("fa:running")
    test.assert_equals("activity_dialog", action_type, "Should identify running as activity dialog")
    
    -- Intervention dialog button
    action_type = button_mapper:identify_button_action("fa:pills")
    test.assert_equals("intervention_dialog", action_type, "Should identify pills as intervention dialog")
end)

test.add_test("Back button identification", function()
    local button_mapper = core.create_button_mapper()
    
    local action_type = button_mapper:identify_button_action("Back")
    test.assert_equals("back", action_type, "Should identify Back text")
end)

test.add_test("Unknown button identification", function()
    local button_mapper = core.create_button_mapper()
    
    local action_type = button_mapper:identify_button_action("Unknown Button")
    test.assert_equals("unknown", action_type, "Should identify unknown buttons")
    
    action_type = button_mapper:identify_button_action("fa:random-icon")
    test.assert_equals("unknown", action_type, "Should identify unknown icons")
    
    action_type = button_mapper:identify_button_action("")
    test.assert_equals("unknown", action_type, "Should handle empty strings")
end)

test.add_test("Level selection validation - from unselected state", function()
    local button_mapper = core.create_button_mapper()
    
    -- From level 0 (no selection), any level should be allowed
    test.assert_true(button_mapper:can_select_level(0, 1), "Should allow level 1 from unselected")
    test.assert_true(button_mapper:can_select_level(0, 2), "Should allow level 2 from unselected")
    test.assert_true(button_mapper:can_select_level(0, 3), "Should allow level 3 from unselected")
end)

test.add_test("Level selection validation - downgrade allowed", function()
    local button_mapper = core.create_button_mapper()
    
    -- From level 3, should allow downgrade to 2 or 1
    test.assert_true(button_mapper:can_select_level(3, 3), "Should allow same level")
    test.assert_true(button_mapper:can_select_level(3, 2), "Should allow downgrade from 3 to 2")
    test.assert_true(button_mapper:can_select_level(3, 1), "Should allow downgrade from 3 to 1")
    
    -- From level 2, should allow downgrade to 1
    test.assert_true(button_mapper:can_select_level(2, 2), "Should allow same level")
    test.assert_true(button_mapper:can_select_level(2, 1), "Should allow downgrade from 2 to 1")
end)

test.add_test("Level selection validation - upgrade prevented", function()
    local button_mapper = core.create_button_mapper()
    
    -- From level 1, should not allow upgrade
    test.assert_true(button_mapper:can_select_level(1, 1), "Should allow same level")
    test.assert_false(button_mapper:can_select_level(1, 2), "Should not allow upgrade from 1 to 2")
    test.assert_false(button_mapper:can_select_level(1, 3), "Should not allow upgrade from 1 to 3")
    
    -- From level 2, should not allow upgrade to 3
    test.assert_false(button_mapper:can_select_level(2, 3), "Should not allow upgrade from 2 to 3")
end)

test.add_test("Case sensitivity in button identification", function()
    local button_mapper = core.create_button_mapper()
    
    -- Test that matching is case-sensitive for exact text
    local action_type = button_mapper:identify_button_action("back")
    test.assert_equals("unknown", action_type, "Should be case-sensitive for 'back' vs 'Back'")
    
    action_type = button_mapper:identify_button_action("BACK")
    test.assert_equals("unknown", action_type, "Should be case-sensitive for 'BACK' vs 'Back'")
    
    action_type = button_mapper:identify_button_action("reset")
    test.assert_equals("unknown", action_type, "Should be case-sensitive for 'reset' vs 'Reset'")
end)

test.add_test("Complex button text with icons", function()
    local button_mapper = core.create_button_mapper()
    
    -- Test buttons with complex text that still contain identifying patterns
    local action_type, level = button_mapper:identify_button_action("Some text fa:bed more text")
    test.assert_equals("capacity_level", action_type, "Should find bed pattern in complex text")
    test.assert_equals(1, level, "Should identify correct level")
    
    action_type = button_mapper:identify_button_action("Click to fa:sync now")
    test.assert_equals("sync", action_type, "Should find sync pattern in complex text")
    
    action_type = button_mapper:identify_button_action("Health fa:heart-pulse tracking")
    test.assert_equals("symptom_dialog", action_type, "Should find heart-pulse in complex text")
end)

test.add_test("Special character handling in patterns", function()
    local button_mapper = core.create_button_mapper()
    
    -- Test that the rocket-launch pattern handles the hyphen correctly
    local action_type, level = button_mapper:identify_button_action("fa:rocket-launch")
    test.assert_equals("capacity_level", action_type, "Should handle hyphen in rocket-launch")
    test.assert_equals(3, level, "Should identify level 3")
    
    -- Test that the rotate-right pattern handles the hyphen correctly  
    action_type = button_mapper:identify_button_action("fa:rotate-right")
    test.assert_equals("reset", action_type, "Should handle hyphen in rotate-right")
    
    -- Test that bolt-lightning handles hyphen correctly
    action_type = button_mapper:identify_button_action("fa:bolt-lightning")  
    test.assert_equals("energy_dialog", action_type, "Should handle hyphen in bolt-lightning")
    
    -- Test that heart-pulse handles hyphen correctly
    action_type = button_mapper:identify_button_action("fa:heart-pulse")
    test.assert_equals("symptom_dialog", action_type, "Should handle hyphen in heart-pulse")
end)

test.add_test("Edge cases in level validation", function()
    local button_mapper = core.create_button_mapper()
    
    -- Test edge cases with invalid levels
    test.assert_true(button_mapper:can_select_level(0, 0), "Should handle level 0 to 0")
    test.assert_true(button_mapper:can_select_level(1, 0), "Should handle downgrade to 0")
    test.assert_true(button_mapper:can_select_level(3, 0), "Should handle any level to 0")
    
    -- Test with levels outside normal range (should still follow the rule)
    test.assert_true(button_mapper:can_select_level(5, 3), "Should allow downgrade from high level")
    test.assert_false(button_mapper:can_select_level(1, 5), "Should prevent upgrade to high level")
end)

test.add_test("Button action consistency", function()
    local button_mapper = core.create_button_mapper()
    
    -- Test that the same button text always returns the same action
    for i = 1, 5 do
        local action_type, level = button_mapper:identify_button_action("fa:walking")
        test.assert_equals("capacity_level", action_type, "Should consistently identify walking")
        test.assert_equals(2, level, "Should consistently return level 2")
    end
    
    for i = 1, 5 do
        local action_type = button_mapper:identify_button_action("fa:sync")
        test.assert_equals("sync", action_type, "Should consistently identify sync")
    end
end)

test.add_test("All capacity levels covered", function()
    local button_mapper = core.create_button_mapper()
    
    -- Ensure all three levels are properly mapped
    local levels_found = {}
    
    local action_type, level = button_mapper:identify_button_action("fa:bed")
    if action_type == "capacity_level" then levels_found[level] = true end
    
    action_type, level = button_mapper:identify_button_action("fa:walking")
    if action_type == "capacity_level" then levels_found[level] = true end
    
    action_type, level = button_mapper:identify_button_action("fa:rocket-launch")
    if action_type == "capacity_level" then levels_found[level] = true end
    
    test.assert_true(levels_found[1], "Should map level 1")
    test.assert_true(levels_found[2], "Should map level 2") 
    test.assert_true(levels_found[3], "Should map level 3")
    test.assert_equals(3, table.getn and table.getn(levels_found) or #levels_found, "Should map exactly 3 levels")
end)

-- This file can be run standalone or included by main test runner
if ... == nil then
    test.run_tests("Button Mapper")
    local success = test.print_final_results()
    os.exit(success and 0 or 1)
end