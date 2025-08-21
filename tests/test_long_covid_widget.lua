#!/usr/bin/env lua

-- Final Working Test Suite for Long Covid Pacing Widget
-- Run with: lua test_long_covid_final.lua

-- Mock AIO Launcher environment
local test_prefs = {}
local test_ui_calls = {}
local test_files = {}
local test_toasts = {}

-- Mock prefs module
local mock_prefs = setmetatable({}, {
    __index = function(t, k) return test_prefs[k] end,
    __newindex = function(t, k, v) test_prefs[k] = v end
})

-- Mock ui module
local mock_ui = {
    show_text = function(text) table.insert(test_ui_calls, {"show_text", text}) end,
    show_toast = function(text) 
        table.insert(test_ui_calls, {"show_toast", text})
        table.insert(test_toasts, text)
    end,
    set_title = function(title) table.insert(test_ui_calls, {"set_title", title}) end,
    set_expandable = function(expandable) table.insert(test_ui_calls, {"set_expandable", expandable}) end,
    is_expanded = function() return test_ui_expanded or false end
}

-- Mock files module
local mock_files = {
    read = function(filename) return test_files[filename] end,
    write = function(filename, content) test_files[filename] = content end
}

-- Mock gui function
local function mock_gui(elements)
    return {
        ui = elements,
        render = function() table.insert(test_ui_calls, {"gui_render", elements}) end
    }
end

-- Helper function to split text into lines
local function split_lines(text)
    local lines = {}
    for line in text:gmatch("[^\r\n]+") do
        table.insert(lines, line)
    end
    return lines
end

-- Helper function for string find
local function string_find(str, pattern, init, plain)
    return string.find(str, pattern, init, plain)
end

-- Test data
local test_criteria_content = [[## RED
- Feeling extremely fatigued
- Brain fog severe
- Pain levels high

## YELLOW
- Moderate fatigue
- Some brain fog
- Manageable symptoms

## GREEN
- Good energy levels
- Clear thinking
- Minimal symptoms
]]

local test_monday_content = [[## RED
**Work:** WFH essential only
**Exercise:** Complete rest

### Morning
- Sleep in
- Gentle stretching only

### Afternoon
- Minimal work tasks
- Rest frequently

## YELLOW
**Work:** WFH normal schedule
**Exercise:** Light walking

### Morning
- Normal wake time
- Light breakfast prep

### Afternoon
- Standard work tasks
- 15 min walk

## GREEN
**Work:** Office possible
**Exercise:** Full routine

### Morning
- Early start possible
- Full breakfast prep

### Afternoon
- All work tasks
- 30 min exercise
]]

-- Setup widget environment
local function setup_widget_env()
    -- Reset state
    test_prefs = {}
    test_ui_calls = {}
    test_files = {}
    test_toasts = {}
    test_ui_expanded = false
    
    -- Set up globals
    _G.prefs = mock_prefs
    _G.ui = mock_ui
    _G.files = mock_files
    _G.gui = mock_gui
    _G.my_gui = nil
    
    -- Initialize default prefs
    _G.prefs.selected_level = 0
    _G.prefs.last_selection_date = ""
end

-- Widget functionality - reimplemented for testing
local levels = {
    {name = "Recovering", color = "#FF4444", key = "red", icon = "bed"},
    {name = "Maintaining", color = "#FFAA00", key = "yellow", icon = "walking"}, 
    {name = "Engaging", color = "#44AA44", key = "green", icon = "bolt"}
}

local function test_parse_decision_criteria()
    local content = mock_files.read("decision_criteria.md")
    if not content then
        return {red = {}, yellow = {}, green = {}}
    end
    
    local criteria = {red = {}, yellow = {}, green = {}}
    local current_level = nil
    
    local lines = split_lines(content)
    for _, line in ipairs(lines) do
        if line:match("^## RED") then
            current_level = "red"
        elseif line:match("^## YELLOW") then
            current_level = "yellow"
        elseif line:match("^## GREEN") then
            current_level = "green"
        elseif line:match("^%- ") and current_level then
            local item = line:match("^%- (.+)")
            if item then
                table.insert(criteria[current_level], item)
            end
        end
    end
    
    return criteria
