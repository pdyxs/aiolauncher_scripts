-- test_data.lua - Shared test data for Long Covid Widget tests

local M = {}

-- Mock AIO Launcher APIs
M.mock_files = {}
M.mock_toasts = {}
M.mock_ui_calls = {}

-- Test file contents
M.test_criteria_content = [[## RED
- Feeling extremely fatigued
- Brain fog severe
- Pain levels high

## YELLOW
- Moderate fatigue
- Some brain fog
- Manageable symptoms

## GREEN
- Good energy levels
- Clear thinking
- Minimal symptoms
]]

M.test_monday_content = [[## RED
**Work:** WFH essential only
**Exercise:** Complete rest

### Morning
- Sleep in
- Gentle stretching only

### Afternoon
- Minimal work tasks
- Rest frequently

## YELLOW
**Work:** WFH normal schedule
**Exercise:** Light walking

### Morning
- Normal wake time
- Light breakfast prep

### Afternoon
- Standard work tasks
- 15 min walk

## GREEN
**Work:** Office possible
**Exercise:** Full routine

### Morning
- Early start possible
- Full breakfast prep

### Afternoon
- All work tasks
- 30 min exercise
]]

M.test_activities_content = [[
# Long Covid Activities

## Physical
- Light walk
- Physio (full) {Required: Mon,Wed,Fri}
- Yin Yoga {Required}
- Eye mask {Required: Weekly}

## Work
- Work from home
- Office work

## Social
- Video call with family
- Short visit with friends
- Weekly check-in call {Required: Weekly}
]]

M.test_interventions_content = [[
## Medications
- LDN (4mg) {Required}
- Claratyne

## Supplements  
- Salvital {Required: Mon,Wed,Fri}
- Vitamin D
- Magnesium
- Weekly vitamin shot {Required: Weekly}

## Lifestyle
- Meditation
- Breathing exercises
- Deep tissue massage {Required: Weekly}
]]

M.test_symptoms_content = [[
- Fatigue
- Brain fog
- Headache
- Joint pain
- Muscle aches
- Shortness of breath
- Sleep issues
]]

-- Create a mock file reader function
function M.create_mock_file_reader(custom_files)
    local files = custom_files or {}
    
    -- Add default test files
    files["decision_criteria.md"] = files["decision_criteria.md"] or M.test_criteria_content
    files["monday.md"] = files["monday.md"] or M.test_monday_content
    files["activities.md"] = files["activities.md"] or M.test_activities_content
    files["interventions.md"] = files["interventions.md"] or M.test_interventions_content
    files["symptoms.md"] = files["symptoms.md"] or M.test_symptoms_content
    
    return function(filename)
        return files[filename] or ""
    end
end

-- Create sample daily logs for testing
function M.create_sample_daily_logs()
    return {
        ["2023-01-01"] = {
            symptoms = {["Fatigue"] = 2, ["Headache"] = 1},
            activities = {["Light walk"] = 1, ["Yin Yoga"] = 1}, -- Sunday: only Yin Yoga required
            interventions = {["LDN (4mg)"] = 1, ["Vitamin D"] = 1}, -- Sunday: only LDN required
            energy_levels = {
                {level = 6, timestamp = os.time() - 3600, time_display = "10:00"},
                {level = 7, timestamp = os.time() - 1800, time_display = "10:30"}
            }
        },
        ["2023-01-02"] = {
            symptoms = {["Brain fog"] = 1},
            activities = {["Work from home"] = 1},
            interventions = {["LDN (4mg)"] = 1},
            energy_levels = {}
        }
    }
end

-- Create sample required activities
function M.create_sample_required_activities()
    return {
        {name = "Physio (full)", days = {"mon", "wed", "fri"}},
        {name = "Yin Yoga", days = nil} -- Required every day
    }
end

-- Create sample required interventions
function M.create_sample_required_interventions()
    return {
        {name = "LDN (4mg)", days = nil}, -- Required every day
        {name = "Salvital", days = {"mon", "wed", "fri"}}
    }
end

-- Mock callback functions for testing
function M.create_mock_callbacks()
    local callback_obj = {
        calls = {}
    }
    
    callback_obj.tasker = function(params)
        table.insert(callback_obj.calls, {type = "tasker", params = params})
    end
    
    callback_obj.ui = function(message)
        table.insert(callback_obj.calls, {type = "ui", message = message})
    end
    
    callback_obj.log = function(item_type, item_value)
        table.insert(callback_obj.calls, {type = "log", item_type = item_type, item_value = item_value})
    end
    
    return callback_obj
end

-- Utility function to mock os.date for consistent testing
function M.mock_os_date(fixed_date)
    local original_date = os.date
    local mock_date = function(format, time)
        if format == "%Y-%m-%d" and not time then
            return fixed_date or "2023-01-01"
        elseif format == "%w" and not time then
            -- Calculate day of week for the fixed date
            local target_date = fixed_date or "2023-01-01"
            local year, month, day = target_date:match("(%d+)-(%d+)-(%d+)")
            if year and month and day then
                -- Create a time table and use os.time to get timestamp
                local time_table = {
                    year = tonumber(year),
                    month = tonumber(month),
                    day = tonumber(day),
                    hour = 12  -- Use noon to avoid timezone issues
                }
                local timestamp = os.time(time_table)
                return original_date("%w", timestamp)
            else
                return "0"  -- Fallback to Sunday
            end
        elseif format == "%A" and not time then
            -- Return full day name
            local target_date = fixed_date or "2023-01-01"
            local year, month, day = target_date:match("(%d+)-(%d+)-(%d+)")
            if year and month and day then
                local time_table = {
                    year = tonumber(year),
                    month = tonumber(month),
                    day = tonumber(day),
                    hour = 12
                }
                local timestamp = os.time(time_table)
                return original_date("%A", timestamp)
            else
                return "Sunday"
            end
        end
        return original_date(format, time)
    end
    
    return mock_date, original_date
end

return M