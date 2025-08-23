# Manual Testing Checklist - Dialog Stack System

## Overview
This checklist focuses on testing the new dialog stack system for symptoms with severity tracking, ensuring it integrates properly with existing widget functionality without breaking backwards compatibility.

## Pre-Testing Setup
- [✅] Ensure widget loads without errors
- [ ] Verify baseline functionality: capacity levels, energy/activity/intervention buttons still work
- [✅] Note current daily logs to compare before/after

---

## ✅ NEW: Symptoms Dialog Stack Testing

### Test 1: Basic Symptoms Flow (List → Severity → Log)
1. **Start Flow**:
   - [✅] Click symptom button (💗 heart-pulse icon)
   - [✅] Verify "Select Symptom" dialog appears
   - [✅] Verify list shows default symptoms with formatting (checkmarks/counts if previously logged)

2. **Select Symptom**:
   - [✅] Select "Fatigue" (or any symptom from list)
   - [✅] Verify "Symptom Severity" dialog appears automatically
   - [✅] Verify severity options show: "1 - Minimal" through "10 - Extreme"

3. **Select Severity**:
   - [✅] Select severity level (e.g., "5 - Moderate-High")
   - [✅] Verify dialog closes and returns to main widget
   - [✅] Verify toast confirmation shows successful logging
   - [✅] Verify symptom logged as: `"Fatigue (severity: 5)"`

### Test 2: Custom Symptom Flow (List → Custom Input → Severity → Log)
1. **Start Flow**:
   - [✅] Click symptom button
   - [✅] Select "Other..." from the list

2. **Custom Input**:
   - [✅] Verify "Custom Symptom" edit dialog appears
   - [✅] Enter custom symptom: "My Test Symptom"
   - [✅] Confirm entry

3. **Severity Selection**:
   - [✅] Verify "Symptom Severity" dialog appears >> Dialog doesn't appear, symptom is NOT logged
   - [✅] Select severity (e.g., "7 - High-Severe")
   - [✅] Verify returns to widget with confirmation
   - [✅] Verify logged as: `"My Test Symptom (severity: 7)"`

### Test 3: Dialog Cancellation Testing
1. **Cancel at Symptom List**:
   - [✅] Click symptom button
   - [✅] Press back/cancel in symptom list
   - [✅] Should return to widget with no logging

2. **Cancel at Severity Level**:
   - [✅] Click symptom button → select symptom → reach severity dialog >> Severity dialog doesn't appear
   - [✅] Press back/cancel in severity dialog
   - [✅] Should return to symptom list (back navigation)
   - [✅] Clicking on another symptom opens the severity dialog
   - [✅] Cancel again to exit completely

3. **Cancel Custom Input**:
   - [✅] Click symptom button → select "Other..." → reach custom input
   - [✅] Press back/cancel or enter empty string
   - [✅] Should return to symptom list
   - [✅] Clicking on another symptom opens the custom input dialog
   - [✅] Verify no logging occurred

4. **Cancel Custom Input Severity**:
   - [✅] Click symptom button → select "Other..." → reach custom input
   - [✅] Enter custom symptom: "My Test Symptom" and confirm entry → reach severity dialog
   - [✅] Press cancel
   - [✅] Should return to custom input with no text

### Test 4: Multiple Symptom Logging
1. **Log Same Symptom Multiple Times**:
   - [✅] Log "Brain fog" with severity 3
   - [✅] Log "Brain fog" again with severity 6
   - [✅] Verify both entries logged separately with different severities

2. **Log Different Symptoms**:
   - [✅] Log 3-4 different symptoms with various severities
   - [✅] Verify all logged correctly with severity metadata
   - [✅] Check symptom list shows proper count markers

---

## ✅ Integration Testing (New + Existing Systems)

### Test 5: Mixed Dialog System Behavior
1. **Symptoms (New) + Activities (Legacy)**:
   - [ ] Log a symptom with severity (new system)
   - [ ] Immediately log an activity (legacy system)  
   - [ ] Verify both systems work without interference
   - [ ] Check both items logged correctly

