local M = {}

function M.parse_todo_list(list, completions, capacity)
    if not list or not capacity then
        return {}
    end

    completions = completions or 0
    local result = {}

    for _, item in ipairs(list) do
        local parsed_items = M._parse_item(item, completions, capacity)
        for _, parsed_item in ipairs(parsed_items) do
            table.insert(result, parsed_item)
        end
    end

    return result
end

function M._parse_item(item, completions, capacity)
    local text = item.text or ""
    local children = item.children or {}

    -- Handle rotation
    if text:lower():find("rotate between") then
        return M._handle_rotation(children, completions, capacity)
    end

    -- Handle capacity-specific children
    local capacity_child = M._find_capacity_child(children, capacity)
    if capacity_child then
        local merged = M._merge_capacity_info(text, capacity_child)
        return {merged}
    end

    -- Handle leaf nodes
    if #children == 0 then
        return {text}
    end

    -- Handle other children
    local result = {}
    for _, child in ipairs(children) do
        local child_items = M._parse_item(child, completions, capacity)
        for _, child_item in ipairs(child_items) do
            table.insert(result, child_item)
        end
    end

    if #result == 0 then
        table.insert(result, text)
    end

    return result
end

function M._handle_rotation(rotation_options, completions, capacity)
    if #rotation_options == 0 then
        return {}
    end

    local selected_index = (completions % #rotation_options) + 1
    local selected_option = rotation_options[selected_index]

    return M._parse_item(selected_option, completions, capacity)
end

function M._find_capacity_child(children, capacity)
    for _, child in ipairs(children) do
        local child_text = child.text or ""
        if child_text:lower():find("^" .. capacity:lower() .. ":") then
            return child_text
        end
    end
    return nil
end

function M._merge_capacity_info(base_text, capacity_text)
    local capacity_info = capacity_text:match("^[^:]+:%s*(.+)")
    if not capacity_info then
        return base_text
    end

    if base_text:find("%(.*%)") then
        return base_text:gsub("%((.*)%)", "(%1, " .. capacity_info .. ")")
    else
        return base_text .. " (" .. capacity_info .. ")"
    end
end

return M