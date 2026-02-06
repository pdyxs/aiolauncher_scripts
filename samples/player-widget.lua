-- type = "widget"
-- name = "Player API example"
-- description = "Control active media session"

local my_gui

local function render()
    local st = player:state()
    local package_name = st.package ~= "" and st.package or "none"
    local song = st.song ~= "" and st.song or "unknown"
    local is_playing = st.is_playing == true
    local play_pause_icon = is_playing and "fa:pause" or "fa:play"

    my_gui = gui{
        {"icon", "fa:music", {size = 16, color = "#888888", gravity = "center_v"}},
        {"spacer", 2},
        {"text", "Player: " .. package_name, {gravity = "center_v|anchor_prev"}},
        {"new_line", 1},
        {"text", "Song: " .. song},
        {"new_line", 1},
        {"text", "State: " .. (is_playing and "playing" or "paused"), {color = is_playing and "#4CAF50" or "#888888"}},
        {"new_line", 2},
        {"button", "fa:backward-step", {expand = true}},
        {"spacer", 2},
        {"button", play_pause_icon, {expand = true}},
        {"spacer", 2},
        {"button", "fa:forward-step", {expand = true}},
        {"spacer", 2},
        {"button", "fa:stop", {expand = true, color = "#D9534F"}},
    }

    my_gui.render()
end

function on_resume()
    render()
end

function on_tick()
    render()
end

function on_click(index)
    if my_gui == nil or my_gui.ui == nil or my_gui.ui[index] == nil then
        return
    end

    local item = my_gui.ui[index]
    if item[1] ~= "button" then
        return
    end

    local action = item[2]

    if action == "fa:backward-step" then
        player:prev()
    elseif action == "fa:play" or action == "fa:pause" then
        player:play_pause()
    elseif action == "fa:forward-step" then
        player:next()
    elseif action == "fa:stop" then
        player:stop()
    end

    render()
end