end

local function test_parse_day_file(day)
    local filename = day .. ".md"
    local content = mock_files.read(filename)
    
    if not content then
        return {red = {}, yellow = {}, green = {}}
    end
    
    local template = {red = {}, yellow = {}, green = {}}
    local current_level = nil
    local current_category = nil
    
    local lines = split_lines(content)
    for _, line in ipairs(lines) do
        if line:match("^## RED") then
            current_level = "red"
            current_category = nil
            template[current_level].overview = {}
        elseif line:match("^## YELLOW") then
            current_level = "yellow"
            current_category = nil
            template[current_level].overview = {}
        elseif line:match("^## GREEN") then
            current_level = "green"
            current_category = nil
            template[current_level].overview = {}
        elseif line:match("^%*%*") and current_level and not current_category then
            table.insert(template[current_level].overview, line)
        elseif line:match("^### ") and current_level then
            current_category = line:match("^### (.+)")
            if current_category then
                template[current_level][current_category] = {}
            end
        elseif line:match("^#### ") and current_level then
            current_category = line:match("^#### (.+)")
            if current_category then
                template[current_level][current_category] = {}
            end
        elseif line:match("^%- ") and current_level and current_category then
            local item = line:match("^%- (.+)")
            if item then
                table.insert(template[current_level][current_category], item)
            end
        end
    end
    
    return template
end

local function test_get_current_day()
    local day_names = {"sunday", "monday", "tuesday", "wednesday", "thursday", "friday", "saturday"}
    local today = day_names[tonumber(os.date("%w")) + 1]
    return today
end

local function test_check_daily_reset()
    local today = os.date("%Y-%m-%d")
    if _G.prefs.last_selection_date ~= today then
        _G.prefs.selected_level = 0
        _G.prefs.last_selection_date = today
        -- Clear today's tracking logs on new day
        if _G.prefs.daily_logs then
            _G.prefs.daily_logs[today] = nil
        end
    end
end

local function test_get_daily_logs(date)
    if not _G.prefs.daily_logs then
        _G.prefs.daily_logs = {}
    end
    
    if not _G.prefs.daily_logs[date] then
        _G.prefs.daily_logs[date] = {
            symptoms = {},
            activities = {},
            interventions = {}
        }
    end
    
    return _G.prefs.daily_logs[date]
end

local function test_log_item(item_type, item_name)
    local today = os.date("%Y-%m-%d")
    local logs = test_get_daily_logs(today)
    
    local category
    if item_type == "symptom" then
        category = logs.symptoms
    elseif item_type == "activity" then
        category = logs.activities
    elseif item_type == "intervention" then
        category = logs.interventions
    else
        error("Invalid item type: " .. tostring(item_type))
    end
    
    category[item_name] = (category[item_name] or 0) + 1
end

local function test_format_list_items(items, item_type)
    local today = os.date("%Y-%m-%d")
    local logs = test_get_daily_logs(today)
    
    local category
    if item_type == "symptom" then
        category = logs.symptoms
    elseif item_type == "activity" then
        category = logs.activities
    elseif item_type == "intervention" then
        category = logs.interventions
    else
        error("Invalid item type: " .. tostring(item_type))
    end
    
    local formatted = {}
    for _, item in ipairs(items) do
        local count = category[item]
        if count and count > 0 then
            table.insert(formatted, item .. " (" .. count .. ")")
        else
            table.insert(formatted, item)
        end
    end
    
    return formatted
end

