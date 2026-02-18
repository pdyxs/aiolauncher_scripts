-- type = "widget"
-- name = "Recorder API example"
-- description = "Start/stop and manage voice notes"

local widget_gui

local function first_record()
    local items = recorder:list()
    if #items == 0 then return nil end
    return items[1]
end

local function build_ui(st, rec)
    local status_text = st.active and "recording" or "idle"
    local status_color = st.active and "#C62828" or "#616161"
    local ui_table = {
        {"text", "%%fa:microphone%%", {size = 18, color = status_color, gravity = "center_v"}},
        {"spacer", 2},
        {"text", "<b>Recorder API</b>", {size = 18, gravity = "center_v"}},
        {"spacer", 2},
        {"text", status_text, {color = status_color, gravity = "center_v"}},
        {"new_line", 1},
        {"text", "Records: <b>" .. tostring(st.records_count) .. "</b>"},
        {"new_line", 1},
    }

    if rec then
        table.insert(ui_table, {"text", "First: " .. tostring(rec.name)})
        table.insert(ui_table, {"new_line", 1})
        table.insert(ui_table, {"text", "Duration: " .. tostring(rec.duration) .. " ms"})
    else
        table.insert(ui_table, {"text", "No records yet", {color = "#757575"}})
    end

    table.insert(ui_table, {"new_line", 2})
    table.insert(ui_table, {"button", "Request permission", {expand = true}})
    table.insert(ui_table, {"new_line", 2})
    table.insert(ui_table, {"button", "Start", {color = "#2E7D32", expand = true}})
    table.insert(ui_table, {"spacer", 2})
    table.insert(ui_table, {"button", "Stop all", {color = "#B71C1C", expand = true}})
    table.insert(ui_table, {"new_line", 2})
    table.insert(ui_table, {"button", "Rename first", {expand = true}})
    table.insert(ui_table, {"spacer", 2})
    table.insert(ui_table, {"button", "Set color", {expand = true}})

    return ui_table
end

local function render()
    local st = recorder:state()
    local rec = first_record()
    widget_gui = gui(build_ui(st, rec))
    widget_gui.render()
end

function on_load()
    render()
end

function on_resume()
    render()
end

function on_click(index)
    if not widget_gui or not widget_gui.ui or not widget_gui.ui[index] then
        return
    end

    local element = widget_gui.ui[index]
    if element[1] ~= "button" then
        return
    end

    local button_text = element[2]
    if button_text == "Request permission" then
        recorder:request_permission()
    elseif button_text == "Start" then
        local res = recorder:start()
        if not res.ok then
            if res.error == "permission_denied" then
                recorder:request_permission()
                ui:show_toast("Grant microphone permission")
                return
            end
            ui:show_toast("Start failed: " .. tostring(res.error))
        end
    elseif button_text == "Stop all" then
        recorder:stop_all()
    elseif button_text == "Rename first" then
        local rec = first_record()
        if rec then
            recorder:rename(rec.id, "Voice " .. os.date("%H:%M:%S"))
        else
            ui:show_toast("No records")
        end
    elseif button_text == "Set color" then
        local rec = first_record()
        if rec then
            recorder:set_color(rec.id, 0xFF2196F3)
        else
            ui:show_toast("No records")
        end
    else
        return
    end

    render()
end

function on_permission_granted()
    ui:show_toast("Microphone permission granted")
    render()
end
