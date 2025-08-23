# DRAFT - Dialog Stack Implementation Decision Log

## Decision Context (2024-12-22)

**Problem**: Current string-based dialog system (`current_dialog_type`) cannot scale to support 3+ level dialog hierarchies needed for:
- Symptoms: List → Selection → Severity (1-10) → Complete
- Activities: List → Selection → Intensity Options → Complete  
- Interventions: List → Selection → Options → Complete

## Key Decisions Made

### Decision 1: Adopt Dialog Stack Architecture ✅

**Alternatives Considered**:
- A) Extend current string-based system with more dialog types
- B) Hybrid approach with simple parent/child tracking
- C) Full dialog stack with flow definitions

**Decision**: Option C - Full dialog stack architecture

**Rationale**:
- String-based system would need exponential combinations: `"symptom_edit_severity"`, `"activity_intensity_edit"`, etc.
- Hybrid approach still requires complex state management for 3+ levels
- Stack approach provides clean, extensible foundation for future dialog complexity
- One-time implementation cost vs. ongoing maintenance burden of string manipulation

### Decision 2: Flow Definition System ✅

**Approach**: Declarative flow definitions separate from dialog stack implementation

**Rationale**:
- Makes dialog flows easy to understand and modify
- Enables conditional branching (physio intensity only for certain activities) 
- Separates flow logic from stack management mechanics
- Facilitates testing of individual flow steps

### Decision 3: Preserve AIO Integration Pattern ✅

**Approach**: Keep global `on_dialog_action(result)` callback, route to active stack

**Rationale**:
- Minimizes changes to AIO integration layer
- Maintains compatibility with existing dialog handling
- Single point of routing prevents callback conflicts

### Decision 4: Gradual Migration Strategy ✅

**Approach**: Implement one category at a time, keep existing system as fallback

**Rationale**:
- Reduces risk of breaking existing functionality
- Allows testing and validation at each step
- Provides rollback option if issues arise
- Enables incremental complexity management

### Decision 5: Context Preservation Approach ✅

**Approach**: Aggregate data from all dialogs in stack for context

**Rationale**:
- Later dialogs need access to earlier selections (severity dialog needs symptom name)
- Stack naturally preserves dialog history
- Simpler than passing context through function parameters
- Enables rich logging with full context

## Technical Decisions

### Stack Management
- **Push/Pop Operations**: Standard stack operations for dialog management
- **Current Dialog Access**: Always work with top of stack
- **Context Aggregation**: Merge data from all stack levels for full context

### Flow Definition Structure
```lua
category = {
    step_name = {
        dialog_type = "list|radio|edit",
        configuration = {...},
        next_step = function(result, context) return "next_step_name" end
    }
}
```

### Edge Case Handling
- **List Dialog Quirk**: Use `ignore_next_cancel` flag per dialog
- **Widget Reload**: Store minimal state in preferences for recovery
- **Error Recovery**: Clear stack and return to widget on errors
- **Back Navigation**: Support via stack pop operations

## Implementation Priorities

### Must Have (Phase 1)
- DialogStack class with core operations
- Dialog flow manager with routing
- AIO integration that doesn't break existing functionality  
- Basic symptoms flow (list → severity)

### Should Have (Phase 2)
- Custom input dialogs ("Other..." flows)
- Activities and interventions flows
- Conditional flow branching
- Comprehensive test coverage

### Could Have (Phase 3)
- Back navigation between dialog levels
- Flow state persistence across widget reloads  
- User experience enhancements (breadcrumbs, progress)
- Performance optimizations

## Risk Mitigation

### High Risk: AIO Integration Complexity
- **Mitigation**: Maintain existing dialog callback patterns, add routing layer
- **Fallback**: Keep current system operational during migration

### Medium Risk: Stack State Management
- **Mitigation**: Comprehensive testing of push/pop operations and context preservation
- **Fallback**: Simple error recovery that clears stack and returns to widget

### Low Risk: Performance Impact
- **Mitigation**: Performance testing during each phase
- **Fallback**: Optimize or simplify stack operations if needed

## Success Validation Criteria

### Code Quality
- [ ] Dialog flows are easier to understand than current string manipulation
- [ ] Adding new dialog steps requires minimal code changes
- [ ] Test coverage for all dialog flows and edge cases

### User Experience  
- [ ] Multi-level flows feel natural and responsive
- [ ] Clear feedback about position in dialog flow
- [ ] Graceful handling of cancellation and errors

### Technical Performance
- [ ] No noticeable slowdown in widget responsiveness
- [ ] Memory usage remains acceptable
- [ ] All existing functionality continues to work

## Future Session Handoff Notes

### Context for Next Implementation Session
1. Read all planning documents in `/planning/` directory
2. Current system analysis is in `long_covid_core.lua:630-771` (dialog_manager functions)
3. Migration should start with symptoms flow as it has most complexity
4. Preserve existing test patterns in `/tests/` directory

### Key Implementation Files
- **Core Logic**: `/my/long_covid_core.lua` - Add dialog stack classes
- **Widget Integration**: `/my/long-covid-pacing.lua` - Replace dialog_manager usage  
- **Testing**: `/tests/test_long_covid_widget.lua` - Add dialog flow tests

### Validation Process  
1. Implement core DialogStack class with tests
2. Create simple symptoms flow (list → severity)  
3. Migrate existing symptoms functionality
4. Verify all existing tests still pass
5. Test new multi-level flow end-to-end

This approach ensures systematic implementation while maintaining system stability.