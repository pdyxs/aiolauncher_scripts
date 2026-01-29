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
              {name = nil, children = nil}
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
              {name = nil, children = nil}
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

-- Load utility functions
require("utils")

local markdown_parser = {
    version = 3
}

--[[
  STEP 1: Parse lines and create rough hierarchy (indentation only)

  Converts markdown text into a tree structure based purely on indentation.
  Each node has: {text = "...", children = [...]}
]]
local function build_hierarchy_from_indentation(content)
    local lines = {}

    if not content then
        return nil
    end

    -- Parse all bullet lines with their indentation
    for line in content:gmatch("[^\r\n]+") do
        local indent, text = line:match("^(%s*)[-*+]%s+(.+)")
        if indent and text then
            table.insert(lines, {
                indent_level = #indent,
                text = text
            })
        end
    end

    -- Build tree structure
    local root = { children = {} }
    local stack = { { item = root, level = -1 } }

    for _, line in ipairs(lines) do
        local node = {
            text = line.text,
            children = {}
        }

        -- Pop stack until we find the parent
        while #stack > 0 and stack[#stack].level >= line.indent_level do
            table.remove(stack)
        end

        -- Add to parent
        local parent = stack[#stack].item
        table.insert(parent.children, node)

        -- Push onto stack
        table.insert(stack, { item = node, level = line.indent_level })
    end

    return root.children
end

--[[
  STEP 2: Expand single-line notations to hierarchical form

  Converts patterns like:
  - "Item (A, B)" -> Item with children A, B
  - "Item: A, B" -> Item with children A, B
  - "Item (~Flag, Option: X)" -> Item with children ~Flag and Option: X

  This is done recursively on the tree.
]]
local function expand_inline_notations(nodes)
    local result = {}

    for _, node in ipairs(nodes) do
        local text = node.text
        local new_children = {}

        -- Check for bracket expansion: "Text (A, B)" or "Text (X: A; Y: B)"
        local base_text, bracket_content = text:match("^(.-)%s*%((.*)%)%s*$")
        if base_text and bracket_content then
            text = base_text:trim()

            -- Check if we have colons or tildes (attribute groups)
            if bracket_content:find(":") or bracket_content:find("~") then
                -- Split by semicolons for multiple groups, or by commas for single group
                local groups = {}
                if bracket_content:find(";") then
                    for group in (bracket_content .. ";"):gmatch("([^;]+);") do
                        table.insert(groups, group:trim())
                    end
                else
                    -- Check if we need to split by commas (mixed tilde and colon)
                    if bracket_content:find("~") and bracket_content:find(",") then
                        for group in (bracket_content .. ","):gmatch("([^,]+),") do
                            table.insert(groups, group:trim())
                        end
                    else
                        table.insert(groups, bracket_content:trim())
                    end
                end

                -- Each group becomes a child - recursively expand them
                for _, group in ipairs(groups) do
                    local child_nodes = expand_inline_notations({ { text = group, children = {} } })
                    for _, child_node in ipairs(child_nodes) do
                        table.insert(new_children, child_node)
                    end
                end
            else
                -- Simple bracket expansion: split by commas
                for item in (bracket_content .. ","):gmatch("([^,]+),") do
                    item = item:trim()
                    if item ~= "" then
                        table.insert(new_children, { text = item, children = {} })
                    end
                end
            end
        end

        -- Check for colon expansion: "Text: A, B, C" (but not if it ends with just ":")
        -- Also skip if it looks like a line prefix pattern (icon, checkbox, date)
        if #new_children == 0 then
            local base, colon_items = text:match("^(.-)%s*:%s*(.+)$")
            -- Skip if base is empty, looks like an icon, checkbox, or date pattern
            local should_skip = not base or base == "" or
                base:match("^%[") or                     -- checkbox
                base:match(":fa[%-_]") or                -- icon (fa- or fa_)
                base:match("%d%d%d%d%-%d%d%-%d%d%s*%-$") -- date
            if base and colon_items and not should_skip then
                -- Keep the colon in the text so Step 4 can identify it as an attribute
                text = base:trim() .. ":"

                -- Split by commas
                for item in (colon_items .. ","):gmatch("([^,]+),") do
                    item = item:trim()
                    if item ~= "" then
                        table.insert(new_children, { text = item, children = {} })
                    end
                end
            end
        end

        -- Create the expanded node
        local expanded_node = {
            text = text,
            children = {}
        }

        -- Add expanded children first, then original children
        for _, child in ipairs(new_children) do
            table.insert(expanded_node.children, child)
        end

        -- Recursively expand original children
        for _, child in ipairs(node.children) do
            local expanded_children = expand_inline_notations({ child })
            for _, ec in ipairs(expanded_children) do
                table.insert(expanded_node.children, ec)
            end
        end

        table.insert(result, expanded_node)
    end

    return result
end

--[[
  STEP 3: Handle text parsing (icons, checkboxes, dates)

  Parses line prefixes from the text field and moves them to dedicated fields.
]]
local function parse_line_prefixes(nodes)
    for _, node in ipairs(nodes) do
        local text = node.text

        -- Extract checkbox [x] or [ ]
        local checkbox_char, remaining = text:match("^%[([x%s])%]%s+(.*)$")
        if checkbox_char then
            node.checkbox = (checkbox_char:lower() == "x")
            text = remaining
        end

        -- Extract icon :fa-icon: or :fa_icon:
        local icon_name, remaining = text:match("^:fa[%-_]([^:]+):%s*(.*)$")
        if icon_name then
            node.icon = icon_name
            text = remaining
        end

        -- Extract date YYYY-MM-DD -
        local date_str, remaining = text:match("^(%d%d%d%d%-%d%d%-%d%d)%s*%-%s+(.*)$")
        if date_str then
            local year, month, day = date_str:match("^(%d%d%d%d)%-(%d%d)%-(%d%d)$")
            node.date = os.time({ year = tonumber(year), month = tonumber(month), day = tonumber(day) })
            text = remaining
        end

        -- Trim whitespace and update text
        node.text = text:trim()

        -- Recursively process children
        if node.children and #node.children > 0 then
            parse_line_prefixes(node.children)
        end
    end
end

--[[
  STEP 4: Parse attributes and handle 'All:'

  Identifies which nodes are attributes (ending with : or starting with ~),
  separates them from regular children, and handles All: inheritance.
]]
local function parse_attributes(nodes)
    -- First, recursively process all children
    for _, node in ipairs(nodes) do
        if node.children and #node.children > 0 then
            local processed_children, child_attributes = parse_attributes(node.children)

            -- Set children to nil if empty
            if #processed_children == 0 then
                node.children = nil
            else
                node.children = processed_children
            end

            -- Add attributes to this node
            if child_attributes and next(child_attributes) then
                node.attributes = child_attributes
            end
        else
            -- No children, set to nil
            node.children = nil
        end
    end

    -- Now separate children from attributes at this level
    -- Process All: incrementally as we go
    local regular_children = {}
    local attributes = {}
    local all_children = {}   -- Accumulated All: children
    local all_attributes = {} -- Accumulated All: attributes

    for i, node in ipairs(nodes) do
        -- Check for tilde-prefixed attribute: ~Keyword
        local tilde_keyword = node.text:match("^~(.+)$")
        if tilde_keyword then
            tilde_keyword = tilde_keyword:trim():lower()
            if not attributes[tilde_keyword] then
                attributes[tilde_keyword] = {}
            end
            table.insert(attributes[tilde_keyword], {
                name = nil,
                children = nil
            })
            -- Check for attribute ending with : (but with optional name in parens)
        elseif node.text:ends_with(":") then
            local keyword, name = node.text:match("^(.-)%s*%((.*)%)%s*:$")
            if not keyword then
                keyword = node.text:match("^(.-)%s*:$")
            end

            keyword = keyword:gsub("%s+", ""):lower()

            -- Check for "All:" special case
            if keyword == "all" then
                -- Append to all previously processed siblings
                for _, prev_child in ipairs(regular_children) do
                    if node.children then
                        if not prev_child.children then
                            prev_child.children = {}
                        end
                        concat(prev_child.children, node.children)
                    end
                    if node.attributes then
                        if not prev_child.attributes then
                            prev_child.attributes = {}
                        end
                        for attr_keyword, entries in pairs(node.attributes) do
                            if not prev_child.attributes[attr_keyword] then
                                prev_child.attributes[attr_keyword] = {}
                            end
                            concat(prev_child.attributes[attr_keyword], entries)
                        end
                    end
                end

                -- Add to accumulated All: for future siblings
                if node.children then
                    concat(all_children, node.children)
                end
                if node.attributes then
                    for attr_keyword, entries in pairs(node.attributes) do
                        if not all_attributes[attr_keyword] then
                            all_attributes[attr_keyword] = {}
                        end
                        concat(all_attributes[attr_keyword], entries)
                    end
                end
            else
                if not attributes[keyword] then
                    attributes[keyword] = {}
                end
                table.insert(attributes[keyword], {
                    name = name,
                    children = node.children,
                    attributes = node.attributes
                })
            end
        else
            -- Regular child - apply accumulated All: first
            if #all_children > 0 then
                if not node.children then
                    node.children = {}
                end
                -- Prepend all accumulated All: children
                for i = #all_children, 1, -1 do
                    table.insert(node.children, 1, all_children[i])
                end
            end
            if next(all_attributes) then
                if not node.attributes then
                    node.attributes = {}
                end
                for attr_keyword, entries in pairs(all_attributes) do
                    if not node.attributes[attr_keyword] then
                        node.attributes[attr_keyword] = {}
                    end
                    concat(node.attributes[attr_keyword], entries)
                end
            end

            table.insert(regular_children, node)
        end
    end

    return regular_children, attributes
end

--[[
  Main parse function
  @param content string - The markdown content to parse
  @return table - Wrapper object with {children = [...], attributes = {...}}
]]
function markdown_parser.parse(content)
    -- Step 1: Build hierarchy from indentation
    local tree = build_hierarchy_from_indentation(content)

    -- Step 2: Expand inline notations (brackets, colons)
    tree = expand_inline_notations(tree)

    -- Step 3: Parse line prefixes (checkboxes, icons, dates)
    parse_line_prefixes(tree)

    -- Step 4: Parse attributes and handle All:
    local children, attributes = parse_attributes(tree)

    return {
        children = children,
        attributes = attributes
    }
end

-- Export for file-manager compatibility
return markdown_parser
