-- name = "Long Covid"
-- description = "Long Covid management widget"
-- type = "widget"
-- author = "Paul Sztajer"
-- version = "0.1"
-- icon = "shield-virus"

local prefs = require "prefs"
local ui_core = require "core.ui"
local logger = require "core.log-via-tasker"
local dialog_flow = require "core.dialog-flow"
local util = require "core.util"

local dialog_manager = dialog_flow.create_dialog_flow()

-- Colors for monochrome display
local COLOR_PRIMARY = "#333333"    -- Darkest
local COLOR_SECONDARY = "#666666"  -- Middle
local COLOR_TERTIARY = "#BBBBBB"   -- Lightest

local capacity_buttons = {
    recovering = {
        label = "fa:bed",
        name = "Recovering",
        callback = function(button) set_capacity(button.name) end,
        long_callback = function(button) reset_capacity() end
    },
    maintaining = {
        label = "fa:balance-scale",
        name = "Maintaining",
        callback = function(button) set_capacity(button.name) end,
        long_callback = function(button) reset_capacity() end
    },
    engaging = {
        label = "fa:rocket-launch",
        name = "Engaging",
        callback = function(button) set_capacity(button.name) end,
        long_callback = function(button) reset_capacity() end
    }
}

local dialog_buttons = {
    log_energy = {
        label = "fa:bolt",
        callback = function(button) dialog_manager:start(button.dialogs) end,
        dialogs = {
            main = {
                type = "radio",
                title = "Log Energy Level",
                get_options = function()
                    return {
                        "1 - Completely drained", "2 - Very low", "3 - Low", "4 - Below average", 
                        "5 - Average", "6 - Above average", "7 - Good", "8 - Very good", 
                        "9 - Excellent", "10 - Peak energy"
                    }
                end,
                handle_result = function(results)
                    local timestamp = os.date("%Y-%m-%d %H:%M:%S")
                    logger.log_to_spreadsheet(timestamp, "Energy", results[#results].index, nil, function(message) ui:show_toast(message) end)
                end
            }
        }
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

    ui_core.handle_button_click(element, util.tables_to_array(capacity_buttons, dialog_buttons))
end

function on_dialog_action(result)
    dialog_manager:handle_result(result)
end

function on_long_click(idx)
    if not my_gui then return end

    local element = my_gui.ui[idx]
    if not element then return end

    ui_core.handle_button_long_click(element, capacity_buttons)
end

function set_capacity(capacity)
    -- Don't allow setting capacity if one is already set today
    if get_current_capacity() then
        return
    end

    prefs.capacity = capacity
    prefs.capacity_date = os.date("%Y-%m-%d")

    -- Log to spreadsheet (capacity buttons don't use detail column)
    local timestamp = os.date("%Y-%m-%d %H:%M:%S")
    logger.log_to_spreadsheet(timestamp, "Capacity", capacity, nil, function(message) ui:show_toast(message) end)

    render_widget()
end

function reset_capacity()
    prefs.capacity = nil
    prefs.capacity_date = nil

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

function get_capacity_button_display(button)
    local current_capacity = get_current_capacity()

    -- Show name if no selection made OR this button is selected
    if not current_capacity or current_capacity == button.name then
        return "%%" .. button.label .. "%% " .. button.name
    else
        return button.label
    end
end

function render_select_capacity()
    -- Show all buttons when no capacity is set
    my_gui = gui{
        {"button", get_capacity_button_display(capacity_buttons.recovering), {color = COLOR_PRIMARY, gravity = "center_h"}},
        {"spacer", 1},
        {"button", get_capacity_button_display(capacity_buttons.maintaining), {color = COLOR_PRIMARY, gravity = "anchor_prev"}},
        {"spacer", 1},
        {"button", get_capacity_button_display(capacity_buttons.engaging), {color = COLOR_PRIMARY, gravity = "anchor_prev"}}
    }
    my_gui.render()
end

function render_capacity_selected()
    local current_capacity = get_current_capacity()

    -- Find and show only the selected capacity button
    local selected_button
    for _, button in pairs(capacity_buttons) do
        if button.name == current_capacity then
            selected_button = button
            break
        end
    end

    if selected_button then
        my_gui = gui{
            {"button", selected_button.label, {color = COLOR_PRIMARY}},
            {"spacer", 3 },
            {"button", dialog_buttons.log_energy.label, {color = COLOR_PRIMARY}}
        }
        my_gui.render()
    end
end

function render_widget()
    local current_capacity = get_current_capacity()

    if current_capacity then
        render_capacity_selected()
    else
        render_select_capacity()
    end
end