#!/usr/bin/env lua

-- Test symptom count markers formatting
package.path = package.path .. ";../my/?.lua;../?.lua"

_G.files = { read = function(filename) return nil end }

local core = require("long_covid_core")

-- Mock daily logs with some logged symptoms
local daily_logs = {
    ["2025-01-23"] = {
        symptoms = {
            ["Brain fog (severity: 3)"] = 1,
            ["Brain fog (severity: 6)"] = 1,  -- Same symptom, different severity  
            ["Fatigue (severity: 5)"] = 2    -- Same symptom logged twice
        }
    }
}

print("=== SYMPTOM COUNT FORMATTING TEST ===")
print()

-- Get the default symptoms list
local symptoms = {
    "Fatigue",
    "Brain fog", 
    "Headache",
    "Shortness of breath",
    "Joint pain",
    "Muscle aches",
    "Sleep issues",
    "Other..."
}

print("Original symptoms:")
for i, symptom in ipairs(symptoms) do
    print("  " .. i .. ": " .. symptom)
end
print()

-- Debug the daily logs structure
print("Daily logs structure:")
for date, logs in pairs(daily_logs) do
    print("  Date:", date)
    if logs.symptoms then
        print("    Symptoms:")
        for symptom, count in pairs(logs.symptoms) do
            print("      '" .. symptom .. "' = " .. count)
        end
    end
end
print()

-- Format with daily logs (like the radio dialog does)
local formatted = core.format_list_items(symptoms, "symptom", daily_logs, {}, {})

print("Formatted with counts:")
for i, formatted_symptom in ipairs(formatted) do
    print("  " .. i .. ": " .. formatted_symptom)
end
print()

print("=== EXPECTED FORMATTING ===")
print("Brain fog should show count markers for multiple logged instances")
print("Fatigue should show count markers for multiple logged instances") 
print("Other symptoms should show no markers")
print()

print("=== DIAGNOSIS ===")
local brain_fog_formatted = nil
local fatigue_formatted = nil
for _, item in ipairs(formatted) do
    if item:find("Brain fog") then brain_fog_formatted = item end
    if item:find("Fatigue") then fatigue_formatted = item end
end

print("Brain fog formatted as:", brain_fog_formatted or "not found")
print("Fatigue formatted as:", fatigue_formatted or "not found")

-- Check if counts are working
local has_brain_fog_count = brain_fog_formatted and brain_fog_formatted:find("%(2%)") -- Should be (2) for 2 different severity entries
local has_fatigue_count = fatigue_formatted and fatigue_formatted:find("%(2%)") -- Should be (2) for 2 entries of same severity

print()
print("Brain fog has count marker:", has_brain_fog_count and true or false)
print("Fatigue has count marker:", has_fatigue_count and true or false)