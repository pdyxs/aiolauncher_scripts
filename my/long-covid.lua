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
local time_utils = require "core.time-utils"

local dialog_manager = dialog_flow.create_dialog_flow()

-- Colors for monochrome display
local COLOR_PRIMARY = "#333333"    -- Darkest
local COLOR_SECONDARY = "#666666"  -- Middle
local COLOR_TERTIARY = "#BBBBBB"   -- Lightest

------- CAPACITY LOGGING

function handle_capacity_click(button)
    -- Don't allow setting capacity if one is already set today
    if get_current_capacity() then
        return
    end

    dialog_manager:start({
        main = {
            type = "radio",
            title = "Capacity compared to yesterday",
            get_options = function()
                return {
                    "25%", "50%", "75%", "90%", "100%", "110%", "125%", "150%", "200%"
                }
            end,
            handle_result = function(results)
                set_capacity(button.name)
                morph:run_with_delay(1000, function()
                    logger.log_to_spreadsheet("Relative Capacity", results[#results].value)
                end)
            end
        }
    })
end

local capacity_buttons = {
    recovering = {
        label = "fa:bed",
        name = "Recovering",
        callback = handle_capacity_click,
        long_callback = function(button) reset_capacity() end
    },
    maintaining = {
        label = "fa:balance-scale",
        name = "Maintaining",
        callback = handle_capacity_click,
        long_callback = function(button) reset_capacity() end
    },
    engaging = {
        label = "fa:rocket-launch",
        name = "Engaging",
        callback = handle_capacity_click,
        long_callback = function(button) reset_capacity() end
    }
}

function set_capacity(capacity)
    prefs.capacity = capacity
    prefs.capacity_date = os.date("%Y-%m-%d")

    logger.log_to_spreadsheet("Capacity", capacity)

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

------- OTHER LOGGING

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
                    prefs.last_energy_log_time = time_utils.get_current_timestamp()
                    logger.log_to_spreadsheet("Energy", results[#results].index)
                    render_widget()
                end
            }
        }
    }
}

-------- RENDERING HELPERS

function get_energy_button_color()
    if not prefs.last_energy_log_time then
        -- Never logged today - PRIMARY
        return COLOR_PRIMARY
    end

    local current_time = time_utils.get_current_timestamp()

    -- Check if it's a different calendar day
    if not time_utils.is_same_calendar_day(prefs.last_energy_log_time, current_time) then
        -- Different calendar day - PRIMARY
        return COLOR_PRIMARY
    end

    local hours_since_last = time_utils.hours_between(prefs.last_energy_log_time, current_time)

    if hours_since_last >= 4 then
        -- 4+ hours since last log - SECONDARY
        return COLOR_SECONDARY
    else
        -- Logged within 4 hours - TERTIARY
        return COLOR_TERTIARY
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

------- RENDERING

function render_widget()
    local current_capacity = get_current_capacity()

    if current_capacity then
        render_capacity_selected()
    else
        render_select_capacity()
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
            {"button", selected_button.label, {color = COLOR_TERTIARY}},
            {"spacer", 3 },
            {"button", dialog_buttons.log_energy.label, {color = get_energy_button_color()}}
        }
        my_gui.render()
    end
end

------ AIO Functions

function on_resume()
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