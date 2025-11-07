--[[
  Markdown Parser for AIO Launcher Scripts

  This parser creates a hierarchical structure from markdown bullet lists with
  support for:
  - Bracket expansion: "Item (A, B)" -> Item with children A, B
  - Colon expansion: "Item: A, B" -> Item with children A, B
  - Attributes: Named lists that are stored separately (case-insensitive keywords)
  - Tilde attributes: "Item (~Flag)" -> Attribute without children
  - "All:" special attribute for inheriting attributes/children
  - Line prefixes: checkboxes, icons, dates
  - Flexible whitespace: Extra spaces are ignored (except for hierarchy indentation)

  Parser Return Structure:

  The parse() function returns a wrapper object:
  {
    children = [...],   -- Array of top-level items
    attributes = {...}  -- Dictionary of top-level attributes
  }

  Each item has the following structure:
  {
    text = "Item text",              -- The main text of the item
    checkbox = true/false/nil,       -- Checkbox state (nil if no checkbox)
    icon = "icon-name" or nil,       -- FontAwesome icon name (without :fa- prefix)
    date = os.time(...) or nil,      -- Date object created from YYYY-MM-DD string
    children = {...},                -- Array of child items (same structure)
    attributes = {                   -- Dictionary of attributes, keyed by keyword (lowercase)
      keyword1 = {                   -- Each keyword maps to array of attribute entries
        {name = "attr1", children = {...}},  -- Each entry has optional name and children
        {name = "attr2", children = {...}}
      },
      keyword2 = {...}
    }
  }

  Note: Attribute entries use "name" instead of "text" for clarity. The children
  array contains the actual items for that attribute instance.
  Attribute keywords are case-insensitive and stored in lowercase (e.g., "Options"
  and "options" both become "options").

  Example parsing:

  Input:
    * [ ] :fa-heart: 2025-01-15 - Task (~Flag, Option (One): A, B; Option (Two): C; Note: Important)
      * Subtask
    * All:
      * Common child
    * Second task (~Important)
      * Explicit child
    * Color: Red

  Output:
    {
      children = [
        {
          text = "Task",
          checkbox = false,
          icon = "heart",
          date = os.time({year = 2025, month = 1, day = 15}),
          attributes = {
            flag = [
              {name = nil, children = []}
            ],
            option = [
              {name = "One", children = [{text = "A"}, {text = "B"}]},
              {name = "Two", children = [{text = "C"}]}
            ],
            note = [
              {name = nil, children = [{text = "Important"}]}
            ]
          },
          children = [
            {text = "Subtask"},
            {text = "Common child"}
          ]
        },
        {
          text = "Second task",
          attributes = {
            important = [
              {name = nil, children = []}
            ]
          },
          children = [
            {text = "Common child"},
            {text = "Explicit child"}
          ]
        }
      ],
      attributes = {
        Color = [
          {name = nil, children = [{text = "Red"}]}
        ]
      }
    }
]]

local markdown_parser = {
    version = 1
}

--[[
  Parse markdown content into a hierarchical structure
  @param content string - The markdown content to parse
  @return table - Wrapper object with {children = [...], attributes = {...}}
]]
function markdown_parser.parse(content)
    local lines = parse_lines(content)
    local raw_items = parse_hierarchy(lines)
    local items_with_all = apply_all_attributes(raw_items)

    -- Separate top-level items from attributes
    local result = {
        children = {},
        attributes = {}
    }

    for _, item in ipairs(items_with_all) do
        if item.is_attribute then
            -- Add to attributes dictionary
            local keyword = item.attribute_keyword
            local name = item.attribute_name
            -- Normalize keyword to lowercase for case-insensitive matching
            local normalized_keyword = keyword:lower()
            if not result.attributes[normalized_keyword] then
                result.attributes[normalized_keyword] = {}
            end
            table.insert(result.attributes[normalized_keyword], {
                name = name,
                children = item.children or {}
            })
        else
            -- Add to children array
            table.insert(result.children, item)
        end
    end

    return result
