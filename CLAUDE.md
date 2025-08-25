## Overview

This project is to create scripts for AIO Launcher, an android launcher.

Scripts are in Lua. Documentation for creating a script can be found in `README.md`

My scripts are all in the `my` folder.

### Long Covid widget

The long covid widget can be found under my/long-covid-pacing.lua

The widget design can be found in widget_design.md. **IMPORTANT**: Follow the documentation maintenance guidelines below to keep this accurate.

#### Long Covid data

Long covid planning can be found in the filesystem, under `Long Covid/plans/`. (See CLAUDE.local.md for the full machine-specific path.) 

Please read and follow the instructions in the 'project_instructions.md' file in that folder before making changes to those plans.

The Long Covid planning widget is an AIO script which aims to:
1. Surface data from the plan on an android device (where the equivalent planning folder can be found at "Documents/pdyxs/Long Covid/plans") - allowing me to choose a level of capacity for the day, and displaying the appropriate plan for all 7 days of the week
2. Allow me to make choices in the widget, which are saved to a markdown file to help track my progress

**Plan Structure**: The system uses separate daily plans for all 7 days (monday.md through sunday.md), replacing the previous combined weekend.md file with separate saturday.md and sunday.md files.

**Project Plan**: See `long_covid_widget_plan.md` for the detailed implementation plan, including data restructuring and widget development phases.

## AIO Launcher Development Guidelines

### Rich UI Button Handling

When using AIO's Rich UI API with dynamic button text (e.g., icon-only vs icon+text), **always match buttons by their stable identifiers (like icons) rather than full text content**.

**Problem**: Button text changes based on state:
- Icon-only: `"fa:bed"`
- Icon+text: `"%%fa:bed%% Recovering"`

**Solution**: Use `elem_text:find("icon_name")` in click handlers:
```lua
-- ❌ Don't match on full text (breaks with dynamic content)
if elem_text == "Recovering" then

-- ✅ Do match on stable icon identifier
if elem_text:find("bed") then
```

This ensures click handlers work regardless of whether buttons show icon-only or icon+text format.

### FontAwesome Icon Usage

- Use `%%fa:icon%%` for icons within text
- Use `fa:icon` for icon-only buttons
- Escape special characters in patterns: `rotate%-right` not `rotate-right`

### Radio Dialog Compatibility Issues

**Critical AIO Bug**: Radio dialogs have an underlying platform issue where `on_dialog_action` is not called for OK/selection events, only for cancel events.

**Problem Symptoms**:
- Radio dialog selections don't trigger `on_dialog_action` callback
- Flow gets stuck after radio dialog selection
- List dialogs work correctly, radio dialogs fail silently

**Verified Workaround**: Use radio dialogs for **all** dialog steps in a flow, not mixed list→radio patterns.

**Implementation Strategy**:
```lua
-- ❌ Don't mix dialog types (causes on_dialog_action issues)
symptom_flow = {
    main_list = { dialog_type = "list" },      -- Works
    severity = { dialog_type = "radio" }       -- Breaks - radio after list
}

-- ✅ Use consistent radio dialogs throughout
symptom_flow = {
    main_list = { dialog_type = "radio" },     -- Works
    severity = { dialog_type = "radio" }       -- Works - radio after radio
}
```

**Required Changes for Radio Compatibility**:
1. **Dialog Flow Definition**: Convert `get_items` → `get_options` for radio dialogs
2. **Data Processing**: Update handlers to expect `data.options` instead of `data.items`  
3. **Display Logic**: Use `dialogs:show_radio_dialog()` consistently
4. **Test Updates**: Update test assertions to expect radio dialog structures

This workaround was implemented successfully for the Long Covid widget's symptom flow, converting from list→radio to radio→radio pattern.

## Testing

### Test Suite Location

All tests are located in the `tests/` directory and can be run locally without AIO Launcher dependencies.

### Running Tests

```bash
cd tests
lua test_long_covid_widget.lua
```

### Test-Driven Development Process

**IMPORTANT**: When adding new functionality to any widget, follow this process:

1. **Write tests first** - Create comprehensive tests for the new functionality before implementing it
2. **Update existing tests** - Modify existing tests if your changes affect current behavior
3. **Implement functionality** - Write the actual feature implementation
4. **Verify all tests pass** - Run the full test suite to ensure nothing is broken
5. **Refactor if needed** - Improve code while keeping tests passing

