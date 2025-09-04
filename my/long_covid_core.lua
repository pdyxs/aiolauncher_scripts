-- long_covid_core.lua - Core business logic for Long Covid Pacing Widget
-- This module contains all the business logic that can be tested independently

local M = {}

-- Dependencies
local date_utils = require "long_covid_date"
local parsing = require "long_covid_parsing"
local state = require "long_covid_state"
local weekly = require "long_covid_weekly"

-- Module version for cache detection
M.VERSION = "2.1.0-dialog-stack"

-- Capacity levels
M.levels = {
    {name = "Recovering", color = "#FF4444", key = "red", icon = "bed"},
    {name = "Maintaining", color = "#FFAA00", key = "yellow", icon = "walking"}, 
    {name = "Engaging", color = "#44AA44", key = "green", icon = "rocket-launch"}
}

-- Initialize state module with levels
state.init(M.levels)

function M.check_daily_reset(last_selection_date, selected_level, daily_capacity_log, daily_logs)
    local today = date_utils.get_today_date()
    local changes = {}
    
    if last_selection_date ~= today then
        -- New day - reset to no selection
        changes.selected_level = 0
        changes.last_selection_date = today
        changes.daily_logs = state.purge_old_daily_logs(daily_logs, today)
    else
        -- Same day - check if we have a stored selection
        if daily_capacity_log and daily_capacity_log[today] then
            changes.selected_level = daily_capacity_log[today].capacity
        end
    end
    
    return changes
end

function M.get_daily_logs(daily_logs, date)
    if not daily_logs then
        daily_logs = {}
    end
    
    if not daily_logs[date] then
        daily_logs[date] = {
            symptoms = {},
            activities = {},
            interventions = {},
            energy_levels = {}
        }
    else
        -- Ensure existing logs have energy_levels field (backward compatibility)
        if not daily_logs[date].energy_levels then
            daily_logs[date].energy_levels = {}
        end
    end
    
    return daily_logs[date]
end

function M.log_item(daily_logs, item_type, item_name)
    local today = date_utils.get_today_date()
    local logs = state.get_daily_logs(daily_logs, today)
    
    local category
    if item_type == "symptom" then
        category = logs.symptoms
    elseif item_type == "activity" then
        category = logs.activities
    elseif item_type == "intervention" then
        category = logs.interventions
    else
        return nil, "Invalid item type: " .. tostring(item_type)
    end
    
    category[item_name] = (category[item_name] or 0) + 1
    return true
end

function M.log_energy(daily_logs, energy_level)
    local today = date_utils.get_today_date()
    local logs = state.get_daily_logs(daily_logs, today)
    
    local energy_entry = {
        level = energy_level,
        timestamp = os.time(),
        time_display = os.date("%H:%M")
    }
    
    table.insert(logs.energy_levels, energy_entry)
    return true
end

function M.get_energy_button_color(daily_logs)
    local today = date_utils.get_today_date()
    local logs = state.get_daily_logs(daily_logs, today)
    
    if not logs.energy_levels or #logs.energy_levels == 0 then
        -- Never logged today - red
        return "#dc3545"
    end
    
    -- Find the most recent energy log
    local most_recent_time = 0
    for _, entry in ipairs(logs.energy_levels) do
        if entry.timestamp and entry.timestamp > most_recent_time then
            most_recent_time = entry.timestamp
        end
    end
    
    if most_recent_time == 0 then
        -- No valid timestamps - red
        return "#dc3545"
    end
    
    local current_time = os.time()
    local hours_since_last = (current_time - most_recent_time) / 3600
    
    if hours_since_last >= 4 then
        -- 4+ hours since last log - yellow
        return "#ffc107"
    else
        -- Logged within 4 hours - green
        return "#28a745"
    end
end






-- Legacy parsing functions removed - use parse_items_with_metadata() directly


-- Legacy parsing functions removed - use parse_items_with_metadata() directly

