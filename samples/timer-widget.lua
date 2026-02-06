-- type = "widget"
-- name = "Timer API example"
-- description = "Start/stop timers from script"

local widget_gui

local function build_ui(total, active)
    local state_text = timer:is_active() and "active" or "idle"
    local state_color = timer:is_active() and "#2E7D32" or "#616161"
    local progress = 0
    if total > 0 then
        progress = math.floor((active * 100) / total)
    end

    return {
        {"text", "<b>Timer API</b>", {size = 18}},
        {"spacer", 2},
        {"text", state_text, {color = state_color, gravity = "center_v"}},
        {"new_line", 1},
        {"text", "All timers: <b>" .. tostring(total) .. "</b>"},
        {"new_line", 1},
        {"text", "Active: <b>" .. tostring(active) .. "</b>"},
        {"new_line", 2},
        {"progress", "Active ratio", {progress = progress}},
        {"new_line", 2},
        {"button", "Start 1m", {expand = true}},
        {"spacer", 2},
        {"button", "Start 5m", {expand = true}},
        {"new_line", 2},
        {"button", "Stop all", {color = "#B71C1C", expand = true}},
    }
end

local function render()
    local timers = timer:list()
    local active = 0
    for i = 1, #timers do
        if timers[i].active then active = active + 1 end
    end

    widget_gui = gui(build_ui(#timers, active))
    widget_gui.render()
end

function on_load()
    render()
end

function on_resume()
    render()
end

function on_click(index)
    if not widget_gui or not widget_gui.ui or not widget_gui.ui[index] then
        return
    end

    local element = widget_gui.ui[index]
    if element[1] ~= "button" then
        return
    end

    local button_text = element[2]
    if button_text == "Start 1m" then
        timer:start(60 * 1000)
    elseif button_text == "Start 5m" then
        timer:start(5 * 60 * 1000)
    elseif button_text == "Stop all" then
        timer:stop_all()
    else
        return
    end

    render()
end
