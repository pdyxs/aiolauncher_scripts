-- name = "Audio"
-- description = "Audio stuff"
-- type = "widget"
-- author = "Paul Sztajer"
-- version = "0.1"

local prefs = require "prefs"

local w_calm_bridge = nil
local calm_provider = "com.calm.android/com.calm.android.widgets.DailyCalmWidget"

function on_resume()
    if not widgets:bound(prefs.calm_wid) then
        setup_calm_widget()
    end

    widgets:request_updates(prefs.calm_wid)
end

function on_app_widget_updated(bridge)
    
    w_calm_bridge = bridge

    my_gui = gui{
        {"button", "fa:spa"},
        {"spacer", 1},
        {"button", "fa:music", {expand=true}},
        {"spacer", 1},
        {"button", "fa:microphone-stand", {expand=true}},
        {"spacer", 1},
        {"button", "fa:speakers", { expand=false }},
    }
    my_gui.render()
end

function on_click(idx)
    if idx == 1 then
        w_calm_bridge:click("v_layout_1")
    elseif idx == 3 then
        apps:launch("com.spotify.music")
    elseif idx == 5 then
        apps:launch("au.com.shiftyjelly.pocketcasts")
    elseif idx == 7 then
        apps:launch("com.sonos.acr2")
    end
end

function setup_calm_widget()
    local id = widgets:setup(calm_provider)
    if (id ~= nil) then
        prefs.calm_wid = id
    else
        ui:show_text("Can't add calm widget")
    end
end