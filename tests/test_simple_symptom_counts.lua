#!/usr/bin/env lua

-- Test simplified symptom count approach
package.path = package.path .. ";../my/?.lua;../?.lua"

local core = require("long_covid_core")

-- Mock daily logs - now storing just base symptom names (use today's date)
local today = os.date("%Y-%m-%d")
local daily_logs = {
    [today] = {
        symptoms = {
            ["Brain fog"] = 2,    -- Logged twice (different severities)
            ["Fatigue"] = 1       -- Logged once
        }
    }
}

print("=== SIMPLIFIED SYMPTOM COUNT TEST ===")
print()

local symptoms = {"Fatigue", "Brain fog", "Headache", "Other..."}

print("Daily logs (simplified):")
for date, logs in pairs(daily_logs) do
    if logs.symptoms then
        for symptom, count in pairs(logs.symptoms) do
            print("  '" .. symptom .. "' = " .. count)
        end
    end
end
print()

local formatted = core.format_list_items(symptoms, "symptom", daily_logs, {}, {})

print("Formatted symptoms:")
for i, formatted_symptom in ipairs(formatted) do
    print("  " .. i .. ": " .. formatted_symptom)
end
print()

print("Expected: Brain fog and Fatigue should show count markers")
print("Actual:", formatted[1]:find("%(1%)") and "Fatigue has count" or "Fatigue missing count")
print("Actual:", formatted[2]:find("%(2%)") and "Brain fog has count" or "Brain fog missing count")