local function test_save_daily_choice(level_idx)
    if level_idx == 0 then
        return
    end
    
    local today = os.date("%Y-%m-%d")
    local day_name = test_get_current_day()
    local level_name = levels[level_idx].name
    
    local entry = string.format("## %s (%s)\n- Capacity: %s\n- Time: %s\n\n", 
        today, day_name:gsub("^%l", string.upper), level_name, os.date("%H:%M"))
    
    local existing_content = mock_files.read("tracking.md") or "# Long Covid Daily Tracking\n\n"
    local new_content = existing_content .. entry
    
    mock_files.write("tracking.md", new_content)
end

local function test_render_widget()
    local today = test_get_current_day()
    local day_display = today:gsub("^%l", string.upper)
    
    mock_ui.set_title("Long Covid Pacing - " .. day_display)
    mock_ui.set_expandable(true)
    
    local ui_elements = {}
    
    -- Add capacity level buttons
    for i, level in ipairs(levels) do
        local color = level.color
        local button_text = "%%fa:" .. level.icon .. "%% " .. level.name
        
        table.insert(ui_elements, {"button", button_text, {color = color}})
        if i < #levels then
            table.insert(ui_elements, {"spacer", 1})
        end
    end
    
    _G.my_gui = mock_gui(ui_elements)
    _G.my_gui.render()
end

local function test_on_click(idx)
    if not _G.my_gui then return end
    
    local element = _G.my_gui.ui[idx]
    if not element then return end
    
    local elem_type = element[1]
    local elem_text = element[2]
    
    if elem_type == "button" then
        if string_find(elem_text, "bed") then
            if _G.prefs.selected_level == 0 or 1 <= _G.prefs.selected_level then
                _G.prefs.selected_level = 1
                test_save_daily_choice(1)
                test_render_widget()
            else
                mock_ui.show_toast("Can only downgrade capacity level")
            end
        elseif string_find(elem_text, "walking") then
            if _G.prefs.selected_level == 0 or 2 <= _G.prefs.selected_level then
                _G.prefs.selected_level = 2
                test_save_daily_choice(2)
                test_render_widget()
            else
                mock_ui.show_toast("Can only downgrade capacity level")
            end
        elseif string_find(elem_text, "bolt") then
            if _G.prefs.selected_level == 0 or 3 <= _G.prefs.selected_level then
                _G.prefs.selected_level = 3
                test_save_daily_choice(3)
                test_render_widget()
            else
                mock_ui.show_toast("Can only downgrade capacity level")
            end
        elseif string_find(elem_text, "rotate%-right") or string_find(elem_text, "Reset") then
            _G.prefs.selected_level = 0
            mock_ui.show_toast("Selection reset")
            test_render_widget()
        end
    end
end

-- Test framework
local tests = {}

local function add_test(name, test_func)
    table.insert(tests, {name = name, func = test_func})
end

local function assert_equals(expected, actual, message)
    if expected ~= actual then
        error((message or "Assertion failed") .. ": expected '" .. tostring(expected) .. "', got '" .. tostring(actual) .. "'")
    end
end

local function assert_true(condition, message)
    if not condition then
        error(message or "Expected true but got false")
    end
end

local function assert_contains(haystack, needle, message)
    if type(haystack) == "table" then
        for _, item in ipairs(haystack) do
            if string_find(tostring(item), tostring(needle), 1, true) then return end
        end
        error((message or "Table does not contain expected value") .. ": " .. tostring(needle))
    else
        if not string_find(tostring(haystack), tostring(needle), 1, true) then
            error((message or "String does not contain expected substring") .. ": " .. tostring(needle))
        end
    end
end

-- Tests
add_test("Initial preferences state", function()
    setup_widget_env()
    
    assert_equals(0, _G.prefs.selected_level, "Default selected level should be 0")
    assert_equals("", _G.prefs.last_selection_date, "Default last selection date should be empty")
end)

add_test("Daily reset functionality", function()
    setup_widget_env()
    
    _G.prefs.selected_level = 2
    _G.prefs.last_selection_date = "2023-01-01"
    
    test_check_daily_reset()
    
    assert_equals(0, _G.prefs.selected_level, "Should reset selection on new day")
    assert_equals(os.date("%Y-%m-%d"), _G.prefs.last_selection_date, "Should update to current date")
end)

