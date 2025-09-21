package.path = "../?.lua;" .. package.path

local todo_parser = require("my.core.todo_parser")

-- Test framework
local test = {}
test.tests = {}
test.passed = 0
test.failed = 0

function test.assert_equals(actual, expected, message)
    if actual ~= expected then
        error("ASSERT_EQUALS FAILED: " .. (message or "") .. "\nExpected: " .. tostring(expected) .. "\nActual: " .. tostring(actual))
    end
end

function test.assert_table_equals(actual, expected, message)
    if #actual ~= #expected then
        error("ASSERT_TABLE_EQUALS FAILED: " .. (message or "") .. "\nDifferent lengths: expected " .. #expected .. ", got " .. #actual)
    end
    for i = 1, #expected do
        if actual[i] ~= expected[i] then
            error("ASSERT_TABLE_EQUALS FAILED: " .. (message or "") .. "\nAt index " .. i .. ": expected '" .. tostring(expected[i]) .. "', got '" .. tostring(actual[i]) .. "'")
        end
    end
end

function test.add_test(name, test_func)
    table.insert(test.tests, {name = name, func = test_func})
end

function test.run_tests()
    for _, t in ipairs(test.tests) do
        local success, err = pcall(t.func)
        if success then
            print("✓ " .. t.name)
            test.passed = test.passed + 1
        else
            print("✗ " .. t.name .. ": " .. err)
            test.failed = test.failed + 1
        end
    end
    print("\nResults: " .. test.passed .. " passed, " .. test.failed .. " failed")
    return test.failed == 0
end

-- Test data
local test_data = {
    {
        text = "Bicep curls",
        children = {
            {text = "Recovering: 4kg, 3x4", children = {}},
            {text = "Maintaining: 4kg, 3x6", children = {}},
            {text = "Engaging: 4kg, 3x8", children = {}}
        }
    },
    {
        text = "Foam roll thighs (front and side)",
        children = {
            {text = "Recovering: 30 secs each", children = {}},
            {text = "Maintaining: 60 secs each", children = {}},
            {text = "Engaging: 90 secs each", children = {}}
        }
    },
    {
        text = "Rotate Between:",
        children = {
            {
                text = "Single leg bridges",
                children = {
                    {text = "Recovering: 3x4", children = {}},
                    {text = "Maintaining: 3x6", children = {}},
                    {text = "Engaging: 3x8", children = {}}
                }
            },
            {
                text = "Wall sits",
                children = {
                    {text = "Recovering: 2x20secs, 1 minute rest", children = {}},
                    {text = "Maintaining: 3x20-30secs, 1 minute rest", children = {}},
                    {text = "Engaging: 3x30secs, 1 minute rest", children = {}}
                }
            }
        }
    },
    {
        text = "Simple item without capacity",
        children = {}
    }
}

-- Tests
test.add_test("Basic capacity selection - Maintaining", function()
    local result = todo_parser.parse_todo_list({test_data[1]}, 0, "Maintaining")
    test.assert_table_equals(result, {"Bicep curls (4kg, 3x6)"})
end)

test.add_test("Basic capacity selection - Recovering", function()
    local result = todo_parser.parse_todo_list({test_data[1]}, 0, "Recovering")
    test.assert_table_equals(result, {"Bicep curls (4kg, 3x4)"})
end)

test.add_test("Basic capacity selection - Engaging", function()
    local result = todo_parser.parse_todo_list({test_data[1]}, 0, "Engaging")
    test.assert_table_equals(result, {"Bicep curls (4kg, 3x8)"})
end)

test.add_test("Item with existing brackets", function()
    local result = todo_parser.parse_todo_list({test_data[2]}, 0, "Maintaining")
    test.assert_table_equals(result, {"Foam roll thighs (front and side, 60 secs each)"})
end)

test.add_test("Rotation - first completion (index 0)", function()
    local result = todo_parser.parse_todo_list({test_data[3]}, 0, "Maintaining")
    test.assert_table_equals(result, {"Single leg bridges (3x6)"})
end)

test.add_test("Rotation - second completion (index 1)", function()
    local result = todo_parser.parse_todo_list({test_data[3]}, 1, "Maintaining")
    test.assert_table_equals(result, {"Wall sits (3x20-30secs, 1 minute rest)"})
end)

test.add_test("Rotation - third completion (wraps around)", function()
    local result = todo_parser.parse_todo_list({test_data[3]}, 2, "Maintaining")
    test.assert_table_equals(result, {"Single leg bridges (3x6)"})
end)

test.add_test("Rotation with different capacity levels", function()
    local result = todo_parser.parse_todo_list({test_data[3]}, 0, "Recovering")
    test.assert_table_equals(result, {"Single leg bridges (3x4)"})

    result = todo_parser.parse_todo_list({test_data[3]}, 1, "Engaging")
    test.assert_table_equals(result, {"Wall sits (3x30secs, 1 minute rest)"})
end)

test.add_test("Simple item without capacity", function()
    local result = todo_parser.parse_todo_list({test_data[4]}, 0, "Maintaining")
    test.assert_table_equals(result, {"Simple item without capacity"})
end)

test.add_test("Multiple items", function()
    local input = {test_data[1], test_data[4]}
    local result = todo_parser.parse_todo_list(input, 0, "Maintaining")
    test.assert_table_equals(result, {"Bicep curls (4kg, 3x6)", "Simple item without capacity"})
end)

test.add_test("Empty input", function()
    local result = todo_parser.parse_todo_list({}, 0, "Maintaining")
    test.assert_table_equals(result, {})
end)

test.add_test("Case insensitive capacity matching", function()
    local test_item = {
        text = "Test exercise",
        children = {
            {text = "maintaining: case test", children = {}},
            {text = "RECOVERING: upper case", children = {}}
        }
    }
    local result = todo_parser.parse_todo_list({test_item}, 0, "Maintaining")
    test.assert_table_equals(result, {"Test exercise (case test)"})

    result = todo_parser.parse_todo_list({test_item}, 0, "Recovering")
    test.assert_table_equals(result, {"Test exercise (upper case)"})
end)

test.add_test("Nil inputs", function()
    local result = todo_parser.parse_todo_list(nil, 0, "Maintaining")
    test.assert_table_equals(result, {})

    result = todo_parser.parse_todo_list({test_data[1]}, nil, "Maintaining")
    test.assert_table_equals(result, {"Bicep curls (4kg, 3x6)"})

    result = todo_parser.parse_todo_list({test_data[1]}, 0, nil)
    test.assert_table_equals(result, {})
end)

-- Run tests if this file is executed directly
if ... == nil then
    test.run_tests()
    os.exit(test.failed == 0 and 0 or 1)
end