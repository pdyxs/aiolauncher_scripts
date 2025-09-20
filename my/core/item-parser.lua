local item_parser = {}

function item_parser.parse_item(item)
    local text = item.text

    -- Check if text is surrounded by double angle brackets
    if text:match("^%[%[(.+)%]%]$") then
        return text:match("^%[%[(.+)%]%]$")
    end

    return text
end

return item_parser