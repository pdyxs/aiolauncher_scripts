-- name = "Confirm Dialog Button"
-- description = "Shows a button that opens a confirm dialog"
-- type = "search"
-- author = "Codex"
-- version = "1.0"

function on_search(input)
    search:show_buttons({"Open confirm dialog"})
end

function on_click(idx)
    dialogs:show_dialog("Confirm", "Do you want to proceed?", "Yes", "No")
end

function on_dialog_action(value)
    if value == 1 or value == 2 then
        aio:show_toast("Button: "..value)
    end
end
