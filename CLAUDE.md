## Overview

This project is to create scripts for AIO Launcher, an android launcher.

Scripts are in Lua. Documentation for creating a script can be found in `README.md`

My scripts are all in the `my` folder.

### Long Covid widget

The long covid widget can be found under my/long-covid-pacing.lua

The widget design can be found in widget_design.md. **IMPORTANT**: Follow the documentation maintenance guidelines below to keep this accurate.

#### Long Covid data

Long covid planning can be found in the filesystem, under 'Long Covid/plans'. 

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