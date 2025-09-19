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