end

--[[
  Split content into lines with metadata
  @param content string - The markdown content
  @return table - Array of {line, indent_level, text}
]]
function parse_lines(content)
    local lines = {}
    for line in content:gmatch("[^\r\n]+") do
        -- Match bullet points with indent
        local indent, text = line:match("^(%s*)[-*+]%s+(.+)")
        if indent and text then
            local indent_level = #indent
            table.insert(lines, {
                indent_level = indent_level,
                text = text
            })
        end
    end
    return lines
end

--[[
  Parse a single line to extract prefix metadata and core text
  @param line string - The line to parse
  @return table - {checkbox, icon, date (os.time object), text}
]]
function parse_line_prefixes(line)
    local result = {
        checkbox = nil,  -- true, false, or nil
        icon = nil,      -- "icon-name" or nil
        date = nil,      -- "YYYY-MM-DD" or nil
        text = line      -- remaining text after prefixes
    }

    local remaining = line

    -- Extract checkbox [ ] or [x]
    local checkbox_match = remaining:match("^%[([x%s])%]%s+(.*)$")
    if checkbox_match then
        result.checkbox = (checkbox_match == "x")
        remaining = remaining:match("^%[[x%s]%]%s+(.*)$")
    end

    -- Extract icon :fa-icon-name:
    local icon_match = remaining:match("^:fa%-([^:]+):%s+(.*)$")
    if icon_match then
        result.icon = icon_match
        remaining = remaining:match("^:fa%-[^:]+:%s+(.*)$")
    end

    -- Extract date YYYY-MM-DD -
    local date_match = remaining:match("^(%d%d%d%d%-%d%d%-%d%d)%s*%-%s+(.*)$")
    if date_match then
        -- Parse date string into components and convert to os.time object
        local year, month, day = date_match:match("^(%d%d%d%d)%-(%d%d)%-(%d%d)$")
        result.date = os.time({year = tonumber(year), month = tonumber(month), day = tonumber(day)})
        remaining = remaining:match("^%d%d%d%d%-%d%d%-%d%d%s*%-%s+(.*)$")
    end

    -- Trim leading and trailing whitespace from final text
    result.text = remaining:match("^%s*(.-)%s*$")
    return result
end

