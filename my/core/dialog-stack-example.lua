-- Example configuration for dialog-stack.lua
-- This shows how to define dialog flows for the stack system

local example_flow_definitions = {
    -- Simple two-step questionnaire flow
    questionnaire = {
        main_list = {
            dialog_type = "radio",
            title = "How are you feeling?",
            get_options = function(data_manager, daily_logs, context)
                return {
                    "Great - Full of energy",
                    "Good - Normal energy",
                    "Okay - Slightly tired",
                    "Poor - Very tired",
                    "Terrible - Exhausted"
                }
            end,
            next_step = function(selected_option, context, flow_def)
                -- Store the feeling and move to follow-up
                context.feeling = selected_option
                return flow_def.follow_up
            end
        },

        follow_up = {
            dialog_type = "radio",
            title = "What would help most?",
            get_options = function(data_manager, daily_logs, context)
                -- Different options based on previous answer
                if context.feeling and context.feeling:match("Great") then
                    return {
                        "Keep current routine",
                        "Try something challenging",
                        "Share energy with others"
                    }
                elseif context.feeling and context.feeling:match("Terrible") then
                    return {
                        "Rest and recovery",
                        "Gentle movement",
                        "Talk to someone"
                    }
                else
                    return {
                        "Light activity",
                        "Mindful breathing",
                        "Listen to music"
                    }
                end
            end,
            next_step = function(selected_option, context, flow_def)
                context.recommendation = selected_option
                return nil -- Complete the flow
            end
        }
    },

    -- Custom input flow with validation
    custom_entry = {
        main_list = {
            dialog_type = "edit",
            title = "Enter Custom Item",
            prompt = "What would you like to track?",
            default_text = "",
            next_step = function(custom_input, context, flow_def)
                if custom_input and #custom_input > 0 then
                    context.custom_item = custom_input
                    return flow_def.category_selection
                else
                    -- Could loop back or complete - for simplicity, complete
                    return nil
                end
            end
        },

        category_selection = {
            dialog_type = "radio",
            title = "Choose Category",
            get_options = function(data_manager, daily_logs, context)
                return {
                    "Physical Activity",
                    "Mental/Cognitive",
                    "Social Interaction",
                    "Self-Care",
                    "Work/Productivity"
                }
            end,
            next_step = function(selected_category, context, flow_def)
                context.category = selected_category
                return nil -- Complete the flow
            end
        }
    },

    -- Branching flow based on initial choice
    branching_example = {
        main_list = {
            dialog_type = "radio",
            title = "What do you want to do?",
            get_options = function(data_manager, daily_logs, context)
                return {
                    "Log an activity",
                    "Record a mood",
                    "Add a note"
                }
            end,
            next_step = function(selected_option, context, flow_def)
                if selected_option:match("activity") then
                    return flow_def.activity_input
                elseif selected_option:match("mood") then
                    return flow_def.mood_rating
                else
                    return flow_def.note_input
                end
            end
        },

        activity_input = {
            dialog_type = "edit",
            title = "Activity Details",
            prompt = "Describe the activity:",
            default_text = "",
            next_step = function(activity_text, context, flow_def)
                context.activity = activity_text
                return nil -- Complete the flow
            end
        },

        mood_rating = {
            dialog_type = "radio",
            title = "Rate Your Mood",
            get_options = function(data_manager, daily_logs, context)
                return {
                    "1 - Very Low",
                    "2 - Low",
                    "3 - Neutral",
                    "4 - Good",
                    "5 - Excellent"
                }
            end,
            next_step = function(mood_rating, context, flow_def)
                context.mood = mood_rating
                return nil -- Complete the flow
            end
        },

        note_input = {
            dialog_type = "edit",
            title = "Add Note",
            prompt = "Enter your note:",
            default_text = "",
            next_step = function(note_text, context, flow_def)
                context.note = note_text
                return nil -- Complete the flow
            end
        }
    }
}

-- Example usage in a widget:
--[[

local dialog_stack = require("my.core.dialog-stack")

-- Create flow manager with your definitions
local flow_manager = dialog_stack.create_dialog_flow_manager(example_flow_definitions)

-- In your widget's button click handler:
function on_click(item, pos)
    if item == "questionnaire_button" then
        local status, dialog_config = flow_manager:start_flow("questionnaire")
        if status == "show_dialog" then
            dialog_stack.show_aio_dialog(dialog_config, dialogs)
        end
    elseif item == "custom_entry_button" then
        local status, dialog_config = flow_manager:start_flow("custom_entry")
        if status == "show_dialog" then
            dialog_stack.show_aio_dialog(dialog_config, dialogs)
        end
    end
end

-- In your widget's dialog result handler:
function on_dialog_action(result)
    if flow_manager:get_current_dialog() then
        local status, flow_result = flow_manager:handle_dialog_result(result)

        if status == "show_dialog" then
            dialog_stack.show_aio_dialog(flow_result, dialogs)
        elseif status == "flow_complete" then
            -- Process completed flow
            local category = flow_result.category
            local context = flow_result.context

            -- Handle the completed flow data
            ui:show_text("Flow completed: " .. category)

            -- Return to main widget
            render_widget()
        elseif status == "flow_cancelled" then
            -- User cancelled
            render_widget()
        end

        return true
    end

    return false
end

--]]

return example_flow_definitions