function M.is_required_today(required_info, daily_logs)
    -- Handle weekly requirements (both old and new formats)
    if required_info.weekly_required or (required_info.days and #required_info.days == 1 and required_info.days[1] == "weekly") then
        return weekly.is_weekly_requirement(required_info, daily_logs)
    end
    
    -- Handle daily requirements (existing logic)
    if not required_info.days then
        -- If no days specified, it's daily required unless explicitly set to false
        return required_info.required ~= false
    end
    
    -- Handle specific day requirements (existing logic)
    local today_abbrev = date_utils.get_current_day_abbrev()
    for _, day in ipairs(required_info.days) do
        if day == today_abbrev then
            return true
        end
    end
    
    return false
end

-- ===================================================================
-- CONSOLIDATED COMPLETION LOGIC (Phase 2 Refactoring)
-- ===================================================================

-- Generic function to get required items for today (replaces both activity/intervention variants)
function M.get_required_items_for_today(required_items, daily_logs)
    local today_required = {}
    
    for _, required_info in ipairs(required_items) do
        if M.is_required_today(required_info, daily_logs) then
            table.insert(today_required, required_info.name)
        end
    end
    
    return today_required
end

-- Generic function to check if all required items are completed (replaces both activity/intervention variants)
function M.are_all_required_items_completed(daily_logs, required_items, item_category)
    local required_today = M.get_required_items_for_today(required_items, daily_logs)
    if #required_today == 0 then
        return true
    end
    
    local today = date_utils.get_today_date()
    local logs = state.get_daily_logs(daily_logs, today)
    local category_logs = logs[item_category] or {}
    
    for _, required_item in ipairs(required_today) do
        -- Check exact match first
        local count = category_logs[required_item] or 0
        
        -- Also check for items that start with this base item (e.g., "Work: From Home" matches "Work")
        for logged_item, logged_count in pairs(category_logs) do
            if logged_item ~= required_item then -- Don't double-count exact matches
                local base_item = logged_item:match("^(.-):%s*") or logged_item
                if base_item == required_item then
                    count = count + logged_count
                end
            end
        end
        
        if count == 0 then
            return false
        end
    end
    
    return true
end

-- ===================================================================
-- LEGACY COMPLETION FUNCTIONS (maintained for backward compatibility)
-- ===================================================================

-- Legacy completion and formatting functions removed - use consolidated versions directly

-- ===================================================================
-- CONSOLIDATED FORMATTING FUNCTIONS
-- ===================================================================

-- Configuration-driven formatting with simplified parameters
function M.format_list_items(items, item_type, daily_logs, required_items)
    local today = date_utils.get_today_date()
    local logs = state.get_daily_logs(daily_logs, today)
    
    -- Configuration mapping for item categories
    local item_config = {
        symptom = { category_key = "symptoms", supports_requirements = false },
        activity = { category_key = "activities", supports_requirements = true },
        intervention = { category_key = "interventions", supports_requirements = true }
    }
    
    local config = item_config[item_type]
    if not config then
        return items  -- Unknown item type, return as-is
    end
    
    local category = logs[config.category_key] or {}
    local required_today = {}
    
    -- Get required items for today if this item type supports requirements
    if config.supports_requirements and required_items then
        required_today = M.get_required_items_for_today(required_items, daily_logs)
    end
    
    -- Create set for quick lookup
    local required_set = {}
    for _, req_item in ipairs(required_today) do
        required_set[req_item] = true
    end
    
    local formatted = {}
    for _, item in ipairs(items) do
        -- Count both exact matches and base item matches (for items with options)
        local count = category[item] or 0
        
        -- Also check for items that start with this base item (e.g., "Work: From Home" matches "Work")
        for logged_item, logged_count in pairs(category) do
            if logged_item ~= item then -- Don't double-count exact matches
                local base_item = logged_item:match("^(.-):%s*") or logged_item
                if base_item == item then
                    count = count + logged_count
                end
            end
        end
        
        local is_required = required_set[item]
        
        if count and count > 0 then
            if is_required then
                table.insert(formatted, "✅ " .. item .. " (" .. count .. ")")
            else
                table.insert(formatted, "✓ " .. item .. " (" .. count .. ")")
            end
        else
            if is_required then
                table.insert(formatted, "⚠️ " .. item)
            else
                table.insert(formatted, "   " .. item)
            end
        end
    end
    
    return formatted
end

-- ===================================================================
-- LEGACY FORMATTING FUNCTION (maintained for backward compatibility)
-- ===================================================================

function M.extract_item_name(formatted_item)
    if not formatted_item then
        return ""
    end
    -- First, remove all icons, checkmarks and leading spaces
    local cleaned = formatted_item:gsub("^[✓✅⚠️%s]*", "")
    
    -- Then extract name before count if present: "Fatigue (2)" -> "Fatigue"
    -- This will only match the LAST (number) pattern, preserving existing brackets
    local item_name = cleaned:match("^(.+)%s%(%d+%)$")
    return item_name or cleaned -- Return cleaned version if no count found
end

function M.save_daily_choice(daily_capacity_log, level_idx)
    if level_idx == 0 then
        return daily_capacity_log
    end
    
    local today = date_utils.get_today_date()
    local level_name = M.levels[level_idx].name
    
    if not daily_capacity_log then
        daily_capacity_log = {}
    end
    
    daily_capacity_log[today] = {
        capacity = level_idx,
        capacity_name = level_name,
        timestamp = os.date("%H:%M")
    }
    
    return daily_capacity_log
end

-- Generic logging function with Tasker integration
function M.log_item_with_tasker(daily_logs, item_type, item_name, tasker_callback, ui_callback)
    local success, error_msg = pcall(function()
        local result, err = state.log_item(daily_logs, item_type, item_name)
        if not result then
            error(err or "Unknown error")
        end
        return result
    end)
    
    if not success then
        if ui_callback then
            ui_callback("Error logging " .. item_type .. ": " .. tostring(error_msg))
        end
        return false
    end
    
    local timestamp = os.date("%Y-%m-%d %H:%M:%S")
    local event_type = item_type:gsub("^%l", string.upper) -- Capitalize first letter
    
    if tasker_callback then
        tasker_callback({
            timestamp = timestamp,
            event_type = event_type,
            value = item_name
        })
    end
    
    if ui_callback then
        local message = "✓ " .. event_type .. " logged: " .. item_name
        ui_callback(message)
    end
    
    return true
end

-- Energy logging with Tasker integration
function M.log_energy_with_tasker(daily_logs, energy_level, tasker_callback, ui_callback)
    local success, error_msg = pcall(function()
        local result = state.log_energy(daily_logs, energy_level)
        if not result then
            error("Energy logging failed")
        end
        return result
    end)
    
    if not success then
        if ui_callback then
            ui_callback("Error logging energy: " .. tostring(error_msg))
        end
        return false
    end
    
    local timestamp = os.date("%Y-%m-%d %H:%M:%S")
    
    if tasker_callback then
        tasker_callback({
            timestamp = timestamp,
            event_type = "Energy",
            value = tostring(energy_level)
        })
    end
    
    if ui_callback then
        ui_callback("✓ Energy level " .. tostring(energy_level or "unknown") .. " logged")
    end
    
    return true
end

-- Dialog manager for handling different dialog types
function M.create_dialog_manager()
    local manager = {
        cached_symptoms = nil,
        cached_activities = nil,
        cached_interventions = nil,
        cached_required_activities = nil,
        cached_required_interventions = nil
    }
    
    
    function manager:load_symptoms(file_reader)
        if not self.cached_symptoms then
            local content = file_reader("symptoms.md")
            -- Inline the parsing logic to avoid module reference issues
            if not content then
                self.cached_symptoms = {
                    "Fatigue",
                    "Brain fog", 
                    "Headache",
                    "Shortness of breath",
                    "Joint pain",
                    "Muscle aches",
                    "Sleep issues",
                    "Other..."
                }
            else
                local symptoms = {}
                -- Inline split_lines to avoid module dependencies
                local lines = {}
                for line in content:gmatch("[^\r\n]+") do
                    table.insert(lines, line)
                end
                
                for _, line in ipairs(lines) do
                    if line:match("^%- ") then
                        local symptom = line:match("^%- (.+)")
                        if symptom then
                            table.insert(symptoms, symptom)
                        end
                    end
                end
                
                table.insert(symptoms, "Other...")
                self.cached_symptoms = symptoms
            end
        end
        return self.cached_symptoms
    end
    
    function manager:load_activities(file_reader)
        if not self.cached_activities or not self.cached_required_activities then
            local content = file_reader("activities.md")
            self.cached_activities_content = content
            local parsed = parsing.parse_items_with_metadata(content, "activities")
            self.cached_activities = parsed.display_names
            self.cached_required_activities = parsed.metadata
        end
        return self.cached_activities, self.cached_required_activities
    end
    
    function manager:load_interventions(file_reader)
        if not self.cached_interventions or not self.cached_required_interventions then
            local content = file_reader("interventions.md")
            self.cached_interventions_content = content
            local parsed = parsing.parse_items_with_metadata(content, "interventions")
            self.cached_interventions = parsed.display_names
            self.cached_required_interventions = parsed.metadata
        end
        return self.cached_interventions, self.cached_required_interventions
    end
    
    function manager:get_energy_levels()
        return {"1 - Completely drained", "2 - Very low", "3 - Low", "4 - Below average", 
                "5 - Average", "6 - Above average", "7 - Good", "8 - Very good", 
                "9 - Excellent", "10 - Peak energy"}
    end
    
    function manager:get_activities_content()
        -- Return cached content, or fallback content if no cached content available
        if self.cached_activities_content then
            return self.cached_activities_content
        else
            return [[# Test Activities

## Work
- Work {Options: In Office, From Home}
- Meeting-heavy day

## Physical  
- Walk {Options: Light, Medium, Heavy}
- Yin Yoga {Required: Thu}
- Exercise {Required}

## Daily Living
- Cooking
- Reading]]
        end
    end
    
    function manager:get_interventions_content()
        -- Return cached content, or fallback content if no cached content available
        if self.cached_interventions_content then
            return self.cached_interventions_content
        else
            return [[# Test Interventions

## Medications
- LDN (4mg) {Required}
- Claratyne

## Supplements  
- Salvital {Options: Morning, Evening}
- Vitamin D

## Treatments
- Meditation
- Breathing exercises {Required: Mon,Wed,Fri}]]
        end
    end
    
    
    return manager
end

-- Cache manager for handling file caching and data loading
function M.create_cache_manager()
    local manager = {
        cached_plans = {},
        cached_criteria = nil,
        cached_symptoms = nil,
        cached_activities = nil,
        cached_interventions = nil,
        cached_required_activities = nil,
        cached_required_interventions = nil
    }
    
    function manager:clear_cache()
        self.cached_plans = {}
        self.cached_criteria = nil
        self.cached_symptoms = nil
        self.cached_activities = nil
        self.cached_interventions = nil
        self.cached_required_activities = nil
        self.cached_required_interventions = nil
    end
    
    function manager:load_decision_criteria(file_reader)
        if not self.cached_criteria then
            local content = file_reader("decision_criteria.md")
            self.cached_criteria = parsing.parse_decision_criteria(content)
        end
        return self.cached_criteria
    end
    
    function manager:load_day_plan(day, file_reader)
        if not self.cached_plans[day] then
            local content = file_reader(day .. ".md")
            self.cached_plans[day] = parsing.parse_day_file(content)
        end
        return self.cached_plans[day]
    end
    
    function manager:load_symptoms(file_reader)
        if not self.cached_symptoms then
            local content = file_reader("symptoms.md")
            self.cached_symptoms = parsing.parse_symptoms_file(content)
        end
        return self.cached_symptoms
    end
    
    function manager:load_activities(file_reader)
        if not self.cached_activities or not self.cached_required_activities then
            local content = file_reader("activities.md")
            self.cached_activities_content = content
            local parsed = parsing.parse_items_with_metadata(content, "activities")
            self.cached_activities = parsed.display_names
            self.cached_required_activities = parsed.metadata
        end
        return self.cached_activities, self.cached_required_activities
    end
    
    function manager:load_interventions(file_reader)
        if not self.cached_interventions or not self.cached_required_interventions then
            local content = file_reader("interventions.md")
            self.cached_interventions_content = content
            local parsed = parsing.parse_items_with_metadata(content, "interventions")
            self.cached_interventions = parsed.display_names
            self.cached_required_interventions = parsed.metadata
        end
        return self.cached_interventions, self.cached_required_interventions
    end
    
    function manager:get_required_activities()
        return self.cached_required_activities
    end
    
    function manager:get_required_interventions()
        return self.cached_required_interventions
    end
    
    return manager
end

-- Button action mapper for handling clicks
function M.create_button_mapper()
    local mapper = {}
    
    function mapper:identify_button_action(elem_text)
        if elem_text:find("bed") then
            return "capacity_level", 1
        elseif elem_text:find("walking") then
            return "capacity_level", 2
        elseif elem_text:find("rocket%-launch") then
            return "capacity_level", 3
        elseif elem_text:find("rotate%-right") or elem_text:find("Reset") then
            return "reset", nil
        elseif elem_text:find("sync") then
            return "sync", nil
        elseif elem_text:find("heart%-pulse") then
            return "symptom_dialog", nil
        elseif elem_text:find("bolt%-lightning") then
            return "energy_dialog", nil
        elseif elem_text:find("running") then
            return "activity_dialog", nil
        elseif elem_text:find("pills") then
            return "intervention_dialog", nil
        elseif elem_text == "Back" then
            return "back", nil
        else
            return "unknown", nil
        end
    end
    
    function mapper:can_select_level(current_level, target_level)
        return current_level == 0 or target_level <= current_level
    end
    
    return mapper
end

-- UI element generator
function M.create_ui_generator()
    local generator = {}
    
    function generator:create_capacity_buttons(selected_level)
        local ui_elements = {}
        
        for i, level in ipairs(M.levels) do
            local color, button_text, gravity
            
            if i == selected_level then
                color = level.color
                button_text = "%%fa:" .. level.icon .. "%% " .. level.name
            elseif selected_level == 0 then
                color = level.color
                button_text = "%%fa:" .. level.icon .. "%% " .. level.name
            else
                color = "#888888"
                button_text = "fa:" .. level.icon
            end
            
            gravity = (i == 1) and "center_h" or "anchor_prev"
            
            local button_props = {color = color}
            if gravity then
                button_props.gravity = gravity
            end
            
            table.insert(ui_elements, {"button", button_text, button_props})
            if i < #M.levels then
                table.insert(ui_elements, {"spacer", 1})
            end
        end
        
        table.insert(ui_elements, {"new_line", 1})
        return ui_elements
    end
    
    -- Health tracking buttons with configuration-driven approach
    function generator:create_health_tracking_buttons(daily_logs, required_items_config)
        -- Configuration for button colors based on completion status
        local button_config = {
            activities = {
                icon = "fa:running",
                completed_color = "#28a745",  -- Green when completed
                incomplete_color = "#dc3545"  -- Red when incomplete
            },
            interventions = {
                icon = "fa:pills", 
                completed_color = "#007bff",  -- Blue when completed
                incomplete_color = "#dc3545"  -- Red when incomplete
            }
        }
        
        local colors = {}
        
        -- Calculate colors using consolidated completion logic
        for item_type, items in pairs(required_items_config or {}) do
            local config = button_config[item_type]
            if config and items then
                local completed = M.are_all_required_items_completed(daily_logs, items, item_type)
                colors[item_type] = completed and config.completed_color or config.incomplete_color
            else
                -- Default to red if no requirements or unknown type
                colors[item_type] = "#dc3545"
            end
        end
        
        local energy_color = M.get_energy_button_color(daily_logs)
        
        return {
            {"button", "fa:heart-pulse", {color = "#6c757d", gravity = "center_h"}},
            {"button", "fa:bolt-lightning", {color = energy_color, gravity = "anchor_prev"}},
            {"spacer", 3},
            {"button", button_config.activities.icon, {color = colors.activities or "#dc3545", gravity = "anchor_prev"}},
            {"button", button_config.interventions.icon, {color = colors.interventions or "#dc3545", gravity = "anchor_prev"}}
        }
    end
    
    -- Legacy function removed - use create_health_tracking_buttons() directly
    
    function generator:create_no_selection_content()
        return {
            {"new_line", 2},
            {"text", "<b>Select your capacity level:</b>", {size = 18}},
            {"new_line", 1},
            {"text", "%%fa:bed%% <b>Recovering</b> - Low energy, prioritize rest", {color = "#FF4444"}},
            {"new_line", 1},
            {"text", "%%fa:walking%% <b>Maintaining</b> - Moderate energy, standard routine", {color = "#FFAA00"}},
            {"new_line", 1},
            {"text", "%%fa:rocket-launch%% <b>Engaging</b> - High energy, can handle challenges", {color = "#44AA44"}},
            {"new_line", 2},
            {"button", "%%fa:sync%% Sync Files", {color = "#4CAF50", gravity = "center_h"}},
            {"spacer", 2},
            {"button", "%%fa:rotate-right%% Reset", {color = "#666666", gravity = "anchor_prev"}}
        }
    end
    
    function generator:create_plan_details(day_plan, selected_level)
        if not day_plan then
            return {
                {"text", "No plan available for " .. (date_utils.get_current_day() or "today"), {color = "#ff6b6b"}},
                {"new_line", 2},
                {"button", "%%fa:sync%% Sync Files", {color = "#4CAF50", gravity = "center_h"}},
                {"spacer", 2},
                {"button", "%%fa:rotate-right%% Reset", {color = "#666666", gravity = "anchor_prev"}}
            }
        end
        
        -- Validate selected level is within valid range
        if not M.levels[selected_level] then
            return {
                {"text", "Invalid level selected", {color = "#ff6b6b"}},
                {"new_line", 2},
                {"button", "%%fa:sync%% Sync Files", {color = "#4CAF50", gravity = "center_h"}},
                {"spacer", 2},
                {"button", "%%fa:rotate-right%% Reset", {color = "#666666", gravity = "anchor_prev"}}
            }
        end
        
        local level_key = M.levels[selected_level].key
        local level_plan = day_plan[level_key]
        
        if not level_plan then
            return {
                {"text", "No plan available for selected level", {color = "#ff6b6b"}},
                {"new_line", 2},
                {"button", "%%fa:sync%% Sync Files", {color = "#4CAF50", gravity = "center_h"}},
                {"spacer", 2},
                {"button", "%%fa:rotate-right%% Reset", {color = "#666666", gravity = "anchor_prev"}}
            }
        end
        
        local ui_elements = {}
        
        -- Add overview section
        if level_plan.overview and #level_plan.overview > 0 then
            table.insert(ui_elements, {"text", "<b>Today's Overview:</b>", {size = 18}})
            table.insert(ui_elements, {"new_line", 1})
            for _, overview_line in ipairs(level_plan.overview) do
                local formatted_line = overview_line:gsub("%*%*([^%*]+)%*%*", "<b>%1</b>")
                table.insert(ui_elements, {"text", formatted_line, {size = 16}})
                table.insert(ui_elements, {"new_line", 1})
            end
            table.insert(ui_elements, {"new_line", 1})
        end
        
        -- Add other categories
        for category, items in pairs(level_plan) do
            if category ~= "overview" and #items > 0 then
                table.insert(ui_elements, {"text", "<b>" .. category .. ":</b>", {size = 16}})
                table.insert(ui_elements, {"new_line", 1})
                for _, item in ipairs(items) do
                    table.insert(ui_elements, {"text", "• " .. item})
                    table.insert(ui_elements, {"new_line", 1})
                end
                table.insert(ui_elements, {"new_line", 1})
            end
        end
        
        -- Add action buttons
        table.insert(ui_elements, {"button", "%%fa:sync%% Sync Files", {color = "#4CAF50", gravity = "center_h"}})
        table.insert(ui_elements, {"spacer", 2})
        table.insert(ui_elements, {"button", "%%fa:rotate-right%% Reset", {color = "#666666", gravity = "anchor_prev"}})
        
        return ui_elements
    end
    
    function generator:create_error_content(error_message)
        return {
            {"text", "<b>Selected:</b> " .. (M.levels[1] and M.levels[1].name or "Unknown"), {size = 18}},
            {"new_line", 1},
            {"text", "%%fa:exclamation-triangle%% <b>" .. (error_message or "Can't load plan data") .. "</b>", {color = "#ff6b6b"}},
            {"new_line", 2},
            {"button", "%%fa:sync%% Sync Files", {color = "#4CAF50", gravity = "center_h"}},
            {"spacer", 2},
            {"button", "%%fa:rotate-right%% Reset", {color = "#666666", gravity = "anchor_prev"}}
        }
    end
    
    function generator:create_decision_criteria_ui(level_idx, criteria)
        if not criteria or #criteria == 0 then
            return {
                {"text", "No criteria available", {color = "#ff6b6b"}},
                {"new_line", 2},
                {"button", "Back", {color = "#666666"}}
            }
        end
        
        local ui_elements = {}
        local level = M.levels[level_idx]
        if level then
            table.insert(ui_elements, {"text", "<b>" .. level.name .. " - Decision Criteria:</b>", {size = 18, color = level.color}})
            table.insert(ui_elements, {"new_line", 2})
        end
        
        for _, criterion in ipairs(criteria) do
            table.insert(ui_elements, {"text", "• " .. criterion})
            table.insert(ui_elements, {"new_line", 1})
        end
        
        table.insert(ui_elements, {"new_line", 1})
        table.insert(ui_elements, {"button", "Back", {color = "#666666"}})
        
        return ui_elements
    end
    
    return generator
end

-- Dialog Stack System for Multi-Level Dialog Flows
function M.create_dialog_stack(category)
    local stack = {
        category = category,
        dialogs = {},
        current_context = {}
    }
    
    function stack:push_dialog(dialog_config)
        table.insert(self.dialogs, dialog_config)
    end
    
    function stack:get_current_dialog()
        return self.dialogs[#self.dialogs]
    end
    
    function stack:pop_dialog()
        return table.remove(self.dialogs)
    end
    
    function stack:is_empty()
        return #self.dialogs == 0
    end
    
    function stack:get_full_context()
        local context = {}
        for _, dialog in ipairs(self.dialogs) do
            if dialog.data then
                for key, value in pairs(dialog.data) do
                    context[key] = value
                end
            end
        end
        return context
    end
    
    function stack:clear()
        self.dialogs = {}
        self.current_context = {}
    end
    
    return stack
end

-- Flow Definitions for Dialog Categories
M.flow_definitions = {
    symptom = {
        main_list = {
            dialog_type = "radio",
            title = "Select Symptom", 
            get_options = function(manager, daily_logs)
                local symptoms = manager:load_symptoms(function(filename) return files:read(filename) end)
                return M.format_list_items(symptoms, "symptom", daily_logs, nil)
            end,
            next_step = function(selected_item, context)
                if selected_item == "Other..." then
                    return "custom_input"
                else
                    return "severity"
                end
            end
        },
        
        custom_input = {
            dialog_type = "edit",
            title = "Custom Symptom",
            prompt = "Enter symptom name:",
            default_text = "",
            next_step = function(custom_name, context)
                return "severity"
            end
        },
        
        severity = {
            dialog_type = "radio",
            title = "Symptom Severity",
            get_options = function()
                return {
                    "1 - Minimal", "2 - Mild", "3 - Mild-Moderate", "4 - Moderate", "5 - Moderate-High",
                    "6 - High", "7 - High-Severe", "8 - Severe", "9 - Very Severe", "10 - Extreme"
                }
            end,
            next_step = function(severity_level, context)
                return "complete"
            end
        }
    },
    
    activity = {
        main_list = {
            dialog_type = "radio",
            title = "Log Activity",
            get_options = function(manager, daily_logs, required_activities, required_interventions)
                local activities, req_activities = manager:load_activities(function(filename) return files:read(filename) end)
                return M.format_list_items(activities, "activity", daily_logs, req_activities or required_activities)
            end,
            next_step = function(selected_item, context, manager)
                if selected_item == "Other..." then
                    return "custom_input"
                else
                    -- Check if this item has options
                    local clean_item = M.extract_item_name(selected_item)
                    local activities_content = manager:get_activities_content()
                    local options = parsing.parse_item_options(activities_content, clean_item)
                    if options and #options > 0 then
                        context.selected_item = clean_item
                        context.available_options = options
                        return "options"
                    else
                        return "complete"
                    end
                end
            end
        },
        
        custom_input = {
            dialog_type = "edit",
            title = "Custom Activity",
            prompt = "Enter activity name:",
            default_text = "",
            next_step = function(custom_name, context)
                return "complete"
            end
        },
        
        options = {
            dialog_type = "radio",
            title = "Select Option",
            get_options = function(manager, daily_logs, required_activities, required_interventions, context)
                return context.available_options or {}
            end,
            next_step = function(selected_option, context)
                return "complete"
            end
        }
    },
    
    intervention = {
        main_list = {
            dialog_type = "radio",
            title = "Log Intervention",
            get_options = function(manager, daily_logs, required_activities, required_interventions)
                local interventions, req_interventions = manager:load_interventions(function(filename) return files:read(filename) end)
                return M.format_list_items(interventions, "intervention", daily_logs, req_interventions or required_interventions)
            end,
            next_step = function(selected_item, context, manager)
                if selected_item == "Other..." then
                    return "custom_input"
                else
                    -- Check if this item has options
                    local clean_item = M.extract_item_name(selected_item)
                    local interventions_content = manager:get_interventions_content()
                    local options = parsing.parse_item_options(interventions_content, clean_item)
                    if options and #options > 0 then
                        context.selected_item = clean_item
                        context.available_options = options
                        return "options"
                    else
                        return "complete"
                    end
                end
            end
        },
        
        custom_input = {
            dialog_type = "edit",
            title = "Custom Intervention",
            prompt = "Enter intervention name:",
            default_text = "",
            next_step = function(custom_name, context)
                return "complete"
            end
        },
        
        options = {
            dialog_type = "radio",
            title = "Select Option",
            get_options = function(manager, daily_logs, required_activities, required_interventions, context)
                return context.available_options or {}
            end,
            next_step = function(selected_option, context)
                return "complete"
            end
        }
    },
    
    energy = {
        main_list = {
            dialog_type = "radio",
            title = "Log Energy Level",
            get_options = function(manager)
                -- Energy levels from 1-10 with descriptions
                return {
                    "1 - Completely drained", "2 - Very low", "3 - Low", "4 - Below average", 
                    "5 - Average", "6 - Above average", "7 - Good", "8 - Very good", 
                    "9 - Excellent", "10 - Peak energy"
                }
            end,
            next_step = function(selected_level, context)
                return "complete"
            end
        }
    }
}

-- Dialog Flow Manager
function M.create_dialog_flow_manager()
    local manager = {
        current_stack = nil,
        flow_definitions = M.flow_definitions,
        data_manager = nil,
        ignore_next_cancel = false
    }
    
    function manager:set_data_manager(data_mgr)
        self.data_manager = data_mgr
    end
    
    function manager:set_daily_logs(logs)
        self.daily_logs = logs
    end
    
    function manager:start_flow(category)
        self.current_stack = M.create_dialog_stack(category)
        self.ignore_next_cancel = false
        
        local flow_def = self.flow_definitions[category]
        if not flow_def or not flow_def.main_list then
            return "error", "Unknown flow category: " .. category
        end
        
        return self:push_next_dialog("main_list")
    end
    
    function manager:push_next_dialog(step_name)
        if not self.current_stack then
            return "error", "No active dialog stack"
        end
        
        local flow_def = self.flow_definitions[self.current_stack.category]
        local step_config = flow_def[step_name]
        
        if not step_config then
            return "error", "Unknown dialog step: " .. step_name
        end
        
        local dialog_config = {
            type = step_config.dialog_type,
            name = step_name,
            title = step_config.title,
            data = {},
            step_config = step_config
        }
        
        -- Prepare dialog-specific data
        local context = self.current_stack:get_full_context()
        local required_activities = {}
        local required_interventions = {}
        
        -- Load required items if we're dealing with activity or intervention flows
        if self.current_stack.category == "activity" or self.current_stack.category == "intervention" then
            if self.data_manager then
                local _, req_act = self.data_manager:load_activities(function(filename) return files:read(filename) end)
                local _, req_int = self.data_manager:load_interventions(function(filename) return files:read(filename) end)
                required_activities = req_act or {}
                required_interventions = req_int or {}
            end
        end
        
        if step_config.dialog_type == "list" and step_config.get_items then
            dialog_config.data.items = step_config.get_items(self.data_manager, self.daily_logs, required_activities, required_interventions, context)
        elseif step_config.dialog_type == "radio" and step_config.get_options then
            dialog_config.data.options = step_config.get_options(self.data_manager, self.daily_logs, required_activities, required_interventions, context)
        elseif step_config.dialog_type == "edit" then
            dialog_config.data.prompt = step_config.prompt
            dialog_config.data.default_text = step_config.default_text or ""
        end
        
        self.current_stack:push_dialog(dialog_config)
        
        -- Handle AIO dialog quirk - all dialogs can trigger spurious cancels
        self.ignore_next_cancel = true
        
        return "show_dialog", dialog_config
    end
    
    function manager:handle_dialog_result(result)
        if not self.current_stack or self.current_stack:is_empty() then
            return "error", "No active dialog flow"
        end
        
        if result == -1 then
            return self:handle_cancel()
        end
        
        local current_dialog = self.current_stack:get_current_dialog()
        if not current_dialog then
            return "error", "No current dialog"
        end
        
        local step_config = current_dialog.step_config
        local context = self.current_stack:get_full_context()
        
        -- Process the result based on dialog type
        local processed_result = result
        local next_step_name = nil
        
        if current_dialog.type == "list" and type(result) == "number" then
            local selected_item = M.extract_item_name(current_dialog.data.items[result])
            current_dialog.data.selected_item = selected_item
            processed_result = selected_item
        elseif current_dialog.type == "radio" and type(result) == "number" then
            local selected_option = current_dialog.data.options[result]
            
            if current_dialog.name == "severity" then
                -- Extract severity number from option like "5 - Moderate-High"
                current_dialog.data.selected_option = selected_option
                processed_result = tonumber(selected_option:match("^(%d+)"))
            elseif current_dialog.name == "main_list" then
                -- For symptom/activity/intervention selection, extract the item name and store it
                local selected_item = M.extract_item_name(selected_option)
                current_dialog.data.selected_item = selected_item
                processed_result = selected_item
                -- DON'T set selected_option for main_list - only for actual options dialogs
            elseif current_dialog.name == "options" then
                -- For activity/intervention options, store both option and combined result
                current_dialog.data.selected_option = selected_option
                processed_result = selected_option
            else
                current_dialog.data.selected_option = selected_option
                processed_result = selected_option
            end
        elseif current_dialog.type == "edit" and type(result) == "string" then
            if result == "" then
                return self:handle_cancel()
            end
            current_dialog.data.custom_input = result
            processed_result = result
        end
        
        -- Determine next step
        if step_config.next_step then
            next_step_name = step_config.next_step(processed_result, context, self.data_manager)
            
            -- Store context changes back in current dialog data for persistence
            for key, value in pairs(context) do
                if key ~= "selected_item" and key ~= "custom_input" and key ~= "selected_option" then
                    current_dialog.data[key] = value
                end
            end
        end
        
        if next_step_name == "complete" then
            return self:complete_flow()
        elseif next_step_name then
            return self:push_next_dialog(next_step_name)
        else
            return "error", "No next step defined"
        end
    end
    
    function manager:handle_cancel()
        if self.ignore_next_cancel then
            self.ignore_next_cancel = false
            -- DON'T pop dialog when ignoring - the dialog is still visually open
            return "continue"
        end
        
        if self.current_stack and not self.current_stack:is_empty() then
            self.current_stack:pop_dialog()
            if self.current_stack:is_empty() then
                return self:reset()
            else
                local current_dialog = self.current_stack:get_current_dialog()
                return "show_dialog", current_dialog
            end
        end
        
        return self:reset()
    end
    
    function manager:complete_flow()
        if not self.current_stack then
            return "error", "No active flow to complete"
        end
        
        local category = self.current_stack.category
        local context = self.current_stack:get_full_context()
        
        -- Build the logged item based on the flow
        local logged_item = nil
        local metadata = {}
        
        if category == "symptom" then
            -- Prioritize custom input over selected item (for "Other..." flows)
            logged_item = context.custom_input or context.selected_item
            if context.selected_option then
                -- Extract severity level from the option
                metadata.severity = tonumber(context.selected_option:match("^(%d+)"))
            end
        elseif category == "activity" or category == "intervention" then
            -- Prioritize custom input over selected item (for "Other..." flows)
            logged_item = context.custom_input or context.selected_item
            
            -- If an option was selected, combine item and option
            if context.selected_option and not context.custom_input then
                logged_item = logged_item .. ": " .. context.selected_option
            end
        elseif category == "energy" then
            -- For energy, extract the numeric level from the selected option
            if context.selected_item then
                logged_item = tonumber(context.selected_item:match("^(%d+)"))
            end
        end
        
        self:reset()
        return "flow_complete", {
            category = category,
            item = logged_item,
            metadata = metadata
        }
    end
    
    function manager:reset()
        self.current_stack = nil
        self.ignore_next_cancel = false
        return "flow_cancelled"
    end
    
    function manager:get_current_dialog()
        if self.current_stack then
            return self.current_stack:get_current_dialog()
        end
        return nil
    end
    
    return manager
end

-- Weekly Required Items Functions

-- Extract items marked with {Required: Weekly} from parsed items
function M.get_weekly_required_items(parsed_items)
    local weekly_items = {}
    
    if not parsed_items then
        return weekly_items
    end
    
    for _, item in ipairs(parsed_items) do
        -- Check if item has weekly_required property or contains "Weekly" in its metadata
        if type(item) == "table" and item.weekly_required then
            table.insert(weekly_items, item)
        elseif type(item) == "string" then
            -- For simple string arrays, we need to parse the content to find weekly items
            -- This function expects parsed items with metadata
            -- For now, return empty array for simple strings
        end
    end
    
    return weekly_items
end


-- Override get_weekly_required_items to work with content parsing
function M.get_weekly_required_items(parsed_items)
    -- If parsed_items is actually content string, parse it
    if type(parsed_items) == "string" then
        return M.parse_and_get_weekly_items(parsed_items)
    end
    
    local weekly_items = {}
    
    if not parsed_items then
        return weekly_items
    end
    
    for _, item in ipairs(parsed_items) do
        -- Check if item has weekly_required property
        if type(item) == "table" and item.weekly_required then
            table.insert(weekly_items, item)
        elseif type(item) == "string" then
            -- Simple string items won't have weekly metadata
            -- But we need to check the original content that was used to create these strings
            -- Since parse_activities just returns simple strings, we can't determine weekly status
            -- The test needs a different approach - it should pass the content directly
        end
    end
    
    return weekly_items
end

-- Purge old daily logs but keep 7 days for weekly requirement checking
function M.purge_old_daily_logs(daily_logs, today)
    if not daily_logs then
        return {}
    end
    
    local last_7_dates = date_utils.get_last_n_dates(7)
    local date_set = {}
    for _, date in ipairs(last_7_dates) do
        date_set[date] = true
    end
    
    local new_logs = {}
    for date, logs in pairs(daily_logs) do
        if date_set[date] then
            new_logs[date] = logs
        end
    end
    
    return new_logs
end

-- Check if weekly item needs to be logged (not logged in last 7 days)
function M.is_weekly_item_required(item_name, daily_logs)
    if not item_name or not daily_logs then
        return true -- Required if no logs
    end
    
    local last_7_dates = date_utils.get_last_n_dates(7)
    
    for _, date in ipairs(last_7_dates) do
        local day_logs = daily_logs[date]
        if day_logs then
            -- Check activities
            if day_logs.activities and day_logs.activities[item_name] and day_logs.activities[item_name] > 0 then
                return false -- Found in last 7 days
            end
            
            -- Check interventions
            if day_logs.interventions and day_logs.interventions[item_name] and day_logs.interventions[item_name] > 0 then
                return false -- Found in last 7 days
            end
            
            -- Check symptoms (though less likely for weekly tracking)
            if day_logs.symptoms and day_logs.symptoms[item_name] and day_logs.symptoms[item_name] > 0 then
                return false -- Found in last 7 days
            end
        end
    end
    
    return true -- Not found in last 7 days, so required
end

-- Count number of days in logs
function M.count_log_days(logs)
    if not logs then
        return 0
    end
    
    local count = 0
    for _ in pairs(logs) do
        count = count + 1
    end
    
    return count
end

-- Get button colors for items based on completion status
function M.get_button_colors(items, category, daily_logs)
    local colors = {}
    
    if not items then
        return colors
    end
    
    for _, item in ipairs(items) do
        local item_name = type(item) == "table" and item.name or item
        
        -- Default color
        colors[item_name] = "default"
        
        if type(item) == "table" then
            local today = date_utils.get_today_date()
            local logs = state.get_daily_logs(daily_logs, today)
            
            local category_logs = nil
            if category == "activities" then
                category_logs = logs.activities
            elseif category == "interventions" then
                category_logs = logs.interventions
            elseif category == "symptoms" then
                category_logs = logs.symptoms
            end
            
            local count = category_logs and category_logs[item_name] or 0
            
            if item.required or item.weekly_required then
                if item.weekly_required then
                    -- Weekly required: red if not logged in last 7 days, green if completed today
                    if count > 0 then
                        colors[item_name] = "completed"
                    elseif M.is_weekly_item_required(item_name, daily_logs) then
                        colors[item_name] = "required"
                    else
                        colors[item_name] = "default"
                    end
                elseif item.required then
                    -- Daily required: check if required today
                    if M.is_required_today and M.is_required_today(item, daily_logs) then
                        colors[item_name] = count > 0 and "completed" or "required"
                    else
                        colors[item_name] = count > 0 and "completed" or "default"
                    end
                end
            else
                -- Not required
                colors[item_name] = count > 0 and "completed" or "default"
            end
        end
    end
    
    return colors
end

-- Parsing function wrappers for backward compatibility
-- These delegate to the parsing module
M.escape_pattern = parsing.escape_pattern
M.split_lines = parsing.split_lines
M.parse_decision_criteria = parsing.parse_decision_criteria
M.parse_day_file = parsing.parse_day_file
M.parse_symptoms_file = parsing.parse_symptoms_file
M.parse_items_with_metadata = parsing.parse_items_with_metadata
M.parse_radio_result = parsing.parse_radio_result
M.handle_other_selection = parsing.handle_other_selection
M.parse_item_options = parsing.parse_item_options
M.parse_and_get_weekly_items = parsing.parse_and_get_weekly_items

-- State management function wrappers for backward compatibility
-- These delegate to the state module
M.check_daily_reset = state.check_daily_reset
M.get_daily_logs = state.get_daily_logs
M.log_item = state.log_item
M.log_energy = state.log_energy
M.get_energy_button_color = state.get_energy_button_color
M.save_daily_choice = state.save_daily_choice
M.log_item_with_tasker = state.log_item_with_tasker
M.log_energy_with_tasker = state.log_energy_with_tasker
M.purge_old_daily_logs = state.purge_old_daily_logs

-- Weekly requirements function wrappers for backward compatibility
-- These delegate to the weekly module
M.get_weekly_required_items = weekly.get_weekly_required_items
M.is_weekly_item_required = weekly.is_weekly_item_required
M.is_weekly_requirement = weekly.is_weekly_requirement
M.purge_for_weekly_tracking = weekly.purge_for_weekly_tracking

-- Date utility function wrappers for backward compatibility
-- These delegate to the date_utils module
M.get_current_day = date_utils.get_current_day
M.get_current_day_abbrev = date_utils.get_current_day_abbrev
M.get_today_date = date_utils.get_today_date
M.get_date_days_ago = date_utils.get_date_days_ago
M.get_last_n_dates = date_utils.get_last_n_dates

return M