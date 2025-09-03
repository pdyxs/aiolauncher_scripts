# Module Split and Test Reorganization Plan

**Status**: Planning  
**Priority**: Medium  
**Complexity**: High  
**Estimated Duration**: 4-6 sessions  
**Created**: 2024-09-03  

## Overview

This plan outlines the complete restructuring of the Long Covid Widget codebase from a monolithic `long_covid_core.lua` (1832 lines) into focused modules with corresponding test reorganization. The goal is to improve maintainability, testability, and code organization.

## Current State Analysis

### Code Structure
- **`long-covid-pacing.lua`**: 442-line widget file (UI layer)
- **`long_covid_core.lua`**: 1832-line monolithic business logic module
- **19+ test files**: Mixed unit/integration tests with unclear boundaries

### Test Issues
- No clear distinction between unit vs integration tests
- Test files don't map to code structure
- Potential duplication between test types
- Difficult to identify test scope and purpose

## Target Architecture

### New Module Structure
```
my/
├── long-covid-pacing.lua              # Widget (unchanged)
├── long_covid_date.lua                # 66 lines - Date/time utilities
├── long_covid_state.lua               # 370 lines - Daily state + logging + completion  
├── long_covid_parsing.lua             # 258 lines - File parsing infrastructure
├── long_covid_ui.lua                  # 400+ lines - UI generation + dialog flows
└── long_covid_weekly.lua              # 200 lines - Weekly requirements system
```

### New Test Structure
```
tests/
├── unit/                              # Pure logic tests (no AIO APIs)
│   ├── test_date_utils.lua           # Tests long_covid_date
│   ├── test_state_management.lua     # Tests long_covid_state
│   ├── test_parsing.lua              # Tests long_covid_parsing
│   ├── test_ui_generation.lua        # Tests long_covid_ui
│   └── test_weekly_requirements.lua  # Tests long_covid_weekly
├── integration/                       # Component integration tests
│   ├── test_dialog_flows.lua         # Cross-module dialog interactions
│   ├── test_manager_integration.lua  # Manager coordination
│   └── test_logging_pipeline.lua     # End-to-end logging flows
├── widget/                           # Widget-level tests (AIO APIs)
│   ├── test_widget_lifecycle.lua     # on_resume, prefs, reset
│   ├── test_widget_interactions.lua  # on_click, button routing
│   └── test_widget_rendering.lua     # render_widget, UI generation
├── framework/
│   ├── test_framework.lua
│   └── test_data.lua
└── run_all_tests.lua
```

## Implementation Phases

### Phase 1: Foundation and Safe Modules (Session 1-2)

#### 1.1: Extract Date Utilities Module
**Risk Level**: Low (no dependencies on other modules)

**Tasks**:
- Create `long_covid_date.lua` with functions:
  - `get_current_day()`, `get_current_day_abbrev()`, `get_today_date()`
  - `get_date_days_ago()`, `get_last_n_dates()`
- Create `tests/unit/test_date_utils.lua`
- Update `long_covid_core.lua` to require and use new module
- Verify existing tests still pass

**Success Criteria**:
- All date-related functions moved to separate module
- No regression in existing functionality
- New unit test provides focused coverage

#### 1.2: Extract Parsing Module
**Risk Level**: Low (clear input/output, minimal coupling)

**Tasks**:
- Create `long_covid_parsing.lua` with functions:
  - `parse_decision_criteria()`, `parse_day_file()`, `parse_symptoms_file()`
  - `parse_items_with_metadata()`, `parse_item_options()`
  - Supporting utilities: `split_lines()`, `escape_pattern()`, etc.
- Create `tests/unit/test_parsing.lua`
- Update dependencies in remaining core module
- Consolidate existing parsing tests

**Success Criteria**:
- All file parsing logic moved to separate module
- Clear API boundaries established
- Consolidated test coverage for all parsing functions

### Phase 2: Core Business Logic (Session 2-3)

#### 2.1: Extract State Management Module
**Risk Level**: Medium (coupled with completion logic)

**Tasks**:
- Create `long_covid_state.lua` with functions:
  - Daily state: `check_daily_reset()`, `get_daily_logs()`, `save_daily_choice()`
  - Logging: `log_item()`, `log_energy()`, Tasker integration
  - Basic completion: `are_all_required_items_completed()`
- Create `tests/unit/test_state_management.lua`
- Carefully manage interfaces with other modules

**Success Criteria**:
- State management isolated from UI concerns  
- Clear API for state persistence and retrieval
- All logging functionality properly encapsulated

#### 2.2: Extract Weekly Requirements Module
**Risk Level**: Low (mostly self-contained)

**Tasks**:
- Create `long_covid_weekly.lua` with functions:
  - Weekly parsing and completion logic
  - Weekly-specific business rules
- Create `tests/unit/test_weekly_requirements.lua`
- Update imports in remaining modules

**Success Criteria**:
- Weekly functionality completely separated
- No impact on daily workflow logic
- Focused test coverage for weekly features

### Phase 3: UI and Complex Systems (Session 3-4)

#### 3.1: Extract UI Module
**Risk Level**: High (complex dependencies on multiple modules)

**Tasks**:
- Create `long_covid_ui.lua` with:
  - UI generation functions
  - Dialog flow system
  - Manager classes (dialog, cache, button mapping)
- Create `tests/unit/test_ui_generation.lua`
- Carefully manage dependencies on state and parsing modules

**Success Criteria**:
- All UI logic separated from business logic
- Dialog system maintains full functionality
- Manager classes properly encapsulated

#### 3.2: Update Widget Integration
**Risk Level**: Medium (update all imports)

