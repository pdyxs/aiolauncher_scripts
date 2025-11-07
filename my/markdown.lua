-- name = "Markdown"
-- description = "A widget based on a markdown file"
-- type = "widget"
-- author = "Paul Sztajer"
-- version = "0.1"

local md_manager = require "my.core.markdown-manager"
local dialog_flow = require "core.dialog-flow"

local dialog_manager = dialog_flow.create_dialog_flow(function() end)
local markdown_manager = md_manager.create()

local components = {
    markdown_manager,
    dialog_manager
}

local my_gui = nil

function on_settings()

end

function on_dialog_action(result)
    for _, component in ipairs(components) do
        if component.on_load then
            component:on_dialog_action(result)
        end
    end
end

function on_load()
    for _, component in ipairs(components) do
        if component.on_load then
            component:on_load()
        end
    end
end

function on_command(data)
    for _, component in ipairs(components) do
        if component.on_command then
            component:on_command(data)
        end
    end
end

function on_resume()
    for _, component in ipairs(components) do
        if component.on_resume then
            component:on_resume()
        end
    end
end

function on_click(idx)
    if not my_gui then return end
    
    local element = my_gui.ui[idx]
    if not element then return end

    for _, component in ipairs(components) do
        if component.on_click then
            component:on_click(element, idx)
        end
    end
end

function on_long_click(idx)
    if not my_gui then return end
    
    local element = my_gui.ui[idx]
    if not element then return end

    for _, component in ipairs(components) do
        if component.on_long_click then
            component:on_long_click(element, idx)
        end
    end
end