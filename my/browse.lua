-- name = "Browse"
-- description = "Internet browsing and searching"
-- type = "widget"
-- author = "Paul Sztajer"
-- version = "0.1"

local prefs = require "prefs"
local ui = require "core.ui"

local w_vivaldi_bridge = nil
local vivaldi_provider = "com.vivaldi.browser/org.chromium.chrome.browser.searchwidget.SearchWidgetProvider"

local buttons = {
    browser = {
        label = "fa:browser",
        callback = function()
            apps:launch("info.plateaukao.einkbro")
        end
    },
    claude = {
        label = "fa:robot",
        callback = function()
            apps:launch("com.anthropic.claude")
        end
    },
    reader = {
        label = "fa:bookmark",
        callback = function()
            apps:launch("com.readermobile")
        end
    },
    qr = {
        label = "fa:qrcode",
        callback = function()
            w_vivaldi_bridge:click("image_2")
        end
    }
}

function on_resume()
    if not widgets:bound(prefs.vivaldi_wid) then
        setup_vivaldi_widget()
    end

    widgets:request_updates(prefs.vivaldi_wid)
end

function on_app_widget_updated(bridge)
    
    if (bridge:provider() == vivaldi_provider) then
        w_vivaldi_bridge = bridge
    end

    my_gui = gui{
        {"button", buttons.browser.label},
        {"spacer", 1},
        {"button", buttons.reader.label, {expand=true}},
        {"spacer", 1},
        {"button", buttons.claude.label, {expand=true}},
        {"spacer", 1},
        {"button", buttons.qr.label, { expand=false }},
    }
    my_gui.render()
end

function on_click(idx)
    if not my_gui then return end
    
    local element = my_gui.ui[idx]
    if not element then return end
    
    ui.handle_button_click(element, buttons)
end

function setup_vivaldi_widget()
    local id = widgets:setup(vivaldi_provider)
    if (id ~= nil) then
        prefs.vivaldi_wid = id
    else
        ui:show_text("Can't add vivaldi widget")
    end
end