-- name = "Capacity Logger"
-- description = "Logging Capacity"
-- type = "widget"
-- author = "Paul Sztajer"
-- version = "0.1"
-- icon = "shield-virus"

local function ms(year, month, day, hour, min, sec)
    return os.time({ year = year, month = month, day = day, hour = hour or 0, min = min or 0, sec = sec or 0 }) * 1000
end

local levels = {
    { name = "5-", value = 1 / 2 },
    { name = "4-", value = 1 / 1.5 },
    { name = "3-", value = 1 / 1.2 },
    { name = "2-", value = 1 / 1.1 },
    { name = "-",  value = 1 / 1.05 },
    { name = "=",  value = 1 },
    { name = "+",  value = 1.05 },
    { name = "2+", value = 1.1 },
    { name = "3+", value = 1.2 },
    { name = "4+", value = 1.5 },
    { name = "5+", value = 2 },
}

local prefs = require "prefs"
local logger = require "core.log-via-tasker"

local function date_key(d)
    return os.date("%Y-%m-%d", os.time(d))
end

local function load_points()
    local stored = prefs.capacity_points or {}
    local pts = {}
    local today = os.time()
    for i = 6, 0, -1 do
        local t = today - i * 86400
        local d = os.date("*t", t)
        local key = os.date("%Y-%m-%d", t)
        local level = stored[key] or "="
        table.insert(pts, { { year = d.year, month = d.month, day = d.day, hour = 0, min = 0, sec = 0 }, level })
    end
    return pts
end

local points = load_points()

local function save_points()
    local stored = prefs.capacity_points or {}
    for _, p in ipairs(points) do
        stored[date_key(p[1])] = p[2]
    end
    prefs.capacity_points = stored
end

local is_editing = false
local is_previewing = false
local original_levels = {}

function render()
    if is_editing and not is_previewing then
        render_edit()
    else
        render_chart()
    end
end

function level_index(name)
    for i, l in ipairs(levels) do
        if l.name == name then return i end
    end
    return 6 -- default "="
end

function render_edit()
    local elements = {}

    for i, p in ipairs(points) do
        local date_str = os.date("%d/%m", os.time(p[1]))
        local lvl_name = p[2]

        -- date
        table.insert(elements, { "text", date_str, { size = 14, gravity = "center_h" } })
        if i < #points then table.insert(elements, { "spacer", 2 }) end
    end
    table.insert(elements, { "new_line", 1 })

    for i, p in ipairs(points) do
        -- increase button
        table.insert(elements, { "button", "fa:chevron-up", { expand = true } })
        if i < #points then table.insert(elements, { "spacer", 2 }) end
    end
    table.insert(elements, { "new_line", 1 })

    for i, p in ipairs(points) do
        -- current level
        table.insert(elements, { "button", p[2], { expand = true, color = "#ffffff" } })
        if i < #points then table.insert(elements, { "spacer", 2 }) end
    end
    table.insert(elements, { "new_line", 1 })

    for i, p in ipairs(points) do
        -- decrease button
        table.insert(elements, { "button", "fa:chevron-down", { expand = true } })
        if i < #points then table.insert(elements, { "spacer", 2 }) end
    end

    gui(elements):render()
end

function render_chart()
    local level_map = {}
    for _, l in ipairs(levels) do
        level_map[l.name] = l.value
    end

    local chart_points = {}
    local current = 1
    table.insert(chart_points, { os.time(points[1][1]) * 1000, 0 })
    for _, p in ipairs(points) do
        local t = os.time(p[1]) * 1000
        local multiplier = level_map[p[2]] or 1
        current = current * multiplier
        table.insert(chart_points, { t, current })
    end
    ui:show_chart(chart_points, "x:date y:none")
end

function on_resume()
    points = load_points()
    render()
end

local last_ticks = 0
local preview_ticks = 0;

function on_tick(ticks)
    last_ticks = ticks
    if is_previewing then
        is_previewing = false
        render()
    end
end

function on_click(idx)
    if is_previewing then
        is_previewing = false
        render()
        return
    end
    if not is_editing then
        is_editing = true
        for i, p in ipairs(points) do
            original_levels[i] = p[2]
        end
        render()
        return
    end

    local n = #points
    -- row offsets: row1 = 0, row2 = 2*n, row3 = 4*n, row4 = 6*n
    -- within a row, element for point i is at offset 2*(i-1)+1 (1-based)
    for i = 1, n do
        local up_idx = 2 * n + 2 * (i - 1) + 1
        local down_idx = 6 * n + 2 * (i - 1) + 1
        if idx == up_idx then
            local li = level_index(points[i][2])
            if li < #levels then
                points[i][2] = levels[li + 1].name
                save_points()
            end
            is_previewing = true
            preview_ticks = last_ticks
            render()
            return
        elseif idx == down_idx then
            local li = level_index(points[i][2])
            if li > 1 then
                points[i][2] = levels[li - 1].name
                save_points()
            end
            is_previewing = true
            preview_ticks = last_ticks
            render()
            return
        end
    end

    -- exiting edit mode: log any changes
    local events = {}
    for i, p in ipairs(points) do
        if p[2] ~= original_levels[i] then
            local li = level_index(p[2])
            table.insert(events, { "Capacity", date_key(p[1]), tostring(levels[li].value) })
        end
    end
    if #events > 0 then
        logger.log_events_to_spreadsheet(events)
    end

    is_editing = false
    render()
end
