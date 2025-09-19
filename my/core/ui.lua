local ui = {}

function ui.matches_button_label(elem_text, button_label)
    -- Escape special pattern characters in button label
    local escaped_label = button_label:gsub("([%-%+%*%?%[%]%^%$%(%)%%])", "%%%1")
    return button_label == elem_text or elem_text:find(escaped_label)
end

function ui.handle_button_click(gui_element, buttons)
    if not gui_element then return end

    local elem_type = gui_element[1]
    local elem_text = gui_element[2]

    for id, button in pairs(buttons) do
        if ui.matches_button_label(elem_text, button.label) then
            button.callback(button)
            break
        end
    end
end

function ui.handle_button_long_click(gui_element, buttons)
    if not gui_element then return end

    local elem_type = gui_element[1]
    local elem_text = gui_element[2]

    for id, button in pairs(buttons) do
        if ui.matches_button_label(elem_text, button.label) then
            if button.long_callback then
                button.long_callback(button)
            end
            break
        end
    end
end

return ui