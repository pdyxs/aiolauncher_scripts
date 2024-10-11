-- name = "Habits"
-- description = "Wrapper around Habits app"
-- type = "widget"
-- author = "Paul Sztajer"
-- version = "1.0"

local prefs = require "prefs"

local w_bridge = nil
local habits = {}

function setup_app_widget()
    local id = widgets:setup("com.ticktick.task/com.ticktick.task.activity.widget.AppWidgetProviderHabit")
    if (id ~= nil) then
        prefs.widget = id
    else
        ui:show_text("Can't add widget")
    end
end

function on_resume()
    if not widgets:bound(prefs.widget) then
        setup_app_widget()
    end

    widgets:request_updates(prefs.widget)
end

function on_app_widget_updated(bridge)
    habits = {}

    local tree = bridge:dump_table().relative_layout_1.frame_layout_1.h_layout_1.list_layout_1
    local i = 1
    while tree["frame_layout_"..(i*2)] do
        local habitTree = tree["frame_layout_"..(i*2)]["h_layout_"..(i*2)]["frame_layout_"..(i*2+1)]["h_layout_"..(i*2+1)]
        local habitName = habitTree["v_layout_"..i]["text_"..(i*2-1)]
        local habitImage = habitTree["image_"..(i*2+1)]
        table.insert(habits, {name=habitName, complete=(habitImage=="54x54")})
        i = i + 1
    end

    local buttons = {}
    local colours = {}
    local progress = 0
    for i, habit in pairs(habits) do
        table.insert(buttons, (habit.complete and "✔️" or "▪️")..habit.name)
        if habit.complete then
            table.insert(colours, "#DDDDDD")
            progress = progress + 1
        else
            table.insert(colours, "#333333")
        end
    end

    ui:show_buttons(buttons, colours)
    ui:set_progress(progress / #buttons)

    w_bridge = bridge
end

function on_click(idx)
    w_bridge:click("image_"..(idx*2+1))
end
