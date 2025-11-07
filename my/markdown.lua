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
local widget_bridges = {}  -- Maps widget names to their bridges
local widget_ids = {}      -- Maps widget providers to their widget IDs

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

function setup_widgets(content)
    -- Set up widgets from the Widgets attribute
    if not content or not content.attributes or not content.attributes.widgets then
        return
    end

    local widgets_entry = content.attributes.widgets[1]
    if not widgets_entry or not widgets_entry.attributes then
        return
    end

    -- Iterate through widget attributes (e.g., vivaldi, etc.)
    for widget_name, widget_entries in pairs(widgets_entry.attributes) do
        local widget_entry = widget_entries[1]
        if widget_entry.children and #widget_entry.children > 0 then
            local provider = widget_entry.children[1].text

            -- Check if we already have this widget bound
            local pref_key = "widget_id_" .. widget_name
            if not widgets:bound(prefs[pref_key]) then
                local id = widgets:setup(provider)
                if id ~= nil then
                    prefs[pref_key] = id
                    widget_ids[provider] = id
                end
            else
                widget_ids[provider] = prefs[pref_key]
            end
        end
    end
    
    -- Request updates for all widgets
    if content.attributes and content.attributes.widgets then
        local widgets_entry = content.attributes.widgets[1]
        if widgets_entry and widgets_entry.attributes then
            for widget_name, _ in pairs(widgets_entry.attributes) do
                local pref_key = "widget_id_" .. widget_name
                if prefs[pref_key] then
                    widgets:request_updates(prefs[pref_key])
                end
            end
        end
    end
end

function render(content)
    if not content or not content.attributes or not content.attributes.ui then
        return
    end

    setup_widgets(content)

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
    if not prefs.markdown_file_path then
        return
    end

    load_and_render()
    for _, component in ipairs(components) do
        if component.on_resume then
            component:on_resume()
        end
    end
end

function on_app_widget_updated(bridge)
    if not prefs.markdown_file_path then
        return
    end

    local content = file_manager:get(prefs.markdown_file_path..".md")
    if not content or not content.attributes or not content.attributes.widgets then
        return
    end

    local provider = bridge:provider()
    local widgets_entry = content.attributes.widgets[1]

    if widgets_entry and widgets_entry.attributes then
        -- Find which widget name this provider corresponds to
        for widget_name, widget_entries in pairs(widgets_entry.attributes) do
            local widget_entry = widget_entries[1]
            if widget_entry.children and #widget_entry.children > 0 then
                local widget_provider = widget_entry.children[1].text
                if widget_provider == provider then
                    widget_bridges[widget_name] = bridge
                    break
                end
            end
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

                        -- Check for 'click' attribute - clicks a widget
                        if item.attributes and item.attributes.click then
                            local click_entry = item.attributes.click[1]
                            if click_entry.children and #click_entry.children > 0 then
                                -- First child is the widget name, remaining are click actions
                                local widget_name = click_entry.children[1].text:lower()
                                local bridge = widget_bridges[widget_name]

                                if bridge then
                                    -- Collect remaining children as click actions
                                    local actions = {}
                                    for i = 2, #click_entry.children do
                                        table.insert(actions, click_entry.children[i].text)
                                    end

                                    -- Call click with actions
                                    if #actions > 0 then
                                        bridge:click(table.unpack(actions))
                                    else
                                        bridge:click()
                                    end
                                else
                                    debug:toast("Widget '" .. widget_name .. "' not found")
                                end
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