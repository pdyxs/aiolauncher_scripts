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

local components = {
    dialog_manager
}

local my_gui = nil
local widget_bridges = {} -- Maps widget names to their bridges
local widget_ids = {}     -- Maps widget providers to their widget IDs

function get_parsed_file_content()
    return prefs.parsed_content
end

function load_and_render()
    if not prefs.markdown_file_uri then
        ui:show_text("No markdown file URI set")
        return
    end
    ui:show_text("Loading file")
    local content = files:read_uri(prefs.markdown_file_uri)
    ui:show_text("Parsing file")
    local parsed_content = markdown_parser.parse(content)
    prefs.parsed_content = parsed_content

    if parsed_content then
        render(parsed_content)
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

function on_edit_mode_button_click(index)
    if index == 1 then
        obsidian.open_file(prefs.markdown_file_name)
    end
end

function render(content)
    ui:show_text(prefs.markdown_file_uri)
    ui:set_edit_mode_buttons({ "fa:file" })

    if not content or not content.attributes or not content.attributes.ui then
        ui:show_text("No UI defined in markdown file")
        return
    end

    setup_widgets(content)

    local ui_items = content.attributes.ui
    if not ui_items or #ui_items == 0 then
        ui:show_text("No UI items defined")
        return
    end

    -- Get the first UI attribute entry
    local ui_entry = ui_items[1]
    if not ui_entry.children then
        ui:show_text("No UI item children defined")
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

            table.insert(gui_elements, { "button", "fa:" .. icon_name, button_options })
        end

        -- Add spacer between buttons (but not after the last one)
        if i < #ui_entry.children then
            table.insert(gui_elements, { "spacer", 1 })
        end
    end

    -- Create and render the GUI
    my_gui = gui(gui_elements)
    my_gui.render()
end

function on_settings()
    files:pick_file("text/markdown")
end

function on_file_picked(uri, name)
    prefs.markdown_file_uri = uri
    prefs.markdown_file_name = name
    load_and_render()
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

    local content = get_parsed_file_content()
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

actions = {
    open = function(node)
        local package_name = node.children[1].text
        apps:launch(package_name)
    end,
    obsidian = function(node)
        local file_name = node.children[1].text
        obsidian.open_file(file_name)
    end,
    click = function(node)
        if node.children and #node.children > 0 then
            -- First child is the widget name, remaining are click actions
            local widget_name = node.children[1].text:lower()
            local bridge = widget_bridges[widget_name]

            if bridge then
                -- Collect remaining children as click actions
                local actions = {}
                for i = 2, #node.children do
                    table.insert(actions, node.children[i].text)
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
    end,
}

function on_click(idx)
    if not my_gui then return end

    local element = my_gui.ui[idx]
    if not element then return end

    if not prefs.markdown_file_path then return end
    local content = get_parsed_file_content()
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
                        if item.attributes then
                            for action_name, action_fn in pairs(actions) do
                                if item.attributes[action_name] then
                                    for _, entry in ipairs(item.attributes[action_name]) do
                                        action_fn(entry)
                                    end
                                end
                            end
                        end
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
