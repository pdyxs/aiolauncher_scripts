-- Long Covid Widget - Date Utilities Module
-- Handles all date and time related calculations

local M = {}

function M.get_current_day()
    local day_names = {"sunday", "monday", "tuesday", "wednesday", "thursday", "friday", "saturday"}
    local today = day_names[tonumber(os.date("%w")) + 1]
    return today
end

function M.get_current_day_abbrev()
    local day_abbrevs = {"sun", "mon", "tue", "wed", "thu", "fri", "sat"}
    return day_abbrevs[tonumber(os.date("%w")) + 1]
end

function M.get_today_date()
    return os.date("%Y-%m-%d")
end

-- Calculate date N days ago from today
function M.get_date_days_ago(days_ago)
    -- Input validation
    if type(days_ago) ~= "number" or days_ago < 0 then
        return nil
    end
    
    if days_ago == 0 then
        return os.date("%Y-%m-%d")
    end
    
    -- Get today's date using the (possibly mocked) os.date
    local today = os.date("%Y-%m-%d")
    
    -- Parse today's date
    local year, month, day = today:match("(%d+)-(%d+)-(%d+)")
    if not year then
        return nil
    end
    
    year, month, day = tonumber(year), tonumber(month), tonumber(day)
    
    -- Convert to timestamp for easy calculation
    local today_time = os.time({year = year, month = month, day = day})
    local seconds_ago = days_ago * 24 * 60 * 60  -- Convert days to seconds
    local target_time = today_time - seconds_ago
    
    -- Format as YYYY-MM-DD
    return os.date("%Y-%m-%d", target_time)
end

-- Return array of last N calendar dates including today
function M.get_last_n_dates(n)
    -- Input validation
    if type(n) ~= "number" or n < 0 then
        return {}
    end
    
    if n == 0 then
        return {}
    end
    
    local dates = {}
    for i = 0, n - 1 do
        local date = M.get_date_days_ago(i)
        if date then
            table.insert(dates, date)
        end
    end
    
    return dates
end

return M