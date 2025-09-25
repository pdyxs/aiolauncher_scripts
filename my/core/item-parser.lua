local item_parser = {}

function item_parser.parse_item(item)
    local text = item.text
    local is_link = false

    -- Check if text is surrounded by double angle brackets
    if text:match("^%[%[(.+)%]%]$") then
        is_link = true
        text = text:match("^%[%[(.+)%]%]$")
    end

    local value = text

    local specifiers = item_parser.extract_specifiers(item)
    
    local meta = { is_link = is_link, specifiers=specifiers }

    local main_text, extracted_detail = text:match("^(.+)%s+%((.+)%)$")
    if main_text and extracted_detail then
        value = main_text
        meta.detail = extracted_detail
    end

    return { value=value, text=text, meta=meta }
end

-- Extracts specifiers and their parameters from an item's children
-- Returns a table where keys are specifier names and values are parameter arrays
function item_parser.extract_specifiers(item)
    local specifiers = {}

    if not item.children then
        return specifiers
    end

    for _, child in ipairs(item.children) do
        local text = child.text or ""

        -- Check if this child is a specifier (contains ":")
        local specifier_name = text:match("^([^:]+):")
        if specifier_name then
            specifier_name = specifier_name:trim()

            -- Format 1: Parameters in same text (e.g. "Options: one, two, three")
            local params_text = text:match("^[^:]+:%s*(.+)")
            if params_text and params_text:trim() ~= "" then
                local params = {}
                for param in params_text:gmatch("([^,]+)") do
                    table.insert(params, param:trim())
                end
                specifiers[specifier_name] = params

            -- Format 2: Parameters as children
            elseif child.children then
                local params = {}
                for _, param_child in ipairs(child.children) do
                    if param_child.text then
                        table.insert(params, param_child.text:trim())
                    end
                end
                specifiers[specifier_name] = params

            -- Empty specifier
            else
                specifiers[specifier_name] = {}
            end
        end
    end

    return specifiers
end

return item_parser