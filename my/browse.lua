-- name = "Browse"
-- description = "Internet browsing and searching"
-- type = "widget"
-- author = "Paul Sztajer"
-- version = "0.1"

local prefs = require "prefs"

local w_vivaldi_bridge = nil
local vivaldi_provider = "com.vivaldi.browser/org.chromium.chrome.browser.searchwidget.SearchWidgetProvider"

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
        {"button", "fa:browser"},
        {"spacer", 1},
        {"button", "fa:magnifying-glass", {expand=true}},
        {"spacer", 1},
        {"button", "fa:robot", {expand=true}},
        {"spacer", 1},
        {"button", "fa:qrcode", { expand=false }},
    }
    my_gui.render()
end

function on_click(idx)
    if idx == 1 then
        w_vivaldi_bridge:click("h_layout_1")
    elseif idx == 3 then
        apps:launch("com.openai.chatgpt")
    elseif idx == 5 then
        apps:launch("com.anthropic.claude")
    elseif idx == 7 then
        w_vivaldi_bridge:click("image_2")
    end
end

function setup_vivaldi_widget()
    local id = widgets:setup(vivaldi_provider)
    if (id ~= nil) then
        prefs.vivaldi_wid = id
    else
        ui:show_text("Can't add vivaldi widget")
    end
end