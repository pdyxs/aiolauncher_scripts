-- name = "Markdown"
-- description = "A widget based on a markdown file"
-- type = "widget"
-- author = "Paul Sztajer"
-- version = "0.1"

local dialog_flow = require "core.dialog-flow"
local markdown_parser = require "core.markdown-parser"
local obsidian = require "core.obsidian"
local prefs = require "prefs"

local dialog_manager = dialog_flow.create_dialog_flow(function() end)
local file_manager = (require "core.file-manager").create()

local components = {
    file_manager,
    dialog_manager
}

local my_gui = nil

function load_and_render()
    if not prefs.markdown_file_path then
        return
    end
    local file_path = prefs.markdown_file_path
    file_manager:load(file_path..".md", render, markdown_parser)

    if prefs.render_error then
        return
    end

    local content = file_manager:get(file_path..".md")
    if content then
        prefs.render_error = true
        render(content)
        prefs.render_error = nil
    end
end

function render(content)
    if not content or not content.attributes or not content.attributes.ui then
        return
    end

    local ui_items = content.attributes.ui
    if not ui_items or #ui_items == 0 then
        return
    end

    -- Get the first UI attribute entry
    local ui_entry = ui_items[1]
    if not ui_entry.children then
        return
    end

    -- Build the GUI elements
    local gui_elements = {}

    for i, item in ipairs(ui_entry.children) do
        -- Add button with icon
        local icon_name = item.icon
        if icon_name then
            -- Convert underscores to hyphens for FontAwesome compatibility
            icon_name = icon_name:gsub("_", "-")

            local button_options = {}

            -- Check for expand attribute
            if item.attributes and item.attributes.expand then
                button_options.expand = true
            end

            table.insert(gui_elements, {"button", "fa:" .. icon_name, button_options})
        end

        -- Add spacer between buttons (but not after the last one)
        if i < #ui_entry.children then
            table.insert(gui_elements, {"spacer", 1})
        end
    end

    -- Create and render the GUI
    my_gui = gui(gui_elements)
    my_gui.render()
end

function on_settings()
    dialog_manager:start({
        main = {
            type = "edit",
            title = "Choose a Markdown File",
            default_text = prefs.markdown_file_path or "Documents/",
            handle_result = function(results)
                local file_path = results[#results]
                prefs.markdown_file_path = file_path
                load_and_render()
            end
        }
    })
end

function on_dialog_action(result)
    for _, component in ipairs(components) do
        if component.on_dialog_action then
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
    load_and_render()
    for _, component in ipairs(components) do
        if component.on_resume then
            component:on_resume()
        end
    end
end

function matches_button_label(elem_text, button_label)
    -- Escape special pattern characters in button label
    local escaped_label = button_label:gsub("([%-%+%*%?%[%]%^%$%(%)%%])", "%%%1")
    return button_label == elem_text or elem_text:find(escaped_label)
end

function on_click(idx)
    if not my_gui then return end

    local element = my_gui.ui[idx]
    if not element then return end

    if not prefs.markdown_file_path then return end
    local content = file_manager:get(prefs.markdown_file_path..".md")
    if content and content.attributes and content.attributes.ui then
        local ui_entry = content.attributes.ui[1]
        if ui_entry and ui_entry.children then
            local elem_text = element[2]

            -- Find the matching UI item by button label
            for _, item in ipairs(ui_entry.children) do
                if item.icon then
                    local button_label = "fa:" .. item.icon:gsub("_", "-")
                    if matches_button_label(elem_text, button_label) then
                        -- Found matching item, handle the click based on attributes

                        -- Check for 'open' attribute - opens an app
                        if item.attributes and item.attributes.open then
                            local open_entry = item.attributes.open[1]
                            if open_entry.children and #open_entry.children > 0 then
                                local package_name = open_entry.children[1].text
                                apps:launch(package_name)
                                return
                            end
                        end

                        -- Check for 'obsidian' attribute - opens Obsidian file
                        if item.attributes and item.attributes.obsidian then
                            local obsidian_entry = item.attributes.obsidian[1]
                            if obsidian_entry.children and #obsidian_entry.children > 0 then
                                local file_path = obsidian_entry.children[1].text
                                obsidian.open_file(file_path)
                                return
                            end
                        end

                        -- Check for 'click' attribute - clicks a widget (stub)
                        if item.attributes and item.attributes.click then
                            local click_entry = item.attributes.click[1]
                            if click_entry.children and #click_entry.children > 0 then
                                -- TODO: Implement widget click functionality
                                -- Format: widget_name, action (e.g., "Vivaldi, image_2")
                                local widget_info = {}
                                for _, child in ipairs(click_entry.children) do
                                    table.insert(widget_info, child.text)
                                end
                                -- Stub: debug:toast("Click widget: " .. table.concat(widget_info, ", "))
                                return
                            end
                        end

                        return
                    end
                end
            end
        end
    end

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