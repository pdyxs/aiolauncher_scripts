# DRAFT - Dialog Stack Technical Implementation Plan

## Architecture Overview

### Core Dialog Stack Structure
```lua
dialog_stack = {
    category = "symptom",  -- High-level category: "symptom", "activity", "intervention"  
    dialogs = {
        {
            type = "list",           -- Dialog implementation type: "list", "radio", "edit"
            name = "main_list",      -- Specific dialog identifier within flow
            data = {                 -- Dialog-specific data and context
                items = symptoms_list,
                selected_item = nil
            },
            ignore_next_cancel = true,  -- Handle AIO quirks (list dialogs don't auto-close)
            on_result = function(result, stack) ... end,  -- Handle dialog result
            on_cancel = function(stack) ... end           -- Handle cancel action
        }
    }
}
```

### Flow Definition System
Each category defines its complete dialog flow:

```lua
flow_definitions = {
    symptom = {
        main_list = {
            dialog_type = "list",
            get_items = function() return load_symptoms() end,
            next_step = function(selected_item)
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
            next_step = function(custom_name)
                return "severity"
            end
        },
        
        severity = {
            dialog_type = "radio",
            title = "Symptom Severity",
            get_options = function() return severity_levels_1_to_10 end,
            next_step = function(severity_level)
                return "complete"  -- End of flow
            end
        }
    },
    
    activity = {
        main_list = {
            dialog_type = "list",
            get_items = function() return load_activities() end,
            next_step = function(selected_item, item_metadata)
                if selected_item == "Other..." then
                    return "custom_input"
                elseif item_metadata and item_metadata.has_intensity_options then
                    return "intensity"
                else
                    return "complete"
                end
            end
        },
        
        intensity = {
            dialog_type = "radio", 
            title = "Activity Intensity",
            get_options = function(context) 
                return context.selected_item.intensity_options 
            end,
            next_step = function(intensity_choice)
                return "complete"
            end
        }
    }
}
```

## Core Components

### 1. DialogStack Class
```lua
local DialogStack = {}

function DialogStack:new(category)
    return {
        category = category,
        dialogs = {},
        current_context = {}
    }
end

function DialogStack:push_dialog(dialog_config)
    table.insert(self.dialogs, dialog_config)
end

function DialogStack:get_current_dialog()
    return self.dialogs[#self.dialogs]
end

function DialogStack:pop_dialog()
    return table.remove(self.dialogs)
end

function DialogStack:get_full_context()
    -- Aggregate data from all dialogs in stack
    local context = {}
    for _, dialog in ipairs(self.dialogs) do
        for key, value in pairs(dialog.data) do
            context[key] = value
        end
    end
    return context
end
```

### 2. Dialog Flow Manager
```lua
function create_dialog_flow_manager()
    local manager = {
        current_stack = nil,
        flow_definitions = flow_definitions
    }
    
    function manager:start_flow(category)
        self.current_stack = DialogStack:new(category)
        local first_step = self.flow_definitions[category].main_list
        self:push_next_dialog("main_list", first_step)
    end
    
    function manager:handle_dialog_result(result)
        if not self.current_stack then return "no_active_flow" end
        
        local current_dialog = self.current_stack:get_current_dialog()
        if not current_dialog then return "no_current_dialog" end
        
        if result == -1 then
            return self:handle_cancel()
        end
        
        -- Process result and determine next action
        local flow_def = self.flow_definitions[self.current_stack.category]
        local current_step = flow_def[current_dialog.name]
        
        local next_step_name = current_step.next_step(result, self.current_stack:get_full_context())
        
        if next_step_name == "complete" then
            return self:complete_flow()
        else
            return self:push_next_dialog(next_step_name, flow_def[next_step_name])
        end
    end
    
    return manager
end
```

### 3. AIO Integration Layer
```lua
-- Global callback that routes to active dialog stack
function on_dialog_action(result)
    if not dialog_flow_manager or not dialog_flow_manager.current_stack then
        return -- No active dialog flow
    end
    
    local action = dialog_flow_manager:handle_dialog_result(result)
    
    if action == "show_dialog" then
        local current_dialog = dialog_flow_manager.current_stack:get_current_dialog()
        show_aio_dialog(current_dialog)
    elseif action == "flow_complete" then
        dialog_flow_manager:reset()
        refresh_widget() -- Return to main widget
    elseif action == "flow_cancelled" then
        dialog_flow_manager:reset()
        refresh_widget()
    end
end

function show_aio_dialog(dialog_config)
    if dialog_config.type == "list" then
        dialogs:show_list_dialog({
            title = dialog_config.title,
            list = dialog_config.data.items
        })
    elseif dialog_config.type == "radio" then
        dialogs:show_radio_dialog(dialog_config.title, dialog_config.data.options, 0)
    elseif dialog_config.type == "edit" then
        dialogs:show_edit_dialog(dialog_config.title, dialog_config.prompt, dialog_config.default_text or "")
    end
end
```

## Edge Case Handling

### List Dialog Cancel Quirk
```lua
{
    type = "list",
    name = "main_list", 
    ignore_next_cancel = true,  -- AIO sends extra cancel after list selection
    on_cancel = function(stack)
        if not self.ignore_next_cancel then
            return "cancel_flow"
        else
            self.ignore_next_cancel = false
            return "continue"
        end
    end
}
```

### Widget Reload State Recovery
```lua
-- Store minimal state in preferences for recovery
prefs.dialog_flow_state = {
    category = "symptom",
    current_step = "severity",
    context = {selected_item = "Fatigue", custom_input = nil}
}

function restore_dialog_flow_from_prefs()
    if prefs.dialog_flow_state then
        dialog_flow_manager:restore_flow(prefs.dialog_flow_state)
        prefs.dialog_flow_state = nil -- Clear after restore
    end
end
```

## Migration Strategy

### Phase 1: Core Infrastructure (Session 1)
- Implement DialogStack class
- Create dialog flow manager  
- Add AIO integration layer
- Write comprehensive tests for stack operations

### Phase 2: Symptoms Flow (Session 2)
- Define symptoms flow configuration
- Implement severity selection dialog
- Migrate existing symptoms functionality
- Test multi-level flow end-to-end

### Phase 3: Activities & Interventions (Session 3)
- Add intensity/options flows for activities and interventions  
- Implement conditional flow branching
- Add back navigation support
- Performance testing and optimization

### Phase 4: Enhanced Features (Session 4)
- Add flow state persistence across widget reloads
- Implement user experience improvements (breadcrumbs, progress indicators)
- Comprehensive edge case testing
- Documentation updates

## Implementation Notes for Future Sessions

### Key Files to Modify
- `/my/long_covid_core.lua` - Add dialog stack classes and flow definitions
- `/my/long-covid-pacing.lua` - Replace current dialog manager with flow manager
- `/tests/` - Add comprehensive dialog flow tests

### Testing Strategy  
- Unit tests for DialogStack class operations
- Integration tests for complete dialog flows  
- Edge case tests for AIO quirks and error conditions
- Performance tests to ensure no regression

### Validation Criteria
Before marking any phase complete:
1. All existing functionality must continue to work
2. New dialog flows must handle edge cases gracefully
3. Test suite must pass completely
4. No performance regression in widget responsiveness