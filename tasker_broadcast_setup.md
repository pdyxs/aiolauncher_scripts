# Tasker Broadcast Setup Guide for Long Covid Widget

## Overview
Instead of copying files (which requires root), this approach has Tasker read the plan files and send the data directly to the AIO widget via broadcast intents.

## Prerequisites

1. **Install Tasker** (if not already installed)
2. **Enable Tasker External Control:**
   - Open Tasker
   - Go to Preferences → Misc
   - Enable "Allow External Access"
3. **Enable AIO Launcher Tasker Integration:**
   - Open AIO Launcher Settings
   - Go to Tasker
   - Enable "Remote API"

## Required Tasker Task: "LongCovid_SendData"

### Step 1: Create New Task
1. Open Tasker
2. Go to Tasks tab
3. Tap "+" to create new task
4. Name it: `LongCovid_SendData`

### Step 2: Add File Read and Broadcast Actions

**Action 1: Read decision_criteria.md**
1. Tap "+" to add action
2. Choose "File" → "Read File"
3. **File:** `/sdcard/Documents/pdyxs/Long Covid/plans/decision_criteria.md`
4. **To Var:** `%criteria_content`

**Action 2: Send decision_criteria to widget**
1. Tap "+" to add action
2. Choose "System" → "Send Intent"
3. **Action:** `ru.execbit.aiolauncher.COMMAND`
4. **Extra:** `cmd:script:long-covid-pacing.lua:plan_data:decision_criteria.md:%criteria_content`
5. **Target:** `Broadcast Receiver`

**Action 3: Read monday.md**
1. Tap "+" to add action
2. Choose "File" → "Read File"
3. **File:** `/sdcard/Documents/pdyxs/Long Covid/plans/days/monday.md`
4. **To Var:** `%monday_content`

**Action 4: Send monday.md to widget**
1. Tap "+" to add action
2. Choose "System" → "Send Intent"
3. **Action:** `ru.execbit.aiolauncher.COMMAND`
4. **Extra:** `cmd:script:long-covid-pacing.lua:plan_data:monday.md:%monday_content`
5. **Target:** `Broadcast Receiver`

**Action 5: Read tuesday.md**
1. Tap "+" to add action
2. Choose "File" → "Read File"
3. **File:** `/sdcard/Documents/pdyxs/Long Covid/plans/days/tuesday.md`
4. **To Var:** `%tuesday_content`

**Action 6: Send tuesday.md to widget**
1. Tap "+" to add action
2. Choose "System" → "Send Intent"
3. **Action:** `ru.execbit.aiolauncher.COMMAND`
4. **Extra:** `cmd:script:long-covid-pacing.lua:plan_data:tuesday.md:%tuesday_content`
5. **Target:** `Broadcast Receiver`

**Action 7: Read wednesday.md**
1. Tap "+" to add action
2. Choose "File" → "Read File"
3. **File:** `/sdcard/Documents/pdyxs/Long Covid/plans/days/wednesday.md`
4. **To Var:** `%wednesday_content`

**Action 8: Send wednesday.md to widget**
1. Tap "+" to add action
2. Choose "System" → "Send Intent"
3. **Action:** `ru.execbit.aiolauncher.COMMAND`
4. **Extra:** `cmd:script:long-covid-pacing.lua:plan_data:wednesday.md:%wednesday_content`
5. **Target:** `Broadcast Receiver`

**Action 9: Read thursday.md**
1. Tap "+" to add action
2. Choose "File" → "Read File"
3. **File:** `/sdcard/Documents/pdyxs/Long Covid/plans/days/thursday.md`
4. **To Var:** `%thursday_content`

**Action 10: Send thursday.md to widget**
1. Tap "+" to add action
2. Choose "System" → "Send Intent"
3. **Action:** `ru.execbit.aiolauncher.COMMAND`
4. **Extra:** `cmd:script:long-covid-pacing.lua:plan_data:thursday.md:%thursday_content`
5. **Target:** `Broadcast Receiver`

**Action 11: Read friday.md**
1. Tap "+" to add action
2. Choose "File" → "Read File"
3. **File:** `/sdcard/Documents/pdyxs/Long Covid/plans/days/friday.md`
4. **To Var:** `%friday_content`

**Action 12: Send friday.md to widget**
1. Tap "+" to add action
2. Choose "System" → "Send Intent"
3. **Action:** `ru.execbit.aiolauncher.COMMAND`
4. **Extra:** `cmd:script:long-covid-pacing.lua:plan_data:friday.md:%friday_content`
5. **Target:** `Broadcast Receiver`

**Action 13: Read weekend.md**
1. Tap "+" to add action
2. Choose "File" → "Read File"
3. **File:** `/sdcard/Documents/pdyxs/Long Covid/plans/days/weekend.md`
4. **To Var:** `%weekend_content`

