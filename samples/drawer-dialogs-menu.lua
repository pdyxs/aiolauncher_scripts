-- name = "Drawer Dialogs Sample"
-- description = "Example drawer script with several dialog types"
-- type = "drawer"
-- author = "Codex"
-- version = "1.0"
-- testing = "true"

local list = {
    "Confirm dialog",
    "Input dialog",
    "Radio dialog",
    "Checkbox dialog",
}

local icons = {
    "fa:circle-question",
    "fa:keyboard",
    "fa:list",
    "fa:square-check",
}

local dialog_id = ""

local radio_items = {"Red", "Green", "Blue"}
local checkbox_items = {"Alpha", "Beta", "Gamma", "Delta"}

function on_drawer_open()
    drawer:show_list(list, icons)
end

function on_click(idx)
    if idx == 1 then
        dialog_id = "confirm"
        dialogs:show_dialog("Confirm", "Do you want to proceed?", "Yes", "No")
    elseif idx == 2 then
        dialog_id = "input"
        dialogs:show_edit_dialog("Input", "Type any text", "")
    elseif idx == 3 then
        dialog_id = "radio"
        dialogs:show_radio_dialog("Pick a color", radio_items, 2)
    elseif idx == 4 then
        dialog_id = "checkbox"
        dialogs:show_checkbox_dialog("Pick any", checkbox_items, {1, 3})
    end
    return true
end

function on_dialog_action(value)
    if value == -1 then
        aio:show_toast("Cancelled")
        return
    end

    if dialog_id == "confirm" then
        if value == 1 then
            aio:show_toast("Confirmed")
        elseif value == 2 then
            aio:show_toast("Declined")
        end
    elseif dialog_id == "input" then
        if type(value) == "string" then
            if value == "" then
                aio:show_toast("Empty input")
            else
                aio:show_toast("Input: " .. value)
            end
        end
    elseif dialog_id == "radio" then
        if type(value) == "number" and radio_items[value] then
            aio:show_toast("Selected: " .. radio_items[value])
        end
    elseif dialog_id == "checkbox" then
        if type(value) == "table" then
            if #value == 0 then
                aio:show_toast("Nothing selected")
                return
            end
            local parts = {}
            for i, v in ipairs(value) do
                parts[i] = checkbox_items[v] or ("#" .. tostring(v))
            end
            aio:show_toast("Selected: " .. table.concat(parts, ", "))
        end
    end
end
