local plan_parser = {}

function plan_parser.parse_plan(plan_text)
    local date_pattern = "^(%d%d%d%d)%-(%d%d)%-(%d%d): (.+)$"
    local year, month, day, plan = string.match(plan_text, date_pattern)

    if not year then
        return plan_text, false
    end

    local formatted_date = string.format("%02d/%02d/%02d", tonumber(day), tonumber(month), tonumber(year) % 100)

    local current_date = os.date("*t")
    local plan_date = os.time({year = tonumber(year), month = tonumber(month), day = tonumber(day)})
    local today = os.time({year = current_date.year, month = current_date.month, day = current_date.day})

    if plan_date <= today then
        return "‼️ " .. formatted_date .. ": ‼️ " .. plan, true
    else
        return formatted_date .. ": " .. plan, false
    end
end

return plan_parser