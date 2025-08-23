# Long Covid Widget Interface Design

## Widget Overview
The Long Covid planning widget provides a comprehensive interface for daily capacity level selection, activity logging, symptom tracking, and displays the appropriate plan for the current day. All data is automatically logged to a Google Spreadsheet for analysis.

## Widget Layout

### Collapsed State
```
Long Covid Pacing - Monday
     🛏️ Recovering | 🚶 Maintaining | 🚀 Engaging
        💗 ⚡     🏃 💊
```

### Expanded State with Plan
```
Long Covid Pacing - Monday
     🛏️ Recovering | 🚶 Maintaining | 🚀 Engaging
        💗 ⚡     🏃 💊

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
- **Three buttons**: 🛏️ Recovering, 🚶 Maintaining, 🚀 Engaging
- **Visual feedback**: Selected level highlighted, others dimmed
- **Alignment**: Always centered on first line
- **Persistence**: Choice saved locally and logged to Google Sheets
- **Restrictions**: Can only downgrade capacity during the day

### 2. Health & Activity Logging
- **Symptom button**: 💗 Heart-pulse icon (left group, centered on second line)
  - **Color**: Always grey (#6c757d) - symptoms are not "required"
  - **Dialog Flow**: Multi-level dialog with severity tracking (NEW)
    1. **Symptom Selection**: Radio dialog with formatted symptom options (includes count markers)
    2. **Severity Rating**: Radio dialog with 1-10 scale for all symptoms
    3. **Logging**: Records symptom with severity metadata
  - **AIO Compatibility**: Uses radio dialogs throughout to work around AIO list→radio dialog issues
- **Energy button**: ⚡ Lightning icon (left group, next to symptom button)
  - **Color**: Red (#dc3545) when never logged, Yellow (#ffc107) when 4+ hours since last log, Green (#28a745) when logged within 4 hours
  - **Dialog**: Radio button selection for single-choice energy level
- **Activity button**: 🏃 Running icon (right group, after spacing)
  - **Color**: Red (#dc3545) when required activities incomplete, Green (#28a745) when complete
- **Intervention button**: 💊 Pills icon (right group, next to activity button)
  - **Color**: Red (#dc3545) when required interventions incomplete, Blue (#007bff) when complete
- **Visibility**: Always visible
- **Layout**: Two groups on second line - health tracking (left), activities/interventions (right) with spacing between
- **Functionality**: Opens searchable list dialogs with custom "Other..." option
- **Data sources**: Markdown files (activities.md, symptoms.md, interventions.md)
- **Required items**: Specified in source files using `{Required}` or `{Required: Mon,Wed,Fri}` syntax
- **Logging**: All entries sent to Google Spreadsheet via AutoSheets
- **Daily tracking**: Items logged during the day are tracked with counts
- **Visual differentiation**: Required vs optional items marked differently in dialogs
- **Auto-reset**: Daily tracking clears automatically when a new day starts

### 3. Daily Plan Display  
- **Dynamic content**: Shows plan for current day and selected capacity
- **Overview section**: Bold summary lines for quick scanning
- **Categorized sections**: Work, Physical, Evening, etc.
- **Bullet points**: Simple, scannable format
- **Error handling**: Sync button when plan data unavailable

### 4. Daily Tracking & Visual Differentiation
- **Real-time counts**: Tracks how many times each item is logged per day
- **Visual indicators**: Items marked differently based on required status and completion
- **Dialog formatting**: 
  - Required completed: `"✅ Physio (full) (1)"` - green checkmark with count
  - Optional completed: `"✓ Light walk (2)"` - regular checkmark with count
  - Required incomplete: `"⚠️ Physio (full)"` - warning icon
  - Optional incomplete: `"   Headache"` - indented for alignment
- **Smart extraction**: Handles items with existing brackets (e.g., "Physio (full)")
- **Persistence**: Daily logs stored in preferences, cleared automatically on new day
- **Count accumulation**: Multiple selections of same item increment the count
- **Bracket preservation**: Items like "Exercise (15 min)" maintain original brackets when logged
- **Required item tracking**: Button colors change from red to green/blue when all required items completed

### 5. Widget Title
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
4. **Activity/Symptom/Intervention logging**:
   - **Symptom logging (NEW ENHANCED FLOW)**:
     - Click symptom button to open symptom selection radio dialog
     - Select from radio options (with checkmarks and counts) or choose "Other..." for custom input
     - If "Other..." selected: Enter custom symptom name in edit dialog
     - Choose severity level (1-10 scale): "1 - Minimal" to "10 - Extreme" in radio dialog
     - Item logged with severity metadata (Google Sheets gets full info, local storage gets base symptom name only)
     - Automatic cancellation handling prevents dialog closing issues
     - Can cancel at any level to return to previous step or main widget
   - **Activity/Intervention logging (LEGACY SYSTEM)**:
     - Click buttons to open single dialogs  
     - Previously logged items show with checkmarks and counts
     - Select items to log (counts increment for repeated selections)
     - Custom items available via "Other..." option
5. **Visual feedback**: Toast confirmations show successful logging
6. **Immediate dialog refresh**: Dialog automatically refreshes to show updated counts after logging

## File Structure Integration

### Data Sources
- `/Long Covid/plans/decision_criteria.md` - Decision criteria
- `/Long Covid/plans/days/{day}.md` - Day-specific templates
- `/Long Covid/plans/tracking.md` - Daily selections log
- `activities.md` - Available activities for logging with required specifications
- `symptoms.md` - Available symptoms for logging
- `interventions.md` - Available interventions for logging with required specifications

### Required Items Specification Format
Activities and interventions can be marked as required using special syntax:

**activities.md example:**
```markdown
## Physical
- Light walk
- Physio (full) {Required: Mon,Wed,Fri}
- Yin Yoga {Required}

