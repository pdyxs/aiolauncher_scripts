-- name = "Echo Chat (Search)"
-- description = "Shows a chat button for any query and echoes user messages."
-- type = "search"
-- author = "Example"
-- version = "1.0"

local function last_user_message(messages)
    for i = #messages, 1, -1 do
        local msg = messages[i]
        if msg and msg.role == "user" then
            return msg.content or ""
        end
    end
    return ""
end

function on_search(query)
    search:show_buttons({ "Chat mode" })
end

function on_click(idx)
    search:chat_start("Echo chat", "Write to me and I'll answer!", "fa:message")
    return false
end

function on_chat(messages)
    local text = last_user_message(messages)
    if text == "exit" then
        search:chat_stop()
    else
        return "You said: " .. text
    end
end