2. **Dialog Routing**:
   - [ ] Click symptom button → verify new dialog flow manager handles it
   - [ ] Click activity button → verify legacy dialog manager handles it
   - [ ] Verify no conflicts or mixed routing

### Test 6: Daily Tracking Integration
1. **Symptom Count Display**:
   - [ ] Log same symptom multiple times with different severities
   - [ ] Reopen symptom dialog
   - [ ] Verify symptom shows with count marker (e.g., "✓ Fatigue (2)")
   - [ ] Verify count reflects all severity entries, not just unique symptoms

2. **Data Persistence**:
   - [ ] Log symptoms with severities
   - [ ] Close widget completely 
   - [ ] Reopen widget
   - [ ] Verify logged symptoms with severities still present in daily logs

---

## ✅ Error Handling & Edge Cases

### Test 7: Edge Case Scenarios
1. **Rapid Dialog Interactions**:
   - [ ] Quickly open/cancel symptom dialogs multiple times
   - [ ] Verify no dialog state corruption or stuck dialogs

2. **Long Custom Symptom Names**:
   - [ ] Enter very long custom symptom name (50+ characters)
   - [ ] Verify it handles gracefully and logs correctly

3. **Special Characters**:
   - [ ] Enter custom symptom with special characters: "Test (parentheses) & symbols"
   - [ ] Verify logs correctly without breaking parsing

### Test 8: System Recovery
1. **Memory/State Management**:
   - [ ] Start symptom flow but don't complete
   - [ ] Navigate away from AIO launcher
   - [ ] Return to launcher - should cleanly handle incomplete flow

---

## ✅ Backwards Compatibility Verification

### Test 9: Legacy Systems Unchanged
1. **Energy Logging** (should work exactly as before):
   - [ ] Click energy button (⚡)
   - [ ] Verify radio dialog with energy levels 1-10
   - [ ] Select level and confirm logging
   - [ ] Verify energy button color changes appropriately

2. **Activity Logging** (should work exactly as before):
   - [ ] Click activity button (🏃)
   - [ ] Verify list dialog with activities + "Other..." option
   - [ ] Select activity → should log immediately (no severity)
   - [ ] Test "Other..." → custom input → immediate logging

3. **Intervention Logging** (should work exactly as before):
   - [ ] Click intervention button (💊)
   - [ ] Verify list dialog with interventions + "Other..." option  
   - [ ] Select intervention → should log immediately (no severity)
   - [ ] Test "Other..." → custom input → immediate logging

---

## ✅ Data Format Verification

### Test 10: Log Format Checking
1. **Check Internal Storage**:
   - [ ] Use AIO launcher settings to view preferences
   - [ ] Look for `daily_logs` data
   - [ ] Verify symptom entries format: `"Symptom Name (severity: N)"`
   - [ ] Verify activity/intervention entries unchanged: `"Activity Name"`

2. **Google Sheets Integration** (if configured):
   - [ ] Log symptoms with severities
   - [ ] Check spreadsheet shows correct format with severity metadata
   - [ ] Verify Tasker integration (if available) handles new format

---

## ✅ Success Criteria

**All tests must pass for dialog stack system to be considered production-ready:**

- [ ] **Functionality**: All new symptom flows work as designed
- [ ] **Integration**: New and legacy systems coexist without conflicts  
- [ ] **Data Integrity**: Severity metadata logged correctly and persistently
- [ ] **User Experience**: Flows feel natural, cancellation works intuitively
- [ ] **Backwards Compatibility**: Existing energy/activity/intervention systems unchanged
- [ ] **Error Handling**: Edge cases handled gracefully without crashes
- [ ] **Performance**: No noticeable slowdown in dialog responsiveness

**Critical Issues That Would Require Fixes:**
- Dialog flows getting stuck or corrupted
- Legacy systems broken by new dialog manager
- Data not persisting correctly
- Cancellation not working properly
- Performance degradation

**If any critical issues found**: Document specific steps to reproduce and report for fixing before production use.