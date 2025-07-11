# Markdown Parsing Specification for Long Covid Widget

## Overview
This specification defines how the AIO Launcher Lua script should parse the simplified markdown files for the Long Covid planning widget.

## File Structure to Parse

### 1. Decision Criteria (`decision_criteria.md`)
```markdown
# Daily Decision Criteria

## RED - Recovering
- HRV: Below baseline
- Sleep: <6hrs or poor quality
- Feel: Waking tired, brain fog
- Yesterday: PEM or very demanding day

## YELLOW - Maintaining  
- HRV: Near baseline
- Sleep: 6-7hrs, average quality
- Feel: Some energy but not optimal
- Yesterday: Normal activity, decent recovery

## GREEN - Engaging
- HRV: Above baseline
- Sleep: 7+hrs, good quality
- Feel: Feeling rested, clear thinking
- Yesterday: Good recovery, minimal stress
```

### 2. Day Files (`days/monday.md`, etc.)
```markdown
# Monday - Home Work Day

## RED - Recovering
### Work
- WFH - minimal meetings
- Light tasks only
- Frequent breaks

### Physical
- Skip physio
- Gentle stretching only

### Evening
- No activities, partner time only
- Early bedtime (8:30 PM)

## YELLOW - Maintaining
### Work
- WFH - normal workload
- Standard tasks
- Hourly breaks

### Physical
- Light physio (10 min)
- Basic routine

### Evening
- Quiet evening with partner
- Early bedtime (9:00 PM)

## GREEN - Engaging
### Work
- Can handle complex tasks
- Full meeting load
- Normal productivity

### Physical
- Full physio (15 min)
- Complete routine

### Evening
- Possible social call
- Normal bedtime (9:30 PM)
```

## Lua Parsing Logic

### 1. File Reading Function
```lua
function readFile(filepath)
    local file = io.open(filepath, "r")
    if not file then return nil end
    local content = file:read("*all")
    file:close()
    return content
end
```

### 2. Parse Decision Criteria
```lua
function parseDecisionCriteria(content)
    local criteria = {red = {}, yellow = {}, green = {}}
    local currentLevel = nil
    
    for line in content:gmatch("[^\r\n]+") do
        if line:match("^## RED") then
            currentLevel = "red"
        elseif line:match("^## YELLOW") then
            currentLevel = "yellow"
        elseif line:match("^## GREEN") then
            currentLevel = "green"
        elseif line:match("^%- ") and currentLevel then
            local item = line:match("^%- (.+)")
            table.insert(criteria[currentLevel], item)
        end
    end
    
    return criteria
end
```

### 3. Parse Day Templates
```lua
function parseDayTemplate(content)
    local template = {red = {}, yellow = {}, green = {}}
    local currentLevel = nil
    local currentCategory = nil
    
    for line in content:gmatch("[^\r\n]+") do
        if line:match("^## RED") then
            currentLevel = "red"
        elseif line:match("^## YELLOW") then
            currentLevel = "yellow"
        elseif line:match("^## GREEN") then
            currentLevel = "green"
        elseif line:match("^### ") and currentLevel then
            currentCategory = line:match("^### (.+)")
            template[currentLevel][currentCategory] = {}
        elseif line:match("^%- ") and currentLevel and currentCategory then
            local item = line:match("^%- (.+)")
            table.insert(template[currentLevel][currentCategory], item)
        end
    end
    
    return template
end
```

### 4. Get Day of Week
```lua
function getCurrentDay()
    local days = {"sunday", "monday", "tuesday", "wednesday", "thursday", "friday", "saturday"}
    local dayNum = tonumber(os.date("%w")) + 1
    return days[dayNum]
end
```

### 5. Extract Bedtime
```lua
function extractBedtime(dayTemplate, level)
    local evening = dayTemplate[level]["Evening"]
    if evening then
        for _, item in ipairs(evening) do
            local bedtime = item:match("bedtime %((.-)%)")
            if bedtime then return bedtime end
            
            local early = item:match("Early bedtime %((.-)%)")
            if early then return early end
        end
    end
    return "9:30 PM" -- default
end
```

## Data Structure Output

### Parsed Decision Criteria
```lua
{
    red = {
        "HRV: Below baseline",
        "Sleep: <6hrs or poor quality",
        "Feel: Waking tired, brain fog",
        "Yesterday: PEM or very demanding day"
    },
    yellow = { ... },
    green = { ... }
}
```

### Parsed Day Template
```lua
{
    red = {
        Work = {
            "WFH - minimal meetings",
            "Light tasks only",
            "Frequent breaks"
        },
        Physical = {
            "Skip physio",
            "Gentle stretching only"
        },
        Evening = {
            "No activities, partner time only",
            "Early bedtime (8:30 PM)"
        }
    },
    yellow = { ... },
    green = { ... }
}
```

## Error Handling
- Return `nil` if file cannot be read
- Skip malformed lines
- Provide default values for missing sections
- Log parsing errors for debugging

## Performance Considerations
- Cache parsed files to avoid re-reading
- Only reload when files are modified
- Keep parsed data in memory during widget session