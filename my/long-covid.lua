-- name = "Long Covid"
-- description = "Long Covid management widget"
-- type = "widget"
-- author = "Paul Sztajer"
-- version = "0.1"

local prefs = require "prefs"
local ui = require "core.ui"

-- Button colors for monochrome display
local BUTTON_COLOR_SELECTED = "#333333"    -- Darkest
local BUTTON_COLOR_NONE = "#666666"        -- Middle
local BUTTON_COLOR_UNSELECTED = "#999999"  -- Lightest

local buttons = {
    recovering = {
        label = "fa:bed",
        name = "Recovering",
        callback = function(button) set_capacity(button.name) end
    },
    maintaining = {
        label = "fa:balance-scale",
        name = "Maintaining",
        callback = function(button) set_capacity(button.name) end
    },
    engaging = {
        label = "fa:bolt",
        name = "Engaging",
        callback = function(button) set_capacity(button.name) end
    }
}

function on_resume()
    check_new_day()
    render_widget()
end

function on_click(idx)
    if not my_gui then return end

    local element = my_gui.ui[idx]
    if not element then return end

    ui.handle_button_click(element, buttons)
end

function set_capacity(capacity)
    prefs.capacity = capacity
    prefs.capacity_date = os.date("%Y-%m-%d")
    render_widget()
end

function get_current_capacity()
    local today = os.date("%Y-%m-%d")
    if prefs.capacity_date == today then
        return prefs.capacity
    end
    return nil
end

function check_new_day()
    local today = os.date("%Y-%m-%d")
    if prefs.capacity_date ~= today then
        prefs.capacity = nil
        prefs.capacity_date = nil
    end
end

function get_button_display(button)
    local current_capacity = get_current_capacity()

    -- Show name if no selection made OR this button is selected
    if not current_capacity or current_capacity == button.name then
        return "%%" .. button.label .. "%% " .. button.name
    else
        return button.label
    end
end

function get_button_color(button)
    local current_capacity = get_current_capacity()

    if current_capacity == button.name then
        return BUTTON_COLOR_SELECTED
    elseif not current_capacity then
        return BUTTON_COLOR_NONE
    else
        return BUTTON_COLOR_UNSELECTED
    end
end

function render_widget()
    my_gui = gui{
        {"button", get_button_display(buttons.recovering), {color = get_button_color(buttons.recovering), gravity = "center_h"}},
        {"spacer", 1},
        {"button", get_button_display(buttons.maintaining), {color = get_button_color(buttons.maintaining), gravity = "anchor_prev"}},
        {"spacer", 1},
        {"button", get_button_display(buttons.engaging), {color = get_button_color(buttons.engaging), gravity = "anchor_prev"}}
    }
    my_gui.render()
end