## Work
- Work from home
```

**interventions.md example:**
```markdown
## Medications
- LDN (4mg) {Required}
- Claratyne

## Supplements
- Salvital {Required: Mon,Wed,Fri}
```

**Syntax:**
- `{Required}` - Required every day
- `{Required: Mon,Wed,Fri}` - Required only on specific days (case insensitive)
- Day abbreviations: `sun`, `mon`, `tue`, `wed`, `thu`, `fri`, `sat`

### Internal Storage (AIO Preferences)
- `daily_logs[date]` - Daily tracking counts for symptoms/activities/interventions
  ```lua
  daily_logs = {
    ["2025-01-21"] = {
      symptoms = {
        ["Fatigue (severity: 5)"] = 1, 
        ["Brain fog (severity: 3)"] = 2,
        ["Custom Headache (severity: 7)"] = 1
      },
      activities = {["Light walk"] = 1, ["Physio (full)"] = 2},
      interventions = {["Vitamin D"] = 1, ["Rest"] = 3}
    }
  }
  ```

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

### Architecture Overview
The widget uses a modular architecture with the following components:

- **Main Widget** (`long-covid-pacing.lua`): User interface handling and AIO integration
- **Core Module** (`long_covid_core.lua`): Business logic and data processing
- **Managers**: Specialized components for different responsibilities
  - `dialog_manager`: Handles legacy dialog interactions and data loading (activities/interventions)
  - `dialog_flow_manager`: **NEW** - Manages multi-level dialog flows with severity tracking (symptoms)
  - `cache_manager`: Manages file caching and data persistence
  - `button_mapper`: Maps button interactions to actions
  - `ui_generator`: Creates UI elements based on state

### Dialog Stack System (NEW)
**Components**:
- `DialogStack` class (`long_covid_core.lua:1082-1123`): Stack operations for multi-level flows
- `Dialog Flow Manager` (`long_covid_core.lua:1170-1351`): Orchestrates complex dialog sequences  
- `Flow Definitions` (`long_covid_core.lua:1126-1167`): Declarative flow configurations

**AIO Platform Compatibility**:
- **Issue**: AIO Launcher has a bug where radio dialogs don't trigger `on_dialog_action` for OK/selection events
- **Solution**: Converted all symptom flow dialogs from list→radio to radio→radio pattern
- **Benefit**: Consistent dialog API usage prevents `on_dialog_action` callback issues
- **Implementation**: Both symptom selection and severity dialogs now use `dialogs:show_radio_dialog()`

**Cancellation Handling**:
- **Issue**: AIO sends spurious cancel events after dialog selections
- **Solution**: `ignore_next_cancel` flag system automatically ignores expected cancel events
- **Trigger**: Set to `true` whenever a dialog is shown, cleared when spurious cancel processed
- **Result**: Multi-level dialogs remain stable during transitions

**Architecture**:
```lua
-- Dialog Stack manages context across multiple dialog levels
dialog_stack = {
    category = "symptom",
    dialogs = {
        {type = "list", name = "main_list", data = {...}},
        {type = "radio", name = "severity", data = {...}}
    }
}

