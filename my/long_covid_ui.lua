-- Long Covid Widget - UI Module
-- Handles UI generation, dialog flows, and manager classes

local M = {}

-- Dependencies
local date_utils = require "long_covid_date"
local parsing = require "long_covid_parsing"
local state = require "long_covid_state"
local weekly = require "long_covid_weekly"

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

return M