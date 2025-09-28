-- name = "Audio"
-- description = "Audio stuff"
-- type = "widget"
-- author = "Paul Sztajer"
-- version = "0.1"

local prefs = require "prefs"
local ui = require "core.ui"

local w_calm_bridge = nil
local calm_provider = "com.calm.android/com.calm.android.widgets.DailyCalmWidget"

local buttons = {
    calm = {
        label = "fa:spa",
        callback = function() w_calm_bridge:click("v_layout_1") end
    },
    spotify = {
        label = "fa:music",
        callback = function() apps:launch("com.spotify.music") end
    },
    pocketcasts = {
        label = "fa:microphone-stand",
        callback = function() apps:launch("au.com.shiftyjelly.pocketcasts") end
    },
    sonos = {
        label = "fa:speakers",
        callback = function() apps:launch("com.sonos.acr2") end
    },
    headphones = {
        label = "fa:headphones",
        callback = function() apps:launch("com.sonova.chb.control") end
    }
}

function on_resume()
    if not widgets:bound(prefs.calm_wid) then
        setup_calm_widget()
    end

    widgets:request_updates(prefs.calm_wid)
end

function on_app_widget_updated(bridge)
    
    w_calm_bridge = bridge

    my_gui = gui{
        {"button", buttons.calm.label},
        {"spacer", 1},
        {"button", buttons.spotify.label, {expand=true}},
        {"spacer", 1},
        {"button", buttons.pocketcasts.label, {expand=true}},
        {"spacer", 1},
        {"button", buttons.headphones.label, { expand=false }},
        {"spacer", 1},
        {"button", buttons.sonos.label, { expand=false }},
    }
    my_gui.render()
end

function on_click(idx)
    if not my_gui then return end

    local element = my_gui.ui[idx]
    if not element then return end

    ui.handle_button_click(element, buttons)
end

function setup_calm_widget()
    local id = widgets:setup(calm_provider)
    if (id ~= nil) then
        prefs.calm_wid = id
    else
        ui:show_text("Can't add calm widget")
    end
end