add_test("Current day calculation", function()
    setup_widget_env()
    
    local day = test_get_current_day()
    local valid_days = {"sunday", "monday", "tuesday", "wednesday", "thursday", "friday", "saturday"}
    
    local found = false
    for _, valid_day in ipairs(valid_days) do
        if day == valid_day then
            found = true
            break
        end
    end
    
    assert_true(found, "Should return a valid day name: " .. tostring(day))
end)

add_test("Decision criteria parsing", function()
    setup_widget_env()
    test_files["decision_criteria.md"] = test_criteria_content
    
    local criteria = test_parse_decision_criteria()
    
    assert_true(type(criteria) == "table", "Should return a table")
    assert_true(type(criteria.red) == "table", "Should have red criteria table")
    assert_true(type(criteria.yellow) == "table", "Should have yellow criteria table")
    assert_true(type(criteria.green) == "table", "Should have green criteria table")
    
    assert_true(#criteria.red > 0, "Should parse RED criteria (found " .. #criteria.red .. " items)")
    assert_true(#criteria.yellow > 0, "Should parse YELLOW criteria (found " .. #criteria.yellow .. " items)") 
    assert_true(#criteria.green > 0, "Should parse GREEN criteria (found " .. #criteria.green .. " items)")
    
    assert_contains(criteria.red[1], "extremely fatigued", "Should contain expected RED criterion")
    assert_contains(criteria.yellow[1], "Moderate fatigue", "Should contain expected YELLOW criterion")
    assert_contains(criteria.green[1], "Good energy", "Should contain expected GREEN criterion")
end)

add_test("Day file parsing", function()
    setup_widget_env()
    test_files["monday.md"] = test_monday_content
    
    local plan = test_parse_day_file("monday")
    
    assert_true(type(plan) == "table", "Should return a table")
    assert_true(plan.red ~= nil, "Should have RED level plan")
    assert_true(plan.yellow ~= nil, "Should have YELLOW level plan")
    assert_true(plan.green ~= nil, "Should have GREEN level plan")
    
    -- Test overview parsing
    assert_true(type(plan.red.overview) == "table", "Should have RED overview table")
    assert_true(#plan.red.overview > 0, "Should parse RED overview (found " .. #plan.red.overview .. " items)")
    assert_contains(plan.red.overview[1], "WFH essential only", "Should contain work overview")
    
    -- Test category parsing
    assert_true(plan.red.Morning ~= nil, "Should parse Morning category")
    assert_true(type(plan.red.Morning) == "table", "Morning should be a table")
    assert_true(#plan.red.Morning > 0, "Should have Morning items")
    assert_contains(plan.red.Morning[1], "Sleep in", "Should contain expected morning item")
end)

add_test("Save daily choice functionality", function()
    setup_widget_env()
    
    test_save_daily_choice(2)
    
    local tracking_content = test_files["tracking.md"]
    assert_true(tracking_content ~= nil, "Should create tracking file")
    assert_contains(tracking_content, "Maintaining", "Should save correct capacity level")
    assert_contains(tracking_content, os.date("%Y-%m-%d"), "Should save current date")
end)

add_test("Widget rendering basic functionality", function()
    setup_widget_env()
    
    _G.prefs.selected_level = 0
    
    test_render_widget()
    
    -- Check that title was set
    local title_found = false
    for _, call in ipairs(test_ui_calls) do
        if call[1] == "set_title" and type(call[2]) == "string" and string_find(call[2], "Long Covid Pacing") then
            title_found = true
            break
        end
    end
    
    assert_true(title_found, "Should set widget title with correct text")
    
    -- Check that expandable was set
    local expandable_found = false
    for _, call in ipairs(test_ui_calls) do
        if call[1] == "set_expandable" then
            expandable_found = true
            break
        end
    end
    
    assert_true(expandable_found, "Should set expandable")
end)

add_test("Click handling - capacity selection", function()
    setup_widget_env()
    
    -- Set up mock GUI with buttons
    local ui_elements = {
        {"button", "fa:bed", {color = "#FF4444"}},
        {"spacer", 1},
        {"button", "%%fa:walking%% Maintaining", {color = "#FFAA00"}}, 
        {"spacer", 1},
        {"button", "fa:bolt", {color = "#888888"}}
    }
    
    _G.my_gui = {ui = ui_elements}
    
    -- Test clicking the walking button (index 3)
    _G.prefs.selected_level = 0
    test_on_click(3)
    
    assert_equals(2, _G.prefs.selected_level, "Should set selected level to 2 (Maintaining)")
end)

add_test("Click handling - reset button", function()
    setup_widget_env()
    
    local ui_elements = {
        {"button", "%%fa:rotate-right%% Reset", {color = "#666666"}}
    }
    
    _G.my_gui = {ui = ui_elements}
    _G.prefs.selected_level = 2
    
    test_on_click(1)
    
    assert_equals(0, _G.prefs.selected_level, "Should reset selected level to 0")
    assert_contains(test_toasts, "Selection reset", "Should show reset toast")
end)

add_test("Level upgrade prevention", function()
    setup_widget_env()
    
    local ui_elements = {
        {"button", "%%fa:bolt%% Engaging", {color = "#44AA44"}}
    }
    
    _G.my_gui = {ui = ui_elements}
    _G.prefs.selected_level = 1  -- Currently at Recovering (level 1)
    
    -- Try to click Engaging (level 3) - should be prevented
    test_on_click(1)
    
    assert_equals(1, _G.prefs.selected_level, "Should not allow upgrade from Recovering")
    assert_contains(test_toasts, "Can only downgrade capacity level", "Should show upgrade prevention message")
end)

-- Daily tracking tests
add_test("Initialize daily logs", function()
    setup_widget_env()
    
    local today = os.date("%Y-%m-%d")
    local logs = test_get_daily_logs(today)
    
    assert_true(type(logs) == "table", "Should return logs table")
    assert_true(type(logs.symptoms) == "table", "Should have symptoms table")
    assert_true(type(logs.activities) == "table", "Should have activities table")
    assert_true(type(logs.interventions) == "table", "Should have interventions table")
end)

add_test("Log symptom with count tracking", function()
    setup_widget_env()
    
    local today = os.date("%Y-%m-%d")
    
    -- Log the same symptom multiple times
    test_log_item("symptom", "Fatigue")
    test_log_item("symptom", "Fatigue")
    test_log_item("symptom", "Brain fog")
    
    local logs = test_get_daily_logs(today)
    
    assert_equals(2, logs.symptoms["Fatigue"], "Should track Fatigue count as 2")
    assert_equals(1, logs.symptoms["Brain fog"], "Should track Brain fog count as 1")
end)

add_test("Log activity with count tracking", function()
    setup_widget_env()
    
    local today = os.date("%Y-%m-%d")
    
    -- Log activities
    test_log_item("activity", "Light walk")
    test_log_item("activity", "Cooking")
    test_log_item("activity", "Cooking")
    test_log_item("activity", "Cooking")
    
    local logs = test_get_daily_logs(today)
    
    assert_equals(1, logs.activities["Light walk"], "Should track Light walk count as 1")
    assert_equals(3, logs.activities["Cooking"], "Should track Cooking count as 3")
end)

add_test("Log intervention with count tracking", function()
    setup_widget_env()
    
    local today = os.date("%Y-%m-%d")
    
    -- Log interventions
    test_log_item("intervention", "Vitamin D")
    test_log_item("intervention", "Rest")
    test_log_item("intervention", "Rest")
    
    local logs = test_get_daily_logs(today)
    
    assert_equals(1, logs.interventions["Vitamin D"], "Should track Vitamin D count as 1")
    assert_equals(2, logs.interventions["Rest"], "Should track Rest count as 2")
end)

add_test("Format list items with counts", function()
    setup_widget_env()
    
    local today = os.date("%Y-%m-%d")
    
    -- Set up some logged items
    test_log_item("symptom", "Fatigue")
    test_log_item("symptom", "Fatigue")
    test_log_item("symptom", "Brain fog")
    
    local symptoms = {"Fatigue", "Brain fog", "Headache"}
    local formatted = test_format_list_items(symptoms, "symptom")
    
    assert_contains(formatted[1], "Fatigue (2)", "Should show count for multiple logs")
    assert_contains(formatted[2], "Brain fog (1)", "Should show count for single log")
    assert_equals("Headache", formatted[3], "Should show plain text for unlogged items")
end)

add_test("Daily reset clears tracking logs", function()
    setup_widget_env()
    
    local today = os.date("%Y-%m-%d")
    
    -- Log some items
    test_log_item("symptom", "Fatigue")
    test_log_item("activity", "Walking")
    
    -- Verify items are logged
    local logs = test_get_daily_logs(today)
    assert_equals(1, logs.symptoms["Fatigue"], "Should have logged Fatigue")
    assert_equals(1, logs.activities["Walking"], "Should have logged Walking")
    
    -- Simulate new day by changing last_selection_date
    _G.prefs.last_selection_date = "2023-01-01"
    test_check_daily_reset()
    
    -- Check that today's logs are cleared
    local new_logs = test_get_daily_logs(today)
    assert_equals(0, new_logs.symptoms["Fatigue"] or 0, "Should clear Fatigue count on new day")
    assert_equals(0, new_logs.activities["Walking"] or 0, "Should clear Walking count on new day")
end)

add_test("Extract item name from formatted string", function()
    setup_widget_env()
    
    -- Test the extract_item_name function that needs to be implemented in main widget
    local function test_extract_item_name(formatted_item)
        local item_name = formatted_item:match("^(.+)%s%(%d+%)$")
        return item_name or formatted_item
    end
    
    assert_equals("Fatigue", test_extract_item_name("Fatigue (2)"), "Should extract name from counted item")
    assert_equals("Brain fog", test_extract_item_name("Brain fog (1)"), "Should extract name from single count")
    assert_equals("Headache", test_extract_item_name("Headache"), "Should return original for uncounted item")
    assert_equals("Other...", test_extract_item_name("Other..."), "Should handle special items")
end)

add_test("Widget initialization creates daily logs", function()
    setup_widget_env()
    
    -- Simulate widget initialization
    if not _G.prefs.daily_logs then
        _G.prefs.daily_logs = {}
    end
    
    local today = os.date("%Y-%m-%d")
    local logs = test_get_daily_logs(today)
    
    assert_true(_G.prefs.daily_logs ~= nil, "Should initialize daily_logs table")
    assert_true(logs ~= nil, "Should create today's logs")
    assert_true(logs.symptoms ~= nil, "Should create symptoms table")
    assert_true(logs.activities ~= nil, "Should create activities table") 
    assert_true(logs.interventions ~= nil, "Should create interventions table")
end)

-- Run tests
local function run_tests()
    print("Running Long Covid Widget Tests (Final Version)...")
    print("=" .. string.rep("=", 60))
    
    local passed = 0
    
    for _, test in ipairs(tests) do
        local success, error_msg = pcall(test.func)
        
        if success then
            passed = passed + 1
            print("✓ " .. test.name)
        else
            print("✗ " .. test.name)
            print("  Error: " .. tostring(error_msg))
        end
    end
    
    print("=" .. string.rep("=", 60))
    print(string.format("Results: %d/%d tests passed", passed, #tests))
    
    if passed == #tests then
        print("All tests passed! 🎉")
        os.exit(0)
    else
        print("Some tests failed. ❌")
        os.exit(1)
    end
end

-- Run the tests
run_tests()