**Action 14: Send weekend.md to widget**
1. Tap "+" to add action
2. Choose "System" → "Send Intent"
3. **Action:** `ru.execbit.aiolauncher.COMMAND`
4. **Extra:** `cmd:script:long-covid-pacing.lua:plan_data:weekend.md:%weekend_content`
5. **Target:** `Broadcast Receiver`

### Step 3: Save Task
1. Tap "✓" to save the task
2. Go back to main Tasker screen

## Required Tasker Task: "LongCovid_WriteTracking"

### Step 1: Create New Task for Writing Tracking Data
1. Open Tasker
2. Go to Tasks tab
3. Tap "+" to create new task
4. Name it: `LongCovid_WriteTracking`

### Step 2: Add Write File Action
**Action 1: Write Tracking File**
1. Tap "+" to add action
2. Choose "File" → "Write File"
3. **File:** `/sdcard/Documents/pdyxs/Long Covid/plans/tracking.md`
4. **Text:** `%tracking_content` (this variable is passed from the widget)
5. **Append:** `Off` (overwrite file)

### Step 3: Save Task
1. Tap "✓" to save the task
2. Go back to main Tasker screen

## Data Flow Summary

### Plan Data Sync (Documents → Widget)
1. **Widget triggers sync** → Calls `tasker:run_task("LongCovid_SendData")`
2. **Tasker reads files** → Reads all 7 plan files from Documents folder
3. **Tasker sends data** → Broadcasts each file's content to AIO widget
4. **Widget receives data** → Stores data using `files:write()` in AIO directory
5. **Widget reloads** → Parses received data and updates display

### Tracking Data Sync (Widget → Documents)
1. **User makes choice** → Widget calls `save_daily_choice()`
2. **Widget saves locally** → Updates tracking data in AIO directory
3. **Widget calls Tasker** → Runs `LongCovid_WriteTracking` task with tracking data
4. **Tasker receives data** → Gets `%tracking_content` variable from widget
5. **Tasker writes file** → Updates tracking.md in Documents folder

## Testing the Setup

### Manual Test
1. Open AIO Launcher
2. Add the Long Covid Pacing widget
3. If you see "Can't load plan data", tap the sync area
4. You should see "Loading plan data..." then "✓ Plan data updated"
5. The widget should now display your plan data

### Verify Data Transfer
1. The widget should show today's plan based on your selected capacity level
2. Long-press capacity buttons to see decision criteria
3. Your daily selections should be tracked in the widget

### Test Tracking Data Sync
1. Select a capacity level in the widget
2. Check `/sdcard/Documents/pdyxs/Long Covid/plans/tracking.md`
3. Your selection should appear in the tracking file
4. Each new selection should be appended to the file

## Troubleshooting

### "Tasker not available"
- Ensure Tasker is installed and running
- Check that "Allow External Access" is enabled in Tasker
- Check that "Remote API" is enabled in AIO Settings

### "Tasker task failed"
- Check that all file paths are correct (case-sensitive)
- Ensure source files exist in Documents folder
- Test the Tasker task manually first
- Check storage permissions for Tasker

### No data received
- Verify the broadcast intent format is correct
- Check that the script name in the Extra field matches exactly: `long-covid-pacing.lua`
- Ensure the data format is: `cmd:script:long-covid-pacing.lua:plan_data:filename:content`

### Tracking data not syncing
- Check that the `LongCovid_WriteTracking` task exists and is enabled
- Verify the task name matches exactly: `LongCovid_WriteTracking`
- Test the task manually in Tasker with a test variable
- Check storage permissions for Tasker to write to Documents folder

## Optional: Auto-Sync Profile

### Create Profile for Automatic Sync
1. Go to Profiles tab
2. Tap "+" to create new profile
3. Choose "Event" → "File" → "File Modified"
4. **File:** `/sdcard/Documents/pdyxs/Long Covid/plans/days/*`
5. Link to task: `LongCovid_SendData`

This will automatically send updated data whenever you edit files in the Documents folder.

## Advantages of This Approach

✅ **No root required** - Uses standard Android broadcast intents
✅ **Direct data transfer** - No file copying needed
✅ **Reliable** - Works within Android security model
✅ **Flexible** - Easy to modify data format
✅ **Automatic** - Can trigger on file changes

## Data Format

The widget expects broadcast data in this format:
```
cmd:script:long-covid-pacing.lua:plan_data:filename:content
```

Where:
- `cmd:script:long-covid-pacing.lua` - Routes to the correct widget
- `plan_data` - Data type identifier
- `filename` - Name of the file (e.g., "monday.md")
- `content` - The actual file content