### Debugging On-Device Issues with Test Harnesses

**CRITICAL**: When encountering bugs or unexpected behavior on the AIO device, always create test harnesses to simulate the issue locally before attempting fixes.

**Why this approach is essential:**
- **Faster iteration** - Testing on device requires restarting AIO, navigating to widget, reproducing steps
- **Better debugging** - Local tests allow detailed logging, step-by-step analysis, and controlled conditions
- **Reproducible results** - Ensures the issue is understood and fix is verified before device testing
- **Preserves context** - Debug output is easier to capture and analyze locally

**Process for device-specific issues:**
1. **Analyze the device behavior** - Note exact sequences, timing, and unexpected results
2. **Create a test harness** - Write a test that simulates the device's API calls and behavior patterns
3. **Reproduce the issue locally** - Ensure the test shows the same problem as the device
4. **Debug and fix locally** - Use the test to understand root cause and verify fix
5. **Test final fix on device** - Only after local test confirms the fix works

**Example scenarios requiring test harnesses:**
- Dialog timing issues (selection followed by automatic cancel)
- Module loading and caching problems  
- State management across widget restarts
- Complex user interaction sequences
- AIO-specific API behaviors

**Test harness naming convention:**
```
tests/test_[feature]_simulation.lua    # For simulating device behavior
tests/test_[bug]_reproduction.lua      # For reproducing specific bugs
```

This approach transforms frustrating device debugging sessions into efficient local development cycles.

### Test Coverage Requirements

All widget functionality should have tests covering:
- **Happy path scenarios** - Normal usage and expected inputs
- **Edge cases** - Boundary conditions and unusual but valid inputs
- **Error handling** - Invalid inputs and error conditions
- **State management** - Preference storage and retrieval
- **UI interactions** - Button clicks and user actions
- **Data parsing** - File parsing and data transformation
- **Business logic** - Widget-specific rules and constraints

### Test Structure

Tests use a lightweight framework with:
- Mock AIO Launcher APIs (prefs, ui, files, gui, tasker)
- Assertion helpers (assert_equals, assert_true, assert_contains)
- Setup/teardown for isolated test execution
- Comprehensive error reporting with line numbers

See `tests/README.md` for detailed testing guidelines and examples.

## Documentation Maintenance Guidelines

**CRITICAL**: Keep documentation synchronized with code changes to maintain project clarity and prevent confusion.

### Documentation Update Requirements

When making changes to the Long Covid widget, **ALWAYS** update documentation in this exact order:

1. **Update widget_design.md FIRST** - Before committing any code changes
2. **Run tests** - Ensure all 87 tests pass after implementation changes
3. **Update CLAUDE.md** - If architectural changes affect development process
4. **Update tests/README.md** - If test structure or count changes

### Widget Design Documentation (widget_design.md)

**Update widget_design.md whenever you make changes to:**

#### User Interface Changes
- ✅ **Button layout, icons, or colors** - Update "Widget Layout" and "User Interface Elements" sections
- ✅ **Capacity level names or behavior** - Update capacity level documentation throughout
- ✅ **Dialog functionality** - Update interaction flow and dialog examples
- ✅ **Visual feedback or indicators** - Update button color logic and visual differentiation sections

#### Technical Implementation Changes  
- ✅ **Architecture changes** - Update "Technical Implementation" section with new components/managers
- ✅ **Function signatures** - Update code examples to match current implementation
- ✅ **Data structures** - Update internal storage and file format sections
- ✅ **Testing changes** - Update "Testing Coverage" section with new test counts/suites

#### Feature Changes
- ✅ **New logging types** - Update logging sections and examples
- ✅ **New data sources** - Update "File Structure Integration" section
- ✅ **Requirement tracking** - Update required items specification and examples
- ✅ **Energy tracking** - Update energy level sections if scale or behavior changes

### Documentation Quality Standards

#### What to INCLUDE in documentation:
- ✅ **Current functionality only** - Document what exists now
- ✅ **Accurate visual layouts** - Match exact icons and button text  
- ✅ **Working code examples** - Test all code snippets for accuracy
- ✅ **Complete interaction flows** - Document all user paths through the interface
- ✅ **Current test coverage** - Keep test numbers and suite descriptions up to date

