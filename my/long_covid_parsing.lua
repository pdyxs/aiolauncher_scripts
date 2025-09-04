-- Long Covid Widget - Parsing Module
-- Handles all file parsing and text processing functionality

local M = {}

-- Helper function to escape pattern characters
function M.escape_pattern(text)
    return text:gsub("([^%w])", "%%%1")
end

-- Helper function to split text into lines
function M.split_lines(text)
    local lines = {}
    for line in text:gmatch("[^\r\n]+") do
        table.insert(lines, line)
    end
    return lines
end

function M.parse_decision_criteria(content)
    if not content then
        return {red = {}, yellow = {}, green = {}}
    end
    
    local criteria = {red = {}, yellow = {}, green = {}}
    local current_level = nil
    
    local lines = M.split_lines(content)
    for _, line in ipairs(lines) do
        if line:match("^## RED") then
            current_level = "red"
        elseif line:match("^## YELLOW") then
            current_level = "yellow"
        elseif line:match("^## GREEN") then
            current_level = "green"
        elseif line:match("^%- ") and current_level then
            local item = line:match("^%- (.+)")
            if item then
                table.insert(criteria[current_level], item)
            end
        end
    end
    
    return criteria
end

function M.parse_day_file(content)
    if not content then
        return {red = {}, yellow = {}, green = {}}
    end
    
    local template = {red = {}, yellow = {}, green = {}}
    local current_level = nil
    local current_category = nil
    
    local lines = M.split_lines(content)
    for _, line in ipairs(lines) do
        if line:match("^## RED") then
            current_level = "red"
            current_category = nil
            template[current_level].overview = {}
        elseif line:match("^## YELLOW") then
            current_level = "yellow"
            current_category = nil
            template[current_level].overview = {}
        elseif line:match("^## GREEN") then
            current_level = "green"
            current_category = nil
            template[current_level].overview = {}
        elseif line:match("^%*%*") and current_level and not current_category then
            table.insert(template[current_level].overview, line)
        elseif line:match("^### ") and current_level then
            current_category = line:match("^### (.+)")
            if current_category then
                template[current_level][current_category] = {}
            end
        elseif line:match("^#### ") and current_level then
            current_category = line:match("^#### (.+)")
            if current_category then
                template[current_level][current_category] = {}
            end
        elseif line:match("^%- ") and current_level and current_category then
            local item = line:match("^%- (.+)")
            if item then
                table.insert(template[current_level][current_category], item)
            end
        end
    end
    
    return template
end

function M.parse_symptoms_file(content)
    if not content then
        return {
            "Fatigue",
            "Brain fog", 
            "Headache",
            "Shortness of breath",
            "Joint pain",
            "Muscle aches",
            "Sleep issues",
            "Other..."
        }
    end
    
    local symptoms = {}
    local lines = M.split_lines(content)
    
    for _, line in ipairs(lines) do
        if line:match("^%- ") then
            local symptom = line:match("^%- (.+)")
            if symptom then
                table.insert(symptoms, symptom)
            end
        end
    end
    
    -- Always add "Other..." as the last option
    table.insert(symptoms, "Other...")
    
    return symptoms
end