-- Flow Manager coordinates the entire user journey
dialog_flow_manager:start_flow("symptom")
  → dialog_flow_manager:handle_dialog_result(user_selection)  
  → dialog_flow_manager:complete_flow() -- with severity metadata
```

### Key Functions
```lua
-- Main widget lifecycle
function on_resume()
    load_prefs_data()        -- Load preferences into globals
    check_daily_reset()      -- Clear tracking on new day
    load_data()             -- Load plan files via cache_manager
    render_widget()         -- Generate UI via ui_generator
end

function on_click(idx)
    -- Uses button_mapper to identify action from clicked element
    local action_type, level = button_mapper:identify_button_action(elem_text)
    -- Handles capacity selection, dialog opening, etc.
end

-- Core business logic (from long_covid_core.lua)
function M.log_item(daily_logs, item_type, item_name)
    -- Increment count for symptoms/activities/interventions
    -- Thread-safe logging with immediate persistence
end

function M.format_list_items(items, item_type, daily_logs, required_activities, required_interventions)
    -- Add checkmarks and counts to logged items
    -- Visual differentiation for required vs optional items
end

function M.check_daily_reset(last_selection_date, selected_level, daily_capacity_log, daily_logs)
    -- Handles daily reset logic and preference management
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
- **Automatic logging**: Saves daily choices and activity/symptom/intervention logs
- **Visual feedback**: Clear indication of what's been logged during the day
- **Count tracking**: Shows frequency of repeated activities/symptoms/interventions
- **Historical view**: Can review past decisions
- **Reflection support**: Evening notes capability
- **Smart reset**: Daily logs clear automatically on new day

## Accessibility Features

### Visual Design
- **High contrast**: Clear color differentiation
- **Large text**: Readable on small screens
- **Consistent layout**: Predictable interface

### Interaction
- **Touch targets**: Buttons sized for easy tapping
- **Feedback**: Visual confirmation of selections
- **Error prevention**: Logical capacity transitions

## Daily Tracking Examples

### Dialog Visual Differentiation
When opening activity/symptom/intervention dialogs, items are visually differentiated based on daily usage:

**Example Activity Dialog:**
```
Log Activity
┌─────────────────────────────────┐
│ ✅ Physio (full) (1)           │  ← Required & completed (green checkmark)
│ ✓ Light walk (2)               │  ← Optional & logged (regular checkmark)
│ ⚠️ Yin Yoga                    │  ← Required & not completed (warning)
│    Desk work                   │  ← Optional & not logged (spacing)
│    Reading                     │  ← Optional & not logged (spacing)
│    Other...                    │  ← Custom option
└─────────────────────────────────┘
```

**Key Features:**
- **Green checkmarks (✅)**: Required items that have been completed
- **Regular checkmarks (✓)**: Optional items that have been logged
- **Warning icons (⚠️)**: Required items that haven't been completed yet
- **Count numbers**: Show frequency `(1)`, `(2)`, `(3)`, etc.
- **Indentation**: Unlogged optional items indented for visual alignment
- **Bracket handling**: Items like "Physio (full)" preserve original brackets
- **Real-time updates**: Counts increment immediately when items are selected
- **Instant feedback**: Dialog refreshes automatically after logging to show updated counts
- **Button colors**: Activity/intervention buttons are red until all required items completed

## Energy Level Tracking

The energy level logging feature provides continuous monitoring of energy throughout the day on a 1-10 scale, with time-based visual feedback to encourage regular logging.

### Energy Levels Scale
1. **Completely drained** - No energy left
2. **Very low** - Struggling to function
3. **Low** - Below normal, limited activity
4. **Below average** - Functioning but tired
5. **Average** - Normal baseline energy
6. **Above average** - Good energy levels
7. **Good** - Feeling strong and capable
8. **Very good** - High energy, productive
9. **Excellent** - Peak performance
10. **Peak energy** - Maximum energy and vitality