#### What to EXCLUDE from documentation:
- ❌ **Future plans or enhancements** - Remove all "Phase 2", "Future Features", etc.
- ❌ **Outdated function signatures** - Remove old implementation details
- ❌ **Deprecated features** - Remove documentation for removed functionality
- ❌ **Speculative content** - Only document implemented and tested features

### Documentation Review Process

**Before marking any task complete:**

1. **Accuracy Check** - Does the documentation match the current code?
2. **Completeness Check** - Are all user-visible features documented?
3. **Clarity Check** - Can someone new understand the widget from the documentation?
4. **Organization Check** - Is information easy to find and logically structured?

### Common Documentation Maintenance Tasks

#### When Adding New Features
```
1. Write/update tests for the new feature
2. Implement the feature
3. Update widget_design.md with:
   - New UI elements or interactions
   - Updated user flows
   - Technical implementation changes
   - Updated test coverage numbers
4. Verify all documentation sections are still accurate
```

#### When Refactoring Code
```
1. Update widget_design.md "Technical Implementation" section
2. Update any affected code examples
3. Update architecture diagrams or descriptions
4. Verify UI documentation still matches behavior
```

#### When Fixing Bugs
```
1. If the bug affects user behavior, update interaction flows
2. If the bug affects visual appearance, update UI documentation
3. If tests were added/changed, update test coverage numbers
```

### Documentation Anti-Patterns to Avoid

- ❌ **"Will implement later"** - Only document current functionality
- ❌ **Copy-paste from old versions** - Always verify against current code
- ❌ **Generic descriptions** - Use specific examples and current data
- ❌ **Inconsistent terminology** - Use same names as in the actual code
- ❌ **Outdated screenshots/layouts** - Update visual examples to match current state

### Validation Commands

**Before committing documentation changes, run:**

```bash
# Verify tests still pass with current documentation claims
cd tests && lua run_all_tests.lua

# Check for outdated references in documentation
grep -n "Phase\|TODO\|FIXME\|deprecated" widget_design.md

# Verify file references are accurate
grep -n "\.lua\|\.md" widget_design.md | head -10
```

This ensures documentation stays **current, accurate, and useful** as the project evolves.

## Feature Lifecycle Documentation Framework

**CRITICAL PRINCIPLE**: Keep planning, development, and final documentation completely separate to prevent documentation debt and confusion.

### 🎯 Phase 1: Planning (Keep SEPARATE from main docs)

**Objective**: Explore and define requirements without polluting current state documentation.

#### What to DO during planning:
- ✅ **Create temporary planning documents** in a `planning/` folder or dev notes
- ✅ **Use clear "DRAFT" or "PLANNING" markers** on all exploratory content
- ✅ **Focus on requirements and user goals**, not implementation details
- ✅ **Document decision criteria** for choosing between approaches
- ✅ **Keep planning documents outside main documentation files**

#### What NOT to do during planning:
- ❌ **Add future features to widget_design.md** - This creates confusion about current state
- ❌ **Mix speculative content with current documentation** - Readers can't tell what exists now
- ❌ **Commit "will implement" language** to main docs - Only document what exists
- ❌ **Update main documentation** until feature is implemented and tested

#### Planning Document Structure:
```
planning/                           # Temporary folder (gitignore if desired)
├── feature-name-requirements.md    # User needs, success criteria
├── feature-name-ui-exploration.md  # UI/UX design options  
├── feature-name-technical-plan.md  # Implementation approaches
└── feature-name-decision-log.md    # Decisions made and rationale
```

**Example Planning Content:**
```markdown
# DRAFT - Sleep Quality Tracking Feature Planning

## User Requirements
- [ ] Users want to log sleep quality on 1-10 scale
- [ ] Sleep data should correlate with energy levels
- [ ] Sleep tracking should be optional, not required

## UI Design Options
Option A: Add sleep button to health tracking row
Option B: Include in energy dialog as compound input
Option C: Separate sleep-focused dialog

## Decision: Choosing Option A because...
```

### 🔨 Phase 2: Development (Test-Driven Documentation)

**Objective**: Implement features with tests as executable specification, keeping main docs unchanged.

