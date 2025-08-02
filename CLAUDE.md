## Overview

This project is to create scripts for AIO Launcher, an android launcher.

Scripts are in Lua. Documentation for creating a script can be found in `README.md`

My scripts are all in the `my` folder.

### Long Covid widget

The long covid widget can be found under my/long-covid-pacing.lua

The widget design can be found in widget_design.md. Update this whenever the design changes.

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