--[[
  Parse text and extract inline expansions (brackets and colons)
  @param text string - The text to parse
  @return table - {base_text, expansions, is_attribute, attribute_keyword, attribute_name}

  expansions = {
    {type = "bracket_simple", items = {"A", "B"}},  -- From (A, B)
    {type = "bracket_group", keyword = "X", name = "Y", items = {"C", "D"}},  -- From X (Y): C, D
    {type = "colon", items = {"E", "F"}}  -- From : E, F
  }

  For attributes (lines ending with :):
    is_attribute = true
    attribute_keyword = "Options"  -- The main keyword
    attribute_name = "Symptoms"    -- Optional name from brackets (or nil)
]]
function parse_text_expansions(text)
    local result = {
        base_text = text,
        expansions = {},
        is_attribute = false,
        attribute_keyword = nil,
        attribute_name = nil
    }

    -- Check for bracket expansion first: "Text (A, B)" or "Text (X: A; Y: B)"
    -- This needs to be checked before colon expansion to avoid matching colons inside brackets
    local base_text, bracket_content = text:match("^(.-)%s*%((.*)%)%s*$")
    if base_text and bracket_content then
        result.base_text = base_text:match("^%s*(.-)%s*$")

        -- Check if bracket content has colons or tildes (attribute groups)
        if bracket_content:find(":") or bracket_content:find("~") then
            -- Has colons or tildes, treat as attribute groups
            -- Split by semicolons for multiple groups (or treat as single group if no semicolons)
            local groups = {}
            if bracket_content:find(";") then
                -- Multiple groups separated by semicolons
                for group in (bracket_content .. ";"):gmatch("([^;]+);") do
                    table.insert(groups, group:match("^%s*(.-)%s*$"))
                end
            else
                -- Single group - but we need to split by commas for tilde attributes mixed with colon attributes
                -- Check if we have a mix of tilde and colon syntax
                if bracket_content:find("~") and bracket_content:find(",") then
                    -- Split by commas
                    for group in (bracket_content .. ","):gmatch("([^,]+),") do
                        table.insert(groups, group:match("^%s*(.-)%s*$"))
                    end
                else
                    -- Single group
                    table.insert(groups, bracket_content:match("^%s*(.-)%s*$"))
                end
            end

            for _, group in ipairs(groups) do
                -- Check for tilde-prefixed attribute first: "~Expand"
                local tilde_keyword = group:match("^~(.+)$")
                if tilde_keyword then
                    tilde_keyword = tilde_keyword:match("^%s*(.-)%s*$")
                    table.insert(result.expansions, {
                        type = "bracket_group",
                        keyword = tilde_keyword,
                        name = nil,
                        items = {}  -- Empty items for tilde attributes
                    })
                else
                    -- Parse each group: "Keyword (Name): items" or "Keyword: items"
                    local keyword, name, items_str = group:match("^(.-)%s*%((.-)%)%s*:%s*(.+)$")
                    if keyword and name and items_str then
                        -- "Option (One): A, B"
                        local items = {}
                        for item in (items_str .. ","):gmatch("([^,]+),") do
                            item = item:match("^%s*(.-)%s*$")
                            if item ~= "" then
                                table.insert(items, item)
                            end
                        end
                        table.insert(result.expansions, {
                            type = "bracket_group",
                            keyword = keyword,
                            name = name,
                            items = items
                        })
                    else
                        -- Try "Keyword: items" without name
                        keyword, items_str = group:match("^(.-)%s*:%s*(.+)$")
                        if keyword and items_str then
                            local items = {}
                            for item in (items_str .. ","):gmatch("([^,]+),") do
                                item = item:match("^%s*(.-)%s*$")
                                if item ~= "" then
                                    table.insert(items, item)
                                end
                            end
                            table.insert(result.expansions, {
                                type = "bracket_group",
                                keyword = keyword,
                                name = nil,
                                items = items
                            })
                        end
                    end
                end
            end
        else
            -- Simple bracket expansion: "Text (A, B, C)"
            local items = {}
            for item in (bracket_content .. ","):gmatch("([^,]+),") do
                item = item:match("^%s*(.-)%s*$")
                if item ~= "" then
                    table.insert(items, item)
                end
            end
            if #items > 0 then
                table.insert(result.expansions, {type = "bracket_simple", items = items})
            end
        end
        return result
    end

    -- Check if line ends with colon (attribute marker)
    local attr_pattern = "^(.-)%s*:%s*$"
    local attr_match = text:match(attr_pattern)

    if attr_match then
        -- This is an attribute
        result.is_attribute = true

        -- Check for brackets in attribute keyword: "Keyword (Name):"
        local keyword, name = attr_match:match("^(.-)%s*%((.*)%)%s*$")
        if keyword and name then
            result.attribute_keyword = keyword
            result.attribute_name = name
            result.base_text = keyword
        else
            result.attribute_keyword = attr_match
            result.base_text = attr_match
        end
        return result
    end

    -- Check for colon expansion: "Text: A, B, C"
    local base, colon_items = text:match("^(.-)%s*:%s*(.+)$")
    if base and colon_items then
        -- Check if base has brackets - this creates an attribute with name
        local keyword, name = base:match("^(.-)%s*%((.*)%)%s*$")
        if keyword and name then
            -- "Test (One, Two): A, B" -> attribute with keyword "Test", name "One, Two"
            result.is_attribute = true
            result.attribute_keyword = keyword
            result.attribute_name = name
            result.base_text = keyword

            -- Parse the items after colon
            local items = {}
            for item in (colon_items .. ","):gmatch("([^,]+),") do
                item = item:match("^%s*(.-)%s*$") -- trim whitespace
                if item ~= "" then
                    table.insert(items, item)
                end
            end
            if #items > 0 then
                table.insert(result.expansions, {type = "colon", items = items})
            end
        else
            -- "Test: A, B, C" -> attribute without name
            result.is_attribute = true
            result.attribute_keyword = base
            result.attribute_name = nil
            result.base_text = base

            local items = {}
            for item in (colon_items .. ","):gmatch("([^,]+),") do
                item = item:match("^%s*(.-)%s*$")
                if item ~= "" then
                    table.insert(items, item)
                end
            end
            if #items > 0 then
                table.insert(result.expansions, {type = "colon", items = items})
            end
        end
        return result
    end

    return result
