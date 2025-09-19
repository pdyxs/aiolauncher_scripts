local markdown_parser = {}

function markdown_parser.get_list_items(filename)
    local content = files:read(filename)
    return markdown_parser.parse_list_items(content)
end

function markdown_parser.parse_list_items(content)
    local lines = {}
    for line in content:gmatch("[^\r\n]+") do
        table.insert(lines, line)
    end

    local result = {}
    local stack = {}
    local last_item_at_level = {}

    for _, line in ipairs(lines) do
        local indent, text = line:match("^(%s*)[-*+]%s+(.+)")
        if indent and text then
            local indent_level = #indent
            local item = {text = text}

            -- Clear deeper levels from tracking
            for level = indent_level + 1, #last_item_at_level do
                last_item_at_level[level] = nil
            end

            if indent_level == 0 then
                -- Top level item
                table.insert(result, item)
                last_item_at_level[0] = item
            else
                -- Find parent at previous level
                local parent_item = nil
                for level = indent_level - 1, 0, -1 do
                    if last_item_at_level[level] then
                        parent_item = last_item_at_level[level]
                        break
                    end
                end

                if parent_item then
                    if not parent_item.children then
                        parent_item.children = {}
                    end
                    table.insert(parent_item.children, item)
                else
                    -- No valid parent found, treat as top level
                    table.insert(result, item)
                end

                last_item_at_level[indent_level] = item
            end
        end
    end

    return result
end

return markdown_parser