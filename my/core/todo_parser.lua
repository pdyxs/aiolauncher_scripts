local M = {}

function M.parse_todo_list(list, completions)
    if not list then
        return {}
    end

    completions = completions or 0
    local result = {}

    for _, item in ipairs(list) do
        local parsed_items = M._parse_item(item, completions)
        for _, parsed_item in ipairs(parsed_items) do
            table.insert(result, parsed_item)
        end
    end

    return result
end

function M._parse_item(item, completions)
    local text = item.text or ""
    local children = item.children or {}

    -- Handle rotation
    if text:lower():find("rotate between") then
        return M._handle_rotation(children, completions)
    end

    -- Handle leaf nodes
    if #children == 0 then
        return {text}
    end

    -- Handle other children
    local result = {}
    for _, child in ipairs(children) do
        local child_items = M._parse_item(child, completions)
        for _, child_item in ipairs(child_items) do
            table.insert(result, child_item)
        end
    end

    if #result == 0 then
        table.insert(result, text)
    end

    return result
end

function M._handle_rotation(rotation_options, completions)
    if #rotation_options == 0 then
        return {}
    end

    local selected_index = (completions % #rotation_options) + 1
    local selected_option = rotation_options[selected_index]

    return M._parse_item(selected_option, completions)
end

return M