### Button Color Logic
- **Red (#dc3545)**: Never logged today - encourages first log
- **Yellow (#ffc107)**: Last logged 4+ hours ago - reminder to update
- **Green (#28a745)**: Logged within last 4 hours - up to date

### Data Storage
Energy levels are stored with timestamps, allowing for:
- Time-series analysis of daily energy patterns
- Correlation with activities, symptoms, and interventions
- Identification of energy peaks and crashes
- Long-term trend analysis

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

## Symptom Severity Tracking (NEW)

### Severity Scale
All symptoms are now tracked with a 1-10 severity scale:
- **1 - Minimal**: Barely noticeable, doesn't affect daily activities
- **2 - Mild**: Noticeable but easily manageable
- **3 - Mild-Moderate**: Slightly bothersome, minor impact on activities
- **4 - Moderate**: Noticeable impact, some difficulty with tasks
- **5 - Moderate-High**: Significant discomfort, affects concentration
- **6 - High**: Major impact on daily functioning
- **7 - High-Severe**: Very difficult to manage, limited ability to function
- **8 - Severe**: Extremely difficult, major limitations
- **9 - Very Severe**: Nearly incapacitating, very limited function
- **10 - Extreme**: Completely incapacitating, unable to function

### Enhanced Logging Examples
**Before (Legacy)**: `Fatigue`, `Brain fog`, `Headache`
**Now (With Severity)**: `Fatigue (severity: 7)`, `Brain fog (severity: 4)`, `Custom Migraine (severity: 9)`

### Multi-Level Dialog Flow
1. **Symptom Selection**: Choose from radio dialog options or "Other..." for custom entry
2. **Custom Input** (if needed): Enter custom symptom name in edit dialog 
3. **Severity Rating**: Select 1-10 scale in radio dialog for all symptoms
4. **Completion**: Symptom logged with severity metadata
   - Google Sheets: Full severity info (e.g., "Fatigue (severity: 5)")
   - Local storage: Base symptom name only (e.g., "Fatigue") for count markers

### Data Benefits
- **Pattern recognition**: Track severity trends over time
- **Treatment correlation**: See which interventions help specific severity levels
- **Capacity planning**: Understand symptom severity impact on daily capacity
- **Medical communication**: Provide precise symptom data to healthcare providers

## Testing Coverage

The widget includes comprehensive test coverage with **87 total tests** across 8 test suites ensuring reliability:

### Test Suites
1. **Core Business Logic** (17 tests): File parsing, data management, calculations, energy tracking
2. **Logging Functions** (14 tests): Tasker integration, error handling, callback validation
3. **Dialog Manager** (14 tests): State management, data loading, result processing
4. **Cache Manager** (11 tests): File caching, data loading, cache invalidation
5. **Button Mapper** (17 tests): Action identification, level validation, pattern matching
6. **UI Generator** (14 tests): Element creation, state-based rendering, layout management
7. **Dialog Stack Core** (13 tests): **NEW** - Multi-level flow management, stack operations, context preservation
8. **Dialog Stack Integration** (6 tests): **NEW** - Radio dialog compatibility, severity tracking, cancellation handling, AIO platform workarounds

### Key Coverage Areas
- **Core functionality**: Preferences, daily reset, capacity selection
- **Data parsing**: Decision criteria, day files, current day calculation
- **UI interaction**: Button clicks, widget rendering, level restrictions
- **Daily tracking**: Log storage, count tracking, formatting with counts
- **Visual differentiation**: Checkmark display, bracket preservation
- **Dialog refresh**: Automatic dialog updates after logging
- **Required activities**: Parsing required specifications, day-specific requirements
- **Completion status**: Button color logic, required vs optional tracking
- **Multi-level dialogs**: **NEW** - Stack operations, context preservation, flow state management
- **Severity tracking**: **NEW** - 1-10 scale validation, metadata storage, complete flow testing
- **Custom input flows**: **NEW** - "Other..." handling, custom symptom entry, validation
- **Cancellation handling**: **NEW** - Multi-level cancel, back navigation, edge case recovery
- **Visual markers**: Warning icons for incomplete required items
- **Energy logging**: Time-based color logic, multiple entries, timing validation
- **Edge cases**: Items with existing brackets, complex naming scenarios

### Running Tests
```bash
cd tests
lua run_all_tests.lua  # Run complete test suite (87 tests)
```

The modular architecture allows for focused testing of each component, with the widget reduced from 680 lines to 428 lines (-37%) while maintaining full functionality through the core module.