#### Development Documentation Strategy:
- ✅ **Write tests FIRST** - Tests serve as living specification of intended behavior
- ✅ **Update tests incrementally** as you implement each piece
- ✅ **Use detailed code comments** for complex implementation decisions
- ✅ **Create draft documentation** in development folders if needed for large features

#### Development Documentation Structure:
```
tests/
├── test_sleep_tracking.lua         # Executable specification
├── test_sleep_energy_correlation.lua  # Integration testing
└── test_ui_sleep_integration.lua   # UI behavior specification

dev_notes/                          # Temporary implementation notes
└── sleep-feature-implementation.md # Development progress, blockers, decisions
```

**Key Development Principles:**
1. **Tests define the feature** - If it's not tested, it's not done
2. **Code comments explain WHY** - Use comments for implementation decisions
3. **Main docs stay current** - Don't update widget_design.md until feature is complete
4. **Development notes are temporary** - Clean up dev notes when feature is done

### ✅ Phase 3: Completion (Documentation as Definition of Done)

**Objective**: Feature is NOT complete until all documentation is updated to reflect new current state.

#### Documentation Completion Checklist:

**1. Verify Implementation Completeness**
```bash
cd tests && lua run_all_tests.lua  # All tests must pass
```

**2. Update Main Documentation (in order)**
- ✅ **Update widget_design.md** - Add complete feature documentation
  - Update UI layouts with new elements
  - Update interaction flows with new behaviors  
  - Update technical implementation with new components
  - Update test coverage numbers
- ✅ **Update CLAUDE.md** - If development process or guidelines changed
- ✅ **Update tests/README.md** - If test structure or organization changed

**3. Clean Up Temporary Documentation**
- ✅ **Remove or archive planning documents** - Move to `archive/` or delete
- ✅ **Remove development notes** - Implementation details are now in code/tests
- ✅ **Remove "DRAFT" or "TODO" markers** from any remaining docs

**4. Verify Documentation Quality**
- ✅ **Accuracy**: Does documentation match actual implementation?
- ✅ **Completeness**: Are all user-visible features documented?
- ✅ **Clarity**: Can someone new understand the feature from docs?
- ✅ **Integration**: Does new content fit well with existing documentation?

#### Example Completion Process:

```markdown
# Before marking feature complete:

## 1. Implementation Verification
- [x] All new tests pass (15 new tests added)
- [x] All existing tests still pass (87 total tests)
- [x] Feature works in actual AIO launcher environment

## 2. Documentation Updates
- [x] widget_design.md: Added "Sleep Quality Tracking" section
- [x] widget_design.md: Updated "Health & Activity Logging" with sleep button
- [x] widget_design.md: Updated "Testing Coverage" (87 → 102 tests)
- [x] tests/README.md: Updated test count and added sleep tracking suite

## 3. Cleanup
- [x] Deleted planning/sleep-quality-tracking-*.md files
- [x] Removed dev_notes/sleep-implementation.md
- [x] Verified no "TODO" or "DRAFT" content in main docs

## 4. Quality Check
- [x] New user can understand sleep tracking from widget_design.md
- [x] Documentation matches actual UI behavior
- [x] All file references are accurate
```

### 🚫 Common Anti-Patterns to Avoid

#### Planning Phase Mistakes:
- ❌ Adding "Coming Soon: Sleep Tracking" to widget_design.md
- ❌ Documenting UI that doesn't exist yet
- ❌ Mixing planning content with current state docs

#### Development Phase Mistakes:
- ❌ Updating main docs before feature is complete
- ❌ Leaving TODO comments in widget_design.md
- ❌ Committing half-implemented documentation

#### Completion Phase Mistakes:
- ❌ Marking feature "done" without updating docs
- ❌ Leaving planning documents in the repo
- ❌ Forgetting to update test coverage numbers

### 📋 Quick Reference Workflow

```
Planning:     Create planning/feature-name-*.md files
              DO NOT touch main documentation

Development:  Write tests first
              Keep main docs unchanged
              Use dev_notes/ for temporary content

Completion:   Update widget_design.md with complete feature
              Update other docs if needed
              Clean up planning/ and dev_notes/
              Verify all tests pass
```

This approach ensures that main documentation always reflects current reality while providing space for planning and development work.
- can you always use debug toasts for debugging instead of ui toasts?