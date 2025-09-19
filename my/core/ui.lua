local ui = {}

function ui.handle_button_click(gui_element, buttons)
    if not gui_element then return end

    local elem_type = gui_element[1]
    local elem_text = gui_element[2]

    for id, button in pairs(buttons) do
        if button.label == elem_text or elem_text:find(button.label:gsub("%%", "%%%%")) then
            button.callback()
            break
        end
    end
end

return ui