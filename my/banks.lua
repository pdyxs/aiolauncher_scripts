-- name = "Banking Widget"
-- description = "Show my banking info"
-- type = "widget"
-- author = "Paul Sztajer"
-- version = "0.1"

local prefs = require "prefs"

local w_ing_bridge = nil
local w_up_bridge = nil

local ing_balance = nil
local up_balance = nil

function on_resume()
    if not widgets:bound(prefs.ing_wid) then
        setup_ing_widget()
    end

    if not widgets:bound(prefs.up_wid) then
        setup_up_widget()
    end

    widgets:request_updates(prefs.ing_wid)
    widgets:request_updates(prefs.up_wid)
end

function on_app_widget_updated(bridge)
    local strings = bridge:dump_strings().values

    is_ING = strings[1] == "ING"

    if is_ING then
        w_ing_bridge = bridge
        local buttons = bridge:dump_elements("button").values
        if buttons[1] == "REFRESH" then
            ing_balance = string.sub(strings[4],4,string.len(strings[4]) - 4)
        else
            ing_balance = "..."
        end
    else
        w_up_bridge = bridge
        up_balance = strings[1]
    end

    my_gui = gui{
        {"button", "%%fa:triangle%% "..(up_balance or "??")},
        {"new_line", 1},
        {"button", "%%fa:paw-claws%% "..(ing_balance or "??")},
        {"spacer", 1},
        {"button", "fa:rotate-right"},
    }
    my_gui.render()
end

function on_click(idx)
    if idx == 3 then
        w_ing_bridge:click("button_2")
    elseif idx == 5 then
        w_ing_bridge:click("button_1")
    elseif idx == 1 then
        apps:launch("au.com.up.money")
    end
end

function setup_up_widget()
    local id = widgets:setup("au.com.up.money/au.com.up.money.widgets.AccountOverviewWidget")
    if (id ~= nil) then
        prefs.up_wid = id
    else
        ui:show_text("Can't add widget")
    end
end

function setup_ing_widget()
    local ing_widgets = widgets:list("au.com.ingdirect.android")
    local id = widgets:setup(ing_widgets[1].provider)
    if (id ~= nil) then
        prefs.ing_wid = id
    else
        ui:show_text("Can't add widget")
    end
end
