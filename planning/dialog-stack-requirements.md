# DRAFT - Dialog Stack System Requirements

## User Requirements Analysis (2024-12-22)

### Current System Limitations
- Single `current_dialog_type` string system breaks down with 3+ level dialog hierarchies
- String manipulation approach (`"symptom"` → `"symptom_edit"` → `"symptom_severity"`) becomes exponentially complex
- No clean way to handle conditional dialog flows or preserve context across dialog levels
- Edge cases (like list dialogs not auto-closing) require hard-coded workarounds

### New Dialog Flow Requirements

#### Symptoms Flow (3 levels)
1. **Main List** → Select symptom from predefined list or "Other..."
2. **Custom Input** → (If "Other..." selected) Enter custom symptom name
3. **Severity Selection** → Choose severity level 1-10 for any symptom
4. **Complete** → Log symptom with severity

#### Activities Flow (2-3 levels)  
1. **Main List** → Select activity from predefined list or "Other..."
2. **Custom Input** → (If "Other..." selected) Enter custom activity name
3. **Intensity Options** → (If activity supports it) Choose intensity level (e.g., "Low intensity physio", "High intensity physio")
4. **Complete** → Log activity with optional intensity metadata

#### Interventions Flow (2-3 levels)
1. **Main List** → Select intervention from predefined list or "Other..."
2. **Custom Input** → (If "Other..." selected) Enter custom intervention name  
3. **Options Selection** → (If intervention supports it) Choose specific options
4. **Complete** → Log intervention with optional metadata

### User Experience Requirements
- **Back Navigation**: Users should be able to go back to previous dialog in the flow
- **Context Preservation**: Each dialog should know what was selected in previous steps
- **Clear Flow State**: Users should understand where they are in multi-step process
- **Graceful Cancellation**: Cancel at any level should return cleanly to widget
- **Error Recovery**: System should handle edge cases and AIO quirks gracefully

### Success Criteria
- ✅ Adding new dialog levels requires minimal code changes
- ✅ Complex flows handle edge cases gracefully without hard-coded workarounds
- ✅ Multi-level flows feel natural and responsive to users
- ✅ System is more maintainable than current string-based approach
- ✅ Performance remains acceptable (no noticeable slowdown)
- ✅ All existing functionality continues to work during migration

### Technical Constraints
- **AIO Launcher**: Only supports one dialog at a time, global `on_dialog_action(result)` callback
- **Widget Environment**: State must survive widget reloads/recreation
- **Memory Usage**: Should not significantly increase memory footprint
- **Backwards Compatibility**: Must not break existing logged data or user preferences

## Decision: Proceed with Dialog Stack Architecture

Based on analysis, the benefits clearly outweigh costs for 3+ level dialog hierarchies. Current string-based system would become unmaintainable technical debt.