end

--[[
  Build hierarchical structure from flat list of lines
  @param lines table - Array of {indent_level, text} from parse_lines
  @return table - Array of items with children
]]
function parse_hierarchy(lines)
    local result = {}
    local last_item_at_level = {}

    for _, line_data in ipairs(lines) do
        local indent_level = line_data.indent_level
        local text = line_data.text

        -- Parse line prefixes (checkbox, icon, date)
        local prefix_data = parse_line_prefixes(text)

        -- Parse text expansions (brackets, colons, attributes)
        local expansion_data = parse_text_expansions(prefix_data.text)

        -- Create the item
        local item = create_item(
            expansion_data.base_text,
            prefix_data.checkbox,
            prefix_data.icon,
            prefix_data.date
        )

        -- Mark if this is an attribute
        item.is_attribute = expansion_data.is_attribute
        item.attribute_keyword = expansion_data.attribute_keyword
        item.attribute_name = expansion_data.attribute_name

        -- Process expansions to create children or attributes
        for _, exp in ipairs(expansion_data.expansions) do
            if exp.type == "bracket_simple" then
                -- Simple bracket expansion creates children
                for _, exp_item in ipairs(exp.items) do
                    add_child(item, create_item(exp_item))
                end
            elseif exp.type == "bracket_group" then
                -- Bracket group creates attributes
                local attr_children = {}
                for _, exp_item in ipairs(exp.items) do
                    table.insert(attr_children, create_item(exp_item))
                end
                add_attribute(item, exp.keyword, exp.name, attr_children)
            elseif exp.type == "colon" then
                -- Colon expansion - if item is attribute, these become children of attribute
                for _, exp_item in ipairs(exp.items) do
                    add_child(item, create_item(exp_item))
                end
            end
        end

        -- Clear deeper levels from tracking
        for level = indent_level + 1, #last_item_at_level do
            last_item_at_level[level] = nil
        end

        -- Add to hierarchy based on indent
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
                -- Check if this is an attribute or a child
                -- Special case: "All:" should be added as a child, not an attribute
                if item.is_attribute and item.text ~= "All" then
                    -- Add as attribute to parent
                    add_attribute(parent_item, item.attribute_keyword, item.attribute_name, item.children or {})
                    -- Don't add the item itself, just its content as attribute
                else
                    -- Add as regular child (including "All:" items)
                    add_child(parent_item, item)
                end
            else
                -- No valid parent found, treat as top level
                table.insert(result, item)
            end

            last_item_at_level[indent_level] = item
        end
    end

    return result
end

--[[
  Apply 'All:' attributes to siblings at the same level
  @param items table - Array of items from parse_hierarchy
  @return table - Array of items with All: attributes applied
]]
function apply_all_attributes(items)
    if not items or #items == 0 then
        return items
    end

    -- Find all "All:" items at this level
    local all_items = {}
    local all_positions = {}
    local non_all_items = {}

    for i, item in ipairs(items) do
        if item.text == "All" and item.is_attribute then
            table.insert(all_items, item)
            table.insert(all_positions, i)
        else
            table.insert(non_all_items, item)
        end
    end

    -- If there are All: items, apply their content to siblings
    if #all_items > 0 then
        -- Process each non-All item
        for item_idx, item in ipairs(non_all_items) do
            -- Determine original position of this item
            local original_pos = 0
            local count = 0
            for i, check_item in ipairs(items) do
                if check_item.text ~= "All" or not check_item.is_attribute then
                    count = count + 1
                    if count == item_idx then
                        original_pos = i
                        break
                    end
                end
            end

            -- Apply All: items based on position
            for all_idx, all_item in ipairs(all_items) do
                local all_pos = all_positions[all_idx]

                if all_item.children then
                    -- Items before All: get children appended
                    -- Items after All: get children prepended
                    if original_pos < all_pos then
                        -- Append
                        for _, child in ipairs(all_item.children) do
                            local child_copy = copy_item(child)
                            add_child(item, child_copy)
                        end
                    else
                        -- Prepend (in reverse order to maintain correct sequence)
                        if not item.children then
                            item.children = {}
                        end
                        for i = #all_item.children, 1, -1 do
                            local child_copy = copy_item(all_item.children[i])
                            table.insert(item.children, 1, child_copy)
                        end
                    end
                end

                -- Apply All: attributes to sibling
                if all_item.attributes then
                    for keyword, attr_entries in pairs(all_item.attributes) do
                        for _, attr_entry in ipairs(attr_entries) do
                            -- Deep copy the attribute children
                            local attr_children_copy = {}
                            if attr_entry.children then
                                for _, child in ipairs(attr_entry.children) do
                                    table.insert(attr_children_copy, copy_item(child))
                                end
                            end
                            add_attribute(item, keyword, attr_entry.name, attr_children_copy)
                        end
                    end
                end
            end
        end

        items = non_all_items
    end

    -- Recursively apply to children
    for _, item in ipairs(items) do
        if item.children then
            item.children = apply_all_attributes(item.children)
        end
    end

    return items
end

-- Helper: Deep copy an item
function copy_item(item)
    local copy = {
        text = item.text,
        checkbox = item.checkbox,
        icon = item.icon,
        date = item.date
    }

    if item.children then
        copy.children = {}
        for _, child in ipairs(item.children) do
            table.insert(copy.children, copy_item(child))
        end
    end

    if item.attributes then
        copy.attributes = {}
        for keyword, attr_entries in pairs(item.attributes) do
            copy.attributes[keyword] = {}
            for _, attr_entry in ipairs(attr_entries) do
                local children_copy = {}
                if attr_entry.children then
                    for _, child in ipairs(attr_entry.children) do
                        table.insert(children_copy, copy_item(child))
                    end
                end
                table.insert(copy.attributes[keyword], {
                    name = attr_entry.name,
                    children = children_copy
                })
            end
        end
    end

    return copy
end

--[[
  Helper: Create a new item structure
]]
function create_item(text, checkbox, icon, date)
    return {
        text = text or "",
        checkbox = checkbox,
        icon = icon,
        date = date,
        children = nil,   -- Will be set to {} when first child is added
        attributes = nil  -- Will be set to {} when first attribute is added
    }
end

--[[
  Helper: Add a child to an item
]]
function add_child(item, child)
    if not item.children then
        item.children = {}
    end
    table.insert(item.children, child)
end

--[[
  Helper: Add an attribute to an item
  @param item table - The item to add attribute to
  @param keyword string - The attribute keyword (e.g., "Options")
  @param name string|nil - Optional attribute name (e.g., "Symptoms")
  @param children table - Array of child items for this attribute
]]
function add_attribute(item, keyword, name, children)
    if not item.attributes then
        item.attributes = {}
    end
    -- Normalize keyword to lowercase for case-insensitive matching
    local normalized_keyword = keyword:lower()
    if not item.attributes[normalized_keyword] then
        item.attributes[normalized_keyword] = {}
    end
    -- Create attribute entry with optional name and children
    local attr_entry = {
        name = name,
        children = children
    }
    table.insert(item.attributes[normalized_keyword], attr_entry)
end

-- Export for file-manager compatibility
return markdown_parser