--- Consolidated parsing infrastructure with metadata-first design
function M.parse_items_with_metadata(content, item_type)
    -- Handle fallback content
    if not content then
        local fallback_content
        if item_type == "activities" then
            fallback_content = [[# Test Activities

## Work
- Work {Options: In Office, From Home}
- Meeting-heavy day

## Physical  
- Walk {Options: Light, Medium, Heavy}
- Yin Yoga {Required: Thu}
- Exercise {Required}
- Eye mask {Required: Weekly}

## Daily Living
- Cooking
- Reading]]
        elseif item_type == "interventions" then
            fallback_content = [[# Test Interventions

## Medications
- LDN (4mg) {Required}
- Claratyne

## Supplements  
- Salvital {Options: Morning, Evening}
- Vitamin D
- Weekly vitamin shot {Required: Weekly}

## Treatments
- Meditation
- Breathing exercises {Required: Mon,Wed,Fri}
- Deep tissue massage {Required: Weekly}]]
        else
            return { items = {}, metadata = {}, display_names = {} }
        end
        return M.parse_items_with_metadata(fallback_content, item_type)
    end
    
    local items = {}
    local metadata = {}
    local display_names = {}
    local lines = M.split_lines(content)
    
    for _, line in ipairs(lines) do
        if line:match("^%- ") then
            local item_line = line:match("^%- (.+)")
            if item_line then
                -- Extract clean item name (removing all markup)
                local clean_name = item_line:match("^(.-)%s*%{") or item_line
                clean_name = clean_name:gsub("^%s+", ""):gsub("%s+$", "")  -- Strip whitespace
                
                -- Create metadata object
                local item_metadata = {
                    name = clean_name,
                    required = false,
                    weekly_required = false,
                    has_options = false,
                    days = nil
                }
                
                -- Parse {Required} variants
                if item_line:match("%{Required%}") then
                    item_metadata.required = true
                elseif item_line:match("%{Required:%s*Weekly%}") then
                    item_metadata.weekly_required = true
                elseif item_line:match("%{Required:%s*([^%}]+)%}") then
                    local days_match = item_line:match("%{Required:%s*([^%}]+)%}")
                    if days_match and days_match ~= "Weekly" then
                        item_metadata.required = true
                        item_metadata.days = {}
                        for day_abbrev in days_match:gmatch("([^,%s]+)") do
                            table.insert(item_metadata.days, day_abbrev:lower())
                        end
                    end
                end
                
                -- Parse {Options:} 
                if item_line:match("%{Options:") then
                    item_metadata.has_options = true
                end
                
                table.insert(items, clean_name)
                table.insert(metadata, item_metadata)
                table.insert(display_names, clean_name)
            end
        end
    end
    
    -- Always add "Other..." as the last option for display
    table.insert(display_names, "Other...")
    
    return {
        items = items,
        metadata = metadata,
        display_names = display_names
    }
end

-- Shared dialog processing utilities
function M.parse_radio_result(options, selected_index)
    if not options or not selected_index then
        return nil
    end
    
    if selected_index < 1 or selected_index > #options then
        return nil
    end
    
    return options[selected_index]
end

function M.handle_other_selection(custom_input)
    -- Simple pass-through for now, could add validation/processing later
    return custom_input
end

-- Parse options from activities/interventions with {Options: ...} syntax
function M.parse_item_options(content, item_name)
    if not content or not item_name then
        return nil
    end
    
    local lines = M.split_lines(content)
    
    for _, line in ipairs(lines) do
        if line:match("^%- ") then
            local full_line = line:match("^%- (.+)")
            if full_line then
                -- Check if this line matches our item name
                local clean_name = full_line:match("^(.-)%s*%{") or full_line
                if clean_name == item_name then
                    -- Look for {Options: ...} pattern
                    local options_match = full_line:match("%{Options:%s*([^%}]+)%}")
                    if options_match then
                        local options = {}
                        for option in options_match:gmatch("([^,]+)") do
                            table.insert(options, option:match("^%s*(.-)%s*$")) -- trim whitespace
                        end
                        return options
                    end
                end
            end
        end
    end
    
    return nil
end

-- Parse items from content and extract weekly required ones
function M.parse_and_get_weekly_items(content)
    if not content then
        return {}
    end
    
    local weekly_items = {}
    local lines = M.split_lines(content)
    
    for _, line in ipairs(lines) do
        if line:match("^%- ") then
            local item_line = line:match("^%- (.+)")
            if item_line and item_line:match("%{Required:%s*Weekly%}") then
                local item_name = item_line:match("^(.-)%s*%{Required:")
                if item_name then
                    table.insert(weekly_items, item_name)
                end
            end
        end
    end
    
    return weekly_items
end

return M