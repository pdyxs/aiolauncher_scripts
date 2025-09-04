-- Long Covid Widget - Weekly Requirements Module
-- Handles weekly requirement logic and tracking

local M = {}

-- Dependencies
local date_utils = require "long_covid_date"
local parsing = require "long_covid_parsing"

-- Extract items marked with {Required: Weekly} from parsed items
function M.get_weekly_required_items(parsed_items)
    -- If parsed_items is actually content string, parse it
    if type(parsed_items) == "string" then
        return parsing.parse_and_get_weekly_items(parsed_items)
    end
    
    local weekly_items = {}
    
    if not parsed_items then
        return weekly_items
    end
    
    for _, item in ipairs(parsed_items) do
        -- Check if item has weekly_required property
        if type(item) == "table" and item.weekly_required then
            table.insert(weekly_items, item)
        elseif type(item) == "string" then
            -- Simple string items won't have weekly metadata
            -- But we need to check the original content that was used to create these strings
            -- Since parse_activities just returns simple strings, we can't determine weekly status
            -- The test needs a different approach - it should pass the content directly
        end
    end
    
    return weekly_items
end

-- Check if weekly item needs to be logged (not logged in last 7 days)
function M.is_weekly_item_required(item_name, daily_logs)
    if not item_name or not daily_logs then
        return true -- Required if no logs
    end
    
    local last_7_dates = date_utils.get_last_n_dates(7)
    
    for _, date in ipairs(last_7_dates) do
        local day_logs = daily_logs[date]
        if day_logs then
            -- Check activities
            if day_logs.activities and day_logs.activities[item_name] and day_logs.activities[item_name] > 0 then
                return false -- Found in last 7 days
            end
            
            -- Check interventions
            if day_logs.interventions and day_logs.interventions[item_name] and day_logs.interventions[item_name] > 0 then
                return false -- Found in last 7 days
            end
            
            -- Check symptoms (though less likely for weekly tracking)
            if day_logs.symptoms and day_logs.symptoms[item_name] and day_logs.symptoms[item_name] > 0 then
                return false -- Found in last 7 days
            end
        end
    end
    
    return true -- Not found in last 7 days, so required
end

-- Check if a requirement info indicates weekly requirement (handles both old and new formats)
function M.is_weekly_requirement(required_info, daily_logs)
    -- Handle weekly requirements (new format: weekly_required=true)
    if required_info.weekly_required then
        -- Weekly items are only required when not logged in last 7 days
        if daily_logs then
            return M.is_weekly_item_required(required_info.name, daily_logs)
        else
            -- If no logs available, assume required (safe default)
            return true
        end
    end
    
    -- Handle weekly requirements (old format: days=["weekly"])
    if required_info.days and #required_info.days == 1 and required_info.days[1] == "weekly" then
        -- Weekly items are only required when not logged in last 7 days
        if daily_logs then
            return M.is_weekly_item_required(required_info.name, daily_logs)
        else
            -- If no logs available, assume required (safe default)
            return true
        end
    end
    
    return false -- Not a weekly requirement
end

-- Clean up daily logs but keep 7 days for weekly requirement checking
-- This is different from the general purge which keeps 30 days
function M.purge_for_weekly_tracking(daily_logs)
    if not daily_logs then
        return {}
    end
    
    local last_7_dates = date_utils.get_last_n_dates(7)
    local date_set = {}
    for _, date in ipairs(last_7_dates) do
        date_set[date] = true
    end
    
    local new_logs = {}
    for date, logs in pairs(daily_logs) do
        if date_set[date] then
            new_logs[date] = logs
        end
    end
    
    return new_logs
end

return M