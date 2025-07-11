# Long Covid Widget Interface Design

## Widget Overview
The Long Covid planning widget provides a simple interface for daily capacity level selection and displays the appropriate plan for the current day.

## Widget Layout

### Folded State
```
Long Covid Pacing
🔴 RED | 🟡 YELLOW | 🟢 GREEN
```

### Expanded State
```
Long Covid Pacing - Monday
🔴 RED | 🟡 YELLOW | 🟢 GREEN

Today's Plan:
Work:
• WFH - normal workload
• Standard tasks
• Hourly breaks

Physical:
• Light physio (10 min)
• Basic routine

Evening:
• Quiet evening with partner
• Early bedtime (9:00 PM)
```

## User Interface Elements

### 1. Capacity Level Selection
- **Three buttons**: 🔴 RED, 🟡 YELLOW, 🟢 GREEN
- **Visual feedback**: Selected level highlighted
- **Persistence**: Choice saved to tracking file

### 2. Daily Plan Display
- **Dynamic content**: Shows plan for current day
- **Categorized sections**: Work, Physical, Evening, etc.
- **Bullet points**: Simple, scannable format

### 3. Widget Title
- **Static**: "Long Covid Pacing"
- **Dynamic**: Adds current day when expanded

## Interaction Flow

### Morning Decision Process
1. User opens widget (expanded view)
2. Sees decision criteria summary (optional)
3. Selects capacity level (🔴/🟡/🟢)
4. Views today's plan based on selection
5. Widget saves choice to tracking file

### Throughout the Day
1. User can re-open widget to review plan
2. Can change capacity level if needed (downgrade only)
3. Plan updates automatically

## File Structure Integration

### Data Sources
- `/Long Covid/plans/decision_criteria.md` - Decision criteria
- `/Long Covid/plans/days/{day}.md` - Day-specific templates
- `/Long Covid/plans/tracking.md` - Daily selections log

### Tracking File Format
```markdown
# Long Covid Daily Tracking

## 2025-01-15 (Monday)
- Capacity: 🟡 YELLOW
- HRV: 45 | Sleep: 7hrs | Feel: 6/10
- Plan: Home work day, light physio
- Evening reflection: Good day, managed energy well

## 2025-01-14 (Sunday)
- Capacity: 🟢 GREEN
- Plan: Weekend activities, yoga
- Evening reflection: Felt strong, good weekend
```

## Technical Implementation

### Widget Functions
```lua
-- Core functions
function on_resume()
    load_today_plan()
    load_tracking_data()
    render_widget()
end

function on_click(idx)
    if idx <= 3 then
        select_capacity_level(idx)
    end
end

-- Data parsing
function parse_day_file(day)
    -- Parse markdown file for current day
    -- Return structured data for RED/YELLOW/GREEN
end

function save_daily_choice(level)
    -- Append to tracking.md
    -- Update widget display
end
```

### UI Rendering
```lua
function render_widget()
    local day = get_current_day()
    local plan = get_plan_for_level(selected_level, day)
    
    ui:set_title("Long Covid Pacing - " .. day)
    
    local buttons = {"🔴 RED", "🟡 YELLOW", "🟢 GREEN"}
    local colors = {"#FF4444", "#FFAA00", "#44AA44"}
    
    ui:show_buttons(buttons, colors)
    
    if ui:is_expanded() then
        local lines = format_plan_for_display(plan)
        ui:show_lines(lines)
    end
end
```

## User Experience Goals

### Simplicity
- **Minimal input**: Just capacity level selection
- **Clear visual**: Color-coded capacity levels
- **Quick access**: Plan visible at a glance

### Flexibility
- **Downgrade allowed**: Can change from GREEN to YELLOW to RED
- **No pressure**: RED days are not failures
- **Adaptive**: Plan shows relevant info for chosen level

### Tracking
- **Automatic logging**: Saves daily choices
- **Historical view**: Can review past decisions
- **Reflection support**: Evening notes capability

## Accessibility Features

### Visual Design
- **High contrast**: Clear color differentiation
- **Large text**: Readable on small screens
- **Consistent layout**: Predictable interface

### Interaction
- **Touch targets**: Buttons sized for easy tapping
- **Feedback**: Visual confirmation of selections
- **Error prevention**: Logical capacity transitions

## Future Enhancements

### Phase 2 Features
- **Quick metrics input**: HRV, sleep quality, energy level
- **Smart suggestions**: Based on recent patterns
- **Weekly review**: Summary of capacity trends

### Phase 3 Features
- **Notification reminders**: Morning decision prompt
- **Integration**: With health apps/smartwatch
- **Analytics**: Capacity level trends and insights