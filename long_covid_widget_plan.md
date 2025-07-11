# Long Covid Planning Widget Project Plan

## Overview
This project will create an AIO Launcher widget for Long Covid pacing plan management. The widget will help surface daily planning data on Android and allow capacity level selection with progress tracking.

## Phase 1: Plan Data Restructuring (Markdown Format)

### Current Issues with the Plan Format:
- Single large markdown file with complex tables
- Hard to parse programmatically due to markdown formatting
- Mixed content (decision criteria, templates, principles)
- Day-specific info embedded in tables

### Proposed New Structure:
```
Long Covid/plans/
├── widget_data/
│   ├── decision_criteria.md
│   ├── days/
│   │   ├── monday.md
│   │   ├── tuesday.md  
│   │   ├── wednesday.md
│   │   ├── thursday.md
│   │   ├── friday.md
│   │   └── weekend.md
│   └── core_info.md
├── current_plan.md (original - kept for reference)
└── archive/ (existing)
```

### Simplified Markdown Format:
- **Standardized structure** for each day file
- **Consistent headings** for easy parsing
- **Simple bullet points** instead of complex tables
- **Clear capacity level sections** (🔴/🟡/🟢)

### Example Day File Structure:
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
- Early dinner (8:30 PM)

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
- Early wind-down (9:00 PM)

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

## Phase 2: Widget Development

### Lua Parsing Strategy:
- Read markdown files line by line
- Use pattern matching for headings and capacity levels
- Extract bullet points into simple arrays
- Cache parsed data for performance

### Widget Features:
1. **Morning Decision Interface:**
   - Display decision criteria from `decision_criteria.md`
   - Capacity level selection (🔴/🟡/🟢)
   - Simple metric inputs

2. **Daily Plan Display:**
   - Parse today's markdown file
   - Show relevant capacity section
   - Display key activities and bedtime

3. **Progress Tracking:**
   - Save selections to `tracking.md`
   - Simple daily log format

### Technical Approach:
- Use AIO Launcher's Lua scripting capabilities
- File-based storage in Android Documents folder
- Simple UI with clear capacity indicators
- Minimal input required from user

## Implementation Timeline

### Week 1-2: Data Restructuring
- Create simplified markdown data files
- Extract day-specific templates
- Test data parsing locally

### Week 3-4: Widget Development
- Build basic widget interface
- Implement capacity selection
- Add daily plan display

### Week 5: Integration & Testing
- Connect widget to restructured data
- Test on Android device
- Refine UI and functionality

## Key Benefits
- Preserves existing pacing system
- Makes plans easily accessible on mobile
- Enables daily tracking and progress monitoring
- Maintains markdown readability for manual editing
- Follows Long Covid project instructions for archiving and updates