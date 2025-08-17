# Long Covid Widget Interface Design

## Widget Overview
The Long Covid planning widget provides a comprehensive interface for daily capacity level selection, activity logging, symptom tracking, and displays the appropriate plan for the current day. All data is automatically logged to a Google Spreadsheet for analysis.

## Widget Layout

### Before Capacity Selection
```
Long Covid Pacing - Monday
     🛏️ Recovering | 🚶 Maintaining | ⚡ Engaging
```

### After Capacity Selection
```
Long Covid Pacing - Monday
🛏️ Recovering | 🚶 Maintaining | ⚡ Engaging                  🏃📋💊
```

### Expanded State with Plan
```
Long Covid Pacing - Monday
🛏️ Recovering | 🚶 Maintaining | ⚡ Engaging                  🏃📋💊

Today's Overview:
Work: WFH normal, hourly breaks
Physical: Light physio (10 min)
Evening: Quiet evening with partner

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

[Sync Files] [Reset]
```

## User Interface Elements

### 1. Capacity Level Selection
- **Three buttons**: 🛏️ Recovering, 🚶 Maintaining, ⚡ Engaging
- **Visual feedback**: Selected level highlighted, others dimmed
- **Alignment**: Centered when no selection, left-aligned after selection
- **Persistence**: Choice saved locally and logged to Google Sheets
- **Restrictions**: Can only downgrade capacity during the day

### 2. Activity, Symptom & Intervention Logging
- **Activity button**: 🏃 Running icon (right-aligned)
- **Symptom button**: 📋 Medical notes icon (next to activity button)
- **Intervention button**: 💊 Pills icon (next to symptom button)
- **Visibility**: Only shown after capacity selection
- **Functionality**: Opens searchable list dialogs with custom "Other..." option
- **Data sources**: Markdown files (activities.md, symptoms.md, interventions.md)
- **Logging**: All entries sent to Google Spreadsheet via AutoSheets

### 3. Daily Plan Display  
- **Dynamic content**: Shows plan for current day and selected capacity
- **Overview section**: Bold summary lines for quick scanning
- **Categorized sections**: Work, Physical, Evening, etc.
- **Bullet points**: Simple, scannable format
- **Error handling**: Sync button when plan data unavailable

### 4. Widget Title
- **Format**: "Long Covid Pacing - [Day]"
- **Dynamic**: Shows current day of week

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
- `activities.md` - Available activities for logging
- `symptoms.md` - Available symptoms for logging
- `interventions.md` - Available interventions for logging

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

## Intervention Tracking

The intervention logging feature allows tracking of medications, supplements, treatments, and lifestyle changes to help determine their effectiveness for long covid management.

### Intervention Categories
- **Medications**: Prescribed and over-the-counter medications
- **Supplements**: Vitamins, minerals, and other supplements
- **Treatments**: Physical therapies, breathing exercises, meditation
- **Lifestyle**: Rest adjustments, hydration, stress management

### Usage Pattern
1. Select daily capacity level first
2. Log interventions throughout the day as they are taken/performed
3. Track patterns over time to identify what helps with specific symptoms or capacity levels
4. Use "Other..." option for unlisted interventions that get added to custom tracking

## Future Enhancements

### Phase 2 Features
- **Quick metrics input**: HRV, sleep quality, energy level
- **Smart suggestions**: Based on recent patterns
- **Weekly review**: Summary of capacity trends
- **Intervention effectiveness**: Analytics on intervention timing vs. symptom patterns

### Phase 3 Features
- **Notification reminders**: Morning decision prompt
- **Integration**: With health apps/smartwatch
- **Analytics**: Capacity level trends and intervention effectiveness insights
- **Dosage tracking**: Amount/frequency for medications and supplements