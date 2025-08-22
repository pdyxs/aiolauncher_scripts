-- test_ui_generator.lua - Tests for UI generator functionality  
-- Tests UI element generation for different widget states

-- Add paths for imports
package.path = package.path .. ";../my/?.lua;./?.lua"

local test = require "test_framework"
local data = require "test_data"
local core = require "long_covid_core"

test.add_test("UI generator creation", function()
    local ui_generator = core.create_ui_generator()
    
    test.assert_type("table", ui_generator, "Should return table")
    test.assert_type("function", ui_generator.create_capacity_buttons, "Should have create_capacity_buttons method")
    test.assert_type("function", ui_generator.create_health_tracking_buttons, "Should have create_health_tracking_buttons method")
    test.assert_type("function", ui_generator.create_no_selection_content, "Should have create_no_selection_content method")
    test.assert_type("function", ui_generator.create_plan_details, "Should have create_plan_details method")
    test.assert_type("function", ui_generator.create_error_content, "Should have create_error_content method")
    test.assert_type("function", ui_generator.create_decision_criteria_ui, "Should have create_decision_criteria_ui method")
end)

test.add_test("Capacity buttons - no selection state", function()
    local ui_generator = core.create_ui_generator()
    
    local elements = ui_generator:create_capacity_buttons(0)
    
    test.assert_type("table", elements, "Should return table")
    test.assert_true(#elements > 0, "Should have elements")
    
    -- Count buttons and check their format
    local button_count = 0
    local spacer_count = 0
    local new_line_count = 0
    
    for _, element in ipairs(elements) do
        if element[1] == "button" then
            button_count = button_count + 1
            -- All buttons should have full icon+text format when no selection
            test.assert_true(element[2]:find("%%fa:"), "Button should have full icon+text format: " .. element[2])
            test.assert_true(element[2]:find("%%"), "Button should have closing %% marker: " .. element[2])
        elseif element[1] == "spacer" then
            spacer_count = spacer_count + 1
        elseif element[1] == "new_line" then
            new_line_count = new_line_count + 1
        end
    end
    
    test.assert_equals(3, button_count, "Should have 3 capacity buttons")
    test.assert_equals(2, spacer_count, "Should have 2 spacers between buttons")
    test.assert_equals(1, new_line_count, "Should have 1 new line at end")
end)

test.add_test("Capacity buttons - level 2 selected", function()
    local ui_generator = core.create_ui_generator()
    
    local elements = ui_generator:create_capacity_buttons(2)
    
    local selected_found = false
    local icon_only_found = false
    local button_count = 0
    
    for _, element in ipairs(elements) do
        if element[1] == "button" then
            button_count = button_count + 1
            
            if element[2]:find("Maintaining") then
                selected_found = true
                test.assert_true(element[2]:find("%%fa:walking%%"), "Selected button should have full format")
                test.assert_equals("#FFAA00", element[3].color, "Selected button should have correct color")
            elseif element[2] == "fa:bed" then
                icon_only_found = true
                test.assert_equals("#888888", element[3].color, "Non-selected button should be grayed out")
            end
        end
    end
    
    test.assert_equals(3, button_count, "Should have 3 buttons")
    test.assert_true(selected_found, "Should find selected button with full text")
    test.assert_true(icon_only_found, "Should find non-selected button as icon-only")
end)

test.add_test("Capacity buttons - gravity settings", function()
    local ui_generator = core.create_ui_generator()
    
    local elements = ui_generator:create_capacity_buttons(0)
    
    local button_elements = {}
    for _, element in ipairs(elements) do
        if element[1] == "button" then
            table.insert(button_elements, element)
        end
    end
    
    test.assert_equals(3, #button_elements, "Should have 3 buttons")
    
    -- First button should have center_h gravity
    test.assert_equals("center_h", button_elements[1][3].gravity, "First button should have center_h gravity")
    
    -- Other buttons should have anchor_prev gravity
    test.assert_equals("anchor_prev", button_elements[2][3].gravity, "Second button should have anchor_prev gravity")
    test.assert_equals("anchor_prev", button_elements[3][3].gravity, "Third button should have anchor_prev gravity")
end)

test.add_test("Health tracking buttons - all requirements met", function()
    local ui_generator = core.create_ui_generator()
    
    -- Create daily logs with completed activities and interventions
    local mock_date, original_date = data.mock_os_date("2023-01-01")
    os.date = mock_date
    
    local daily_logs = {
        ["2023-01-01"] = {
            activities = {["Physio (full)"] = 1, ["Yin Yoga"] = 1},
            interventions = {["LDN (4mg)"] = 1, ["Salvital"] = 1},
            energy_levels = {{level = 7, timestamp = os.time() - 1800, time_display = "10:30"}} -- Recent
        }
    }
    
    local required_activities = data.create_sample_required_activities()
    local required_interventions = data.create_sample_required_interventions()
    
    local elements = ui_generator:create_health_tracking_buttons(daily_logs, required_activities, required_interventions)
    
    os.date = original_date
    
    test.assert_type("table", elements, "Should return table")
    test.assert_equals(5, #elements, "Should have 5 elements (4 buttons + 1 spacer)")
    
    -- Check button order and colors
    test.assert_equals("button", elements[1][1], "First should be button")
    test.assert_equals("fa:heart-pulse", elements[1][2], "First should be symptom button")
    test.assert_equals("#6c757d", elements[1][3].color, "Symptom button should be gray")
    
    test.assert_equals("fa:bolt-lightning", elements[2][2], "Second should be energy button")
    test.assert_equals("#28a745", elements[2][3].color, "Energy button should be green (recent log)")
    
    test.assert_equals("spacer", elements[3][1], "Third should be spacer")
    test.assert_equals(3, elements[3][2], "Spacer should be size 3")
    
    test.assert_equals("fa:running", elements[4][2], "Fourth should be activity button")
    test.assert_equals("#28a745", elements[4][3].color, "Activity button should be green (completed)")
    
    test.assert_equals("fa:pills", elements[5][2], "Fifth should be intervention button")  
    test.assert_equals("#007bff", elements[5][3].color, "Intervention button should be blue (completed)")
end)

test.add_test("Health tracking buttons - requirements not met", function()
    local ui_generator = core.create_ui_generator()
    
    local mock_date, original_date = data.mock_os_date("2023-01-01")
    os.date = mock_date
    
    -- Empty daily logs (no activities/interventions completed)
    local daily_logs = {
        ["2023-01-01"] = {
            activities = {},
            interventions = {},
            energy_levels = {} -- No energy logged
        }
    }
    
    local required_activities = data.create_sample_required_activities()
    local required_interventions = data.create_sample_required_interventions()
    
    local elements = ui_generator:create_health_tracking_buttons(daily_logs, required_activities, required_interventions)
    
    os.date = original_date
    
    -- All tracking buttons should be red when requirements not met
    test.assert_equals("#dc3545", elements[2][3].color, "Energy button should be red (no logs)")
    test.assert_equals("#dc3545", elements[4][3].color, "Activity button should be red (not completed)")
    test.assert_equals("#dc3545", elements[5][3].color, "Intervention button should be red (not completed)")
end)

test.add_test("No selection content generation", function()
    local ui_generator = core.create_ui_generator()
    
    local elements = ui_generator:create_no_selection_content()
    
    test.assert_type("table", elements, "Should return table")
    test.assert_true(#elements > 5, "Should have multiple elements")
    
    -- Check for key content elements
    local found_selection_text = false
    local found_recovering_desc = false
    local found_maintaining_desc = false
    local found_engaging_desc = false
    local found_sync_button = false
    local found_reset_button = false
    
    for _, element in ipairs(elements) do
        if element[1] == "text" then
            if element[2]:find("Select your capacity level") then
                found_selection_text = true
                test.assert_equals(18, element[3].size, "Title should have size 18")
            elseif element[2]:find("Recovering") then
                found_recovering_desc = true
                test.assert_equals("#FF4444", element[3].color, "Recovering should be red")
            elseif element[2]:find("Maintaining") then
                found_maintaining_desc = true
                test.assert_equals("#FFAA00", element[3].color, "Maintaining should be yellow")
            elseif element[2]:find("Engaging") then
                found_engaging_desc = true  
                test.assert_equals("#44AA44", element[3].color, "Engaging should be green")
            end
        elseif element[1] == "button" then
            if element[2]:find("Sync Files") then
                found_sync_button = true
                test.assert_equals("#4CAF50", element[3].color, "Sync button should be green")
                test.assert_equals("center_h", element[3].gravity, "Sync button should be centered")
            elseif element[2]:find("Reset") then
                found_reset_button = true
                test.assert_equals("#666666", element[3].color, "Reset button should be gray")
                test.assert_equals("anchor_prev", element[3].gravity, "Reset button should be anchored")
            end
        end
    end
    
    test.assert_true(found_selection_text, "Should have selection instruction")
    test.assert_true(found_recovering_desc, "Should have Recovering description")
    test.assert_true(found_maintaining_desc, "Should have Maintaining description")
    test.assert_true(found_engaging_desc, "Should have Engaging description")
    test.assert_true(found_sync_button, "Should have sync button")
    test.assert_true(found_reset_button, "Should have reset button")
end)

test.add_test("Plan details with valid plan", function()
    local ui_generator = core.create_ui_generator()
    
    local test_plan = {
        red = {
            overview = {"**Work:** WFH essential only", "**Exercise:** Complete rest"},
            Morning = {"Sleep in", "Gentle stretching only"},
            Afternoon = {"Minimal work tasks", "Rest frequently"}
        }
    }
    
    local elements = ui_generator:create_plan_details(test_plan, 1)
    
    test.assert_type("table", elements, "Should return table")
    test.assert_true(#elements > 5, "Should have multiple elements")
    
    -- Check for overview section
    local found_overview_title = false
    local found_work_overview = false
    local found_morning_section = false
    local found_morning_item = false
    
    for _, element in ipairs(elements) do
        if element[1] == "text" then
            if element[2]:find("Today's Overview") then
                found_overview_title = true
                test.assert_equals(18, element[3].size, "Overview title should have size 18")
            elseif element[2]:find("<b>Work:</b> WFH essential only") then
                found_work_overview = true
                test.assert_equals(16, element[3].size, "Overview content should have size 16")
            elseif element[2]:find("<b>Morning:</b>") then
                found_morning_section = true
                test.assert_equals(16, element[3].size, "Section title should have size 16")
            elseif element[2]:find("• Sleep in") then
                found_morning_item = true
            end
        end
    end
    
    test.assert_true(found_overview_title, "Should have overview title")
    test.assert_true(found_work_overview, "Should have formatted work overview")
    test.assert_true(found_morning_section, "Should have Morning section")
    test.assert_true(found_morning_item, "Should have morning items")
end)

test.add_test("Plan details with nil plan", function()
    local ui_generator = core.create_ui_generator()
    
    local elements = ui_generator:create_plan_details(nil, 1)
    
    test.assert_type("table", elements, "Should return table")
    
    -- Should show error message
    local found_no_plan = false
    local found_sync_button = false
    
    for _, element in ipairs(elements) do
        if element[1] == "text" and element[2]:find("No plan available") then
            found_no_plan = true
            test.assert_equals("#ff6b6b", element[3].color, "Error message should be red")
        elseif element[1] == "button" and element[2]:find("Sync Files") then
            found_sync_button = true
        end
    end
    
    test.assert_true(found_no_plan, "Should show no plan message")
    test.assert_true(found_sync_button, "Should still show sync button")
end)

test.add_test("Plan details with invalid level", function()
    local ui_generator = core.create_ui_generator()
    
    local test_plan = {
        red = {overview = {"Test overview"}},
        yellow = {overview = {"Test overview"}},
        green = {overview = {"Test overview"}}
    }
    
    -- Try to get plan for level 4 (doesn't exist)
    local elements = ui_generator:create_plan_details(test_plan, 4)
    
    -- Should handle gracefully - might show error or default behavior
    test.assert_type("table", elements, "Should return table even for invalid level")
    test.assert_true(#elements > 0, "Should have some elements")
end)

test.add_test("Error content generation", function()
    local ui_generator = core.create_ui_generator()
    
    local elements = ui_generator:create_error_content("Test error message")
    
    test.assert_type("table", elements, "Should return table")
    
    local found_selected_text = false
    local found_error_message = false
    local found_sync_button = false
    
    for _, element in ipairs(elements) do
        if element[1] == "text" then
            if element[2]:find("Selected:") then
                found_selected_text = true
                test.assert_equals(18, element[3].size, "Selected text should have size 18")
            elseif element[2]:find("Test error message") then
                found_error_message = true
                test.assert_equals("#ff6b6b", element[3].color, "Error should be red")
            end
        elseif element[1] == "button" and element[2]:find("Sync Files") then
            found_sync_button = true
        end
    end
    
    test.assert_true(found_selected_text, "Should show selected level")
    test.assert_true(found_error_message, "Should show custom error message") 
    test.assert_true(found_sync_button, "Should have sync button")
end)

test.add_test("Decision criteria UI generation", function()
    local ui_generator = core.create_ui_generator()
    
    local criteria = {"High fatigue", "Severe brain fog", "Pain levels high"}
    local elements = ui_generator:create_decision_criteria_ui(1, criteria)
    
    test.assert_type("table", elements, "Should return table")
    
    local found_title = false
    local found_criteria = {}
    local found_back = false
    
    for _, element in ipairs(elements) do
        if element[1] == "text" then
            if element[2]:find("Recovering.*Decision Criteria") then
                found_title = true
                test.assert_equals(18, element[3].size, "Title should have size 18")
                test.assert_equals("#FF4444", element[3].color, "Title should have level color")
            else
                for _, criterion in ipairs(criteria) do
                    if element[2]:find(criterion) then
                        found_criteria[criterion] = true
                    end
                end
            end
        elseif element[1] == "button" and element[2] == "Back" then
            found_back = true
            test.assert_equals("#666666", element[3].color, "Back button should be gray")
        end
    end
    
    test.assert_true(found_title, "Should have criteria title")
    test.assert_true(found_back, "Should have back button")
    
    for _, criterion in ipairs(criteria) do
        test.assert_true(found_criteria[criterion], "Should show criterion: " .. criterion)
    end
end)

test.add_test("Decision criteria UI with empty criteria", function()
    local ui_generator = core.create_ui_generator()
    
    local elements = ui_generator:create_decision_criteria_ui(1, {})
    
    test.assert_type("table", elements, "Should return table")
    
    local found_no_criteria = false
    local found_back = false
    
    for _, element in ipairs(elements) do
        if element[1] == "text" and element[2]:find("No criteria available") then
            found_no_criteria = true
            test.assert_equals("#ff6b6b", element[3].color, "No criteria message should be red")
        elseif element[1] == "button" and element[2] == "Back" then
            found_back = true
        end
    end
    
    test.assert_true(found_no_criteria, "Should show no criteria message")
    test.assert_true(found_back, "Should still have back button")
end)

test.add_test("UI element structure consistency", function()
    local ui_generator = core.create_ui_generator()
    
    -- Test that all UI generation methods return properly structured elements
    local test_functions = {
        function() return ui_generator:create_capacity_buttons(1) end,
        function() return ui_generator:create_health_tracking_buttons({}, {}, {}) end,
        function() return ui_generator:create_no_selection_content() end,
        function() return ui_generator:create_plan_details({red = {}}, 1) end,
        function() return ui_generator:create_error_content("test") end,
        function() return ui_generator:create_decision_criteria_ui(1, {"test"}) end
    }
    
    for i, func in ipairs(test_functions) do
        local elements = func()
        test.assert_type("table", elements, "Function " .. i .. " should return table")
        
        for j, element in ipairs(elements) do
            test.assert_type("table", element, "Element " .. j .. " should be table")
            test.assert_true(#element >= 2, "Element should have at least type and content")
            test.assert_type("string", element[1], "Element type should be string")
        end
    end
end)

-- This file can be run standalone or included by main test runner
if ... == nil then
    test.run_tests("UI Generator")
    local success = test.print_final_results()
    os.exit(success and 0 or 1)
end