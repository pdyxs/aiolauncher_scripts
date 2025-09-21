local M = {}

function M.get_current_timestamp()
    return os.time()
end

function M.is_same_calendar_day(timestamp1, timestamp2)
    if not timestamp1 or not timestamp2 then
        return false
    end

    local date1 = os.date("*t", timestamp1)
    local date2 = os.date("*t", timestamp2)

    return date1.year == date2.year and date1.yday == date2.yday
end

function M.is_same_week(timestamp1, timestamp2)
    if not timestamp1 or not timestamp2 then
        return false
    end

    -- Calculate days since epoch for each date
    local days1 = math.floor(timestamp1 / 86400)
    local days2 = math.floor(timestamp2 / 86400)

    -- Check if the absolute difference is 6 days or less
    return math.abs(days1 - days2) <= 6
end

function M.is_day_of_week(timestamp, days_array)
    if not timestamp or not days_array or #days_array == 0 then
        return false
    end

    local date = os.date("*t", timestamp)
    local weekday = date.wday -- 1=Sunday, 2=Monday, ..., 7=Saturday

    -- Convert numeric weekday to day name
    local day_names = {"sunday", "monday", "tuesday", "wednesday", "thursday", "friday", "saturday"}
    local actual_day = day_names[weekday]

    -- Check if actual day matches any in the array
    for _, day in ipairs(days_array) do
        local normalized_day = string.lower(day)
        if #normalized_day >= 3 and string.sub(actual_day, 1, #normalized_day) == normalized_day then
            return true
        end
    end

    return false
end

function M.hours_between(timestamp1, timestamp2)
    if not timestamp1 or not timestamp2 then
        return nil
    end

    return math.abs(timestamp2 - timestamp1) / 3600
end

function M.format_time(timestamp)
    if not timestamp then
        return "Never"
    end

    return os.date("%H:%M", timestamp)
end

function M.format_time_ago(timestamp)
    if not timestamp then
        return "Never logged"
    end

    local current_time = os.time()
    local hours_ago = M.hours_between(timestamp, current_time)

    if hours_ago < 1 then
        local minutes_ago = math.floor((current_time - timestamp) / 60)
        return minutes_ago .. "m ago"
    elseif hours_ago < 24 then
        return math.floor(hours_ago) .. "h ago"
    else
        local days_ago = math.floor(hours_ago / 24)
        return days_ago .. "d ago"
    end
end

return M