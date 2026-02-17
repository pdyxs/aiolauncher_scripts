package.path = "../?.lua;" .. package.path

-- Mock dependencies before requiring log-via-tasker
local mock_prefs = {}
package.loaded["prefs"] = mock_prefs
package.loaded["core.time-utils"] = {
    get_current_timestamp = function() return os.time() end
}
package.loaded["core.util"] = require("my.core.util")

local logger = require("my.core.log-via-tasker")

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

local function reset_prefs()
    mock_prefs.logs = nil
end

-- Tests for store_log (single event, existing behavior)

test.add_test("store_log: single event increments all levels", function()
    reset_prefs()
    logger.store_log("Intervention", "physio", "one")

    test.assert_equals(mock_prefs.logs["Intervention"].count, 1, "event count")
    test.assert_equals(mock_prefs.logs["Intervention"].values["physio"].count, 1, "value count")
    test.assert_equals(mock_prefs.logs["Intervention"].values["physio"].details["one"].count, 1, "detail count")
end)

test.add_test("store_log: repeated calls increment all levels each time", function()
    reset_prefs()
    logger.store_log("Intervention", "physio", "one")
    logger.store_log("Intervention", "physio", "two")
    logger.store_log("Intervention", "physio", "three")

    test.assert_equals(mock_prefs.logs["Intervention"].count, 3, "event count should be 3")
    test.assert_equals(mock_prefs.logs["Intervention"].values["physio"].count, 3, "value count should be 3")
    test.assert_equals(mock_prefs.logs["Intervention"].values["physio"].details["one"].count, 1, "detail one count")
    test.assert_equals(mock_prefs.logs["Intervention"].values["physio"].details["two"].count, 1, "detail two count")
    test.assert_equals(mock_prefs.logs["Intervention"].values["physio"].details["three"].count, 1, "detail three count")
end)

-- Tests for store_logs (batch, deduplicated behavior)

test.add_test("store_logs: same event+value with different details increments parent only once", function()
    reset_prefs()
    logger.store_logs({
        { "Intervention", "physio", "one" },
        { "Intervention", "physio", "two" },
        { "Intervention", "physio", "three" },
    })

    test.assert_equals(mock_prefs.logs["Intervention"].count, 1, "event count should be 1")
    test.assert_equals(mock_prefs.logs["Intervention"].values["physio"].count, 1, "value count should be 1")
    test.assert_equals(mock_prefs.logs["Intervention"].values["physio"].details["one"].count, 1, "detail one count")
    test.assert_equals(mock_prefs.logs["Intervention"].values["physio"].details["two"].count, 1, "detail two count")
    test.assert_equals(mock_prefs.logs["Intervention"].values["physio"].details["three"].count, 1, "detail three count")
end)

test.add_test("store_logs: single event behaves same as store_log", function()
    reset_prefs()
    logger.store_logs({
        { "Intervention", "physio", "one" },
    })

    test.assert_equals(mock_prefs.logs["Intervention"].count, 1, "event count")
    test.assert_equals(mock_prefs.logs["Intervention"].values["physio"].count, 1, "value count")
    test.assert_equals(mock_prefs.logs["Intervention"].values["physio"].details["one"].count, 1, "detail count")
end)

test.add_test("store_logs: different events get separate counts", function()
    reset_prefs()
    logger.store_logs({
        { "Intervention", "physio", "one" },
        { "Activity", "walking", "short" },
    })

    test.assert_equals(mock_prefs.logs["Intervention"].count, 1, "intervention event count")
    test.assert_equals(mock_prefs.logs["Intervention"].values["physio"].count, 1, "physio value count")
    test.assert_equals(mock_prefs.logs["Activity"].count, 1, "activity event count")
    test.assert_equals(mock_prefs.logs["Activity"].values["walking"].count, 1, "walking value count")
end)

test.add_test("store_logs: different values under same event get separate value counts", function()
    reset_prefs()
    logger.store_logs({
        { "Intervention", "physio", "one" },
        { "Intervention", "massage", "deep" },
    })

    test.assert_equals(mock_prefs.logs["Intervention"].count, 1, "event count should be 1")
    test.assert_equals(mock_prefs.logs["Intervention"].values["physio"].count, 1, "physio value count")
    test.assert_equals(mock_prefs.logs["Intervention"].values["massage"].count, 1, "massage value count")
end)

test.add_test("store_logs: events without detail only increment event and value", function()
    reset_prefs()
    logger.store_logs({
        { "Intervention", "physio" },
        { "Intervention", "massage" },
    })

    test.assert_equals(mock_prefs.logs["Intervention"].count, 1, "event count should be 1")
    test.assert_equals(mock_prefs.logs["Intervention"].values["physio"].count, 1, "physio value count")
    test.assert_equals(mock_prefs.logs["Intervention"].values["massage"].count, 1, "massage value count")
end)

test.add_test("store_logs: accumulates with existing counts", function()
    reset_prefs()
    -- First batch
    logger.store_logs({
        { "Intervention", "physio", "one" },
        { "Intervention", "physio", "two" },
    })
    -- Second batch
    logger.store_logs({
        { "Intervention", "physio", "three" },
        { "Intervention", "physio", "four" },
    })

    test.assert_equals(mock_prefs.logs["Intervention"].count, 2, "event count should be 2 (one per batch)")
    test.assert_equals(mock_prefs.logs["Intervention"].values["physio"].count, 2, "value count should be 2 (one per batch)")
    test.assert_equals(mock_prefs.logs["Intervention"].values["physio"].details["one"].count, 1)
    test.assert_equals(mock_prefs.logs["Intervention"].values["physio"].details["two"].count, 1)
    test.assert_equals(mock_prefs.logs["Intervention"].values["physio"].details["three"].count, 1)
    test.assert_equals(mock_prefs.logs["Intervention"].values["physio"].details["four"].count, 1)
end)

test.add_test("store_logs: sets last_value and last_detail correctly", function()
    reset_prefs()
    logger.store_logs({
        { "Intervention", "physio", "one" },
        { "Intervention", "physio", "two" },
        { "Intervention", "physio", "three" },
    })

    test.assert_equals(mock_prefs.logs["Intervention"].last_value, "physio", "last_value")
    test.assert_equals(mock_prefs.logs["Intervention"].values["physio"].last_detail, "three", "last_detail should be last in batch")
end)

-- Run tests
if ... == nil then
    test.run_tests()
    os.exit(test.failed == 0 and 0 or 1)
end