**Tasks**:
- Update `long-covid-pacing.lua` to import all new modules
- Ensure all widget functions continue to work
- Update any direct function calls to use new module interfaces

**Success Criteria**:
- Widget functionality unchanged from user perspective
- All module imports working correctly
- No performance degradation

### Phase 4: Test Reorganization (Session 4-5)

#### 4.1: Reorganize Existing Tests
**Tasks**:
- Create `tests/unit/`, `tests/integration/`, `tests/widget/` directories
- Move and consolidate existing tests:
  
  **Move to unit/**:
  - `test_core_logic.lua` → `unit/test_state_management.lua` (merge)
  - `test_options_completion.lua` → `unit/test_completion_logic.lua` 
  - `test_consolidated_*` → merge into relevant unit tests
  - `test_weekly_required_items.lua` → `unit/test_weekly_requirements.lua` (merge)

  **Move to integration/**:
  - `test_dialog_manager.lua` + `test_cache_manager.lua` → `integration/test_manager_integration.lua`
  - `test_*_integration.lua` → `integration/test_dialog_flows.lua`
  - `test_logging_functions.lua` + `test_activity_logging_persistence.lua` → `integration/test_logging_pipeline.lua`

  **Keep as framework:**:
  - `test_framework.lua`, `test_data.lua` → `framework/`

- Update `run_all_tests.lua` to use new directory structure

**Success Criteria**:
- Clear separation between test types
- No test functionality lost in reorganization
- Consolidated tests eliminate duplication

#### 4.2: Add Widget-Level Integration Tests
**Tasks**:
- Create `widget/test_widget_lifecycle.lua`:
  - `on_resume()` error handling and initialization
  - Daily reset logic with real preference data
  - State persistence across widget restarts

- Create `widget/test_widget_interactions.lua`:
  - `on_click()` for all button types
  - `on_long_click()` functionality
  - Button action routing and validation

- Create `widget/test_widget_rendering.lua`:
  - `render_widget()` with different states
  - UI generation pipeline
  - Error handling in rendering

**Success Criteria**:
- True widget-level integration testing
- Coverage of widget-specific functionality not covered by unit tests
- Full AIO Launcher API integration verification

### Phase 5: Validation and Optimization (Session 5-6)

#### 5.1: Comprehensive Testing
**Tasks**:
- Run complete test suite and verify all tests pass
- Test widget functionality on device to ensure no regressions
- Performance testing to ensure no significant slowdown
- Memory usage validation with new module structure

#### 5.2: Documentation Updates
**Tasks**:
- Update `tests/README.md` with new structure
- Update `CLAUDE.md` with new testing guidelines
- Add module documentation to each new file
- Update development workflow documentation

#### 5.3: Cleanup and Optimization
**Tasks**:
- Remove old test files after verifying migration
- Optimize module interfaces based on actual usage
- Remove any dead code discovered during split
- Consolidate any remaining duplicate functionality

## Risk Mitigation

### High-Risk Areas
1. **Dialog Flow System**: Very complex state management across modules
   - **Mitigation**: Extract this last, extensive testing
2. **Circular Dependencies**: Some functions are tightly coupled
   - **Mitigation**: Careful interface design, temporary wrapper functions if needed
3. **Widget Integration**: Many imports to update
   - **Mitigation**: Update incrementally, test after each module

### Testing Strategy
- Run full test suite after each module extraction
- Test widget on device after major changes
- Keep backup of working version before each phase
- Incremental approach - one module at a time

### Rollback Plan
- Each phase is designed to be independently rollback-able
- Keep original `long_covid_core.lua` until all phases complete
- Git branching strategy for easy reversion

## Success Metrics

### Code Quality
- [ ] Total lines of code per file < 500 (except UI module)
- [ ] Clear module boundaries with minimal coupling
- [ ] All tests pass with new structure

### Test Quality  
- [ ] 1:1 mapping between code modules and unit test files
- [ ] Clear distinction between unit/integration/widget tests
- [ ] No duplicated test functionality
- [ ] Test execution time not significantly increased

### Maintainability
- [ ] Easy to locate tests for specific functionality
- [ ] Easy to add new features to appropriate modules
- [ ] Clear interfaces between modules
- [ ] Documentation reflects new structure

## Dependencies and Prerequisites

- All current tests must be passing before starting
- Understanding of current module coupling (analysis complete)
- Standard test framework must be fully implemented (✅ complete)
- Clear development workflow established

## Follow-up Considerations

### Future Enhancements Enabled
- Easier to add new file parsing formats
- Clearer extension points for new UI elements
- Better separation for adding new external integrations
- Modular testing allows focused development

### Potential Further Splits
- If UI module becomes too large, could split into:
  - `long_covid_dialog_flows.lua`
  - `long_covid_managers.lua`  
  - `long_covid_ui_generation.lua`

## Implementation Notes

### Module Import Pattern
Each module should follow this pattern:
```lua
-- module_name.lua
local M = {}

-- Dependencies
local date_utils = require("long_covid_date")
local parsing = require("long_covid_parsing")

-- Functions
function M.function_name()
    -- implementation
end

return M
```

### Test File Pattern  
Each test file should follow the standardized pattern:
```lua
-- tests/unit/test_module_name.lua
local test = require "test_framework"
local module = require "long_covid_module"

test.add_test("test description", function()
    -- test implementation
end)

if ... == nil then
    test.run_tests("Module Name Tests")
    local success = test.print_final_results()
    os.exit(success and 0 or 1)
end
```

This plan provides a systematic approach to transforming the codebase while minimizing risk and maintaining functionality throughout the process.