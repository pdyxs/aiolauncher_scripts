--[[
  Markdown Parser for AIO Launcher Scripts

  This parser creates a hierarchical structure from markdown bullet lists with
  support for:
  - Bracket expansion: "Item (A, B)" -> Item with children A, B
  - Colon expansion: "Item: A, B" -> Item with children A, B
  - Attributes: Named lists that are stored separately
  - "All:" special attribute for inheriting attributes/children
  - Line prefixes: checkboxes, icons, dates

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
    date = "YYYY-MM-DD" or nil,      -- ISO date string
    children = {...},                -- Array of child items (same structure)
    attributes = {                   -- Dictionary of attributes, keyed by keyword
      keyword1 = {                   -- Each keyword maps to array of attribute entries
        {name = "attr1", children = {...}},  -- Each entry has optional name and children
        {name = "attr2", children = {...}}
      },
      keyword2 = {...}
    }
  }

  Note: Attribute entries use "name" instead of "text" for clarity. The children
  array contains the actual items for that attribute instance.

  Example parsing:

  Input:
    * [ ] :fa-heart: 2025-01-15 - Task (Option (One): A, B; Option (Two): C; Note: Important)
      * Subtask
    * All:
      * Common child
    * Second task
      * Explicit child
    * Color: Red

  Output:
    {
      children = [
        {
          text = "Task",
          checkbox = false,
          icon = "heart",
          date = "2025-01-15",
          attributes = {
            Option = [
              {name = "One", children = [{text = "A"}, {text = "B"}]},
              {name = "Two", children = [{text = "C"}]}
            ],
            Note = [
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
            if not result.attributes[keyword] then
                result.attributes[keyword] = {}
            end
            table.insert(result.attributes[keyword], {
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
    -- TODO: Split content into lines
    -- TODO: For each line, extract indent level and full text
    return {}
end

--[[
  Parse a single line to extract prefix metadata and core text
  @param line string - The line to parse
  @return table - {checkbox, icon, date, text}
]]
function parse_line_prefixes(line)
    local result = {
        checkbox = nil,  -- true, false, or nil
        icon = nil,      -- "icon-name" or nil
        date = nil,      -- "YYYY-MM-DD" or nil
        text = line      -- remaining text after prefixes
    }

    -- TODO: Extract checkbox [ ] or [x]
    -- TODO: Extract icon :fa-icon-name:
    -- TODO: Extract date YYYY-MM-DD -
    -- TODO: Set result.text to remaining text

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

    -- TODO: Check if line ends with colon (attribute marker)
    -- TODO: Extract attribute keyword and optional name from brackets like "Options (Symptoms):"
    -- TODO: Extract bracket content if present: (...)
    -- TODO: Parse bracket content for semicolon-separated groups
    -- TODO: Each group can be: "Keyword (Name): items" or "Keyword: items" or "items"
    -- TODO: Parse colon expansion after text: "Text: A, B, C"

    return result
end

--[[
  Build hierarchical structure from flat list of lines
  @param lines table - Array of {indent_level, text} from parse_lines
  @return table - Array of items with children
]]
function parse_hierarchy(lines)
    local result = {}
    local stack = {}  -- Track parent items at each indent level
    local last_item_at_level = {}

    -- TODO: Similar to legacy parser, build hierarchy based on indent
    -- TODO: For each line, create item with parse_line_prefixes
    -- TODO: Parse text expansions with parse_text_expansions
    -- TODO: Create children from expansions
    -- TODO: Handle attributes separately

    return result
end

--[[
  Apply 'All:' attributes to siblings at the same level
  @param items table - Array of items from parse_hierarchy
  @return table - Array of items with All: attributes applied
]]
function apply_all_attributes(items)
    -- TODO: Find all "All:" items at each level
    -- TODO: Collect attributes and children from All: items
    -- TODO: Apply to all siblings (items at same level)
    -- TODO: Handle ordering: items before All: get its content, items after also get it
    -- TODO: Recursively apply to children
    -- TODO: Remove All: items from final output

    return items
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
    if not item.attributes[keyword] then
        item.attributes[keyword] = {}
    end
    -- Create attribute entry with optional name and children
    local attr_entry = {
        name = name,
        children = children
    }
    table.insert(item.attributes[keyword], attr_entry)
end

-- Export for file-manager compatibility
return markdown_parser
