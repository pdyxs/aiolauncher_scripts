-- name = "Habits"
-- description = "Wrapper around Habits app"
-- type = "widget"
-- author = "Paul Sztajer"
-- version = "1.0"

local prefs = require "prefs"

function setup_app_widget()
    local id = widgets:setup("org.isoron.uhabits/org.isoron.uhabits.widgets.CheckmarkWidgetProvider")
    if (id ~= nil) then
        prefs.wid = id
    else
        ui:show_text("Can't add widget")
    end
end

function on_resume()
    if not widgets:bound(prefs.wid) then
        setup_app_widget()
    end

    widgets:request_updates(prefs.wid)
end

function on_app_widget_updated(bridge)
    ui:show_text("Hi"..bridge:dump_json())
end

function on_click()
end
