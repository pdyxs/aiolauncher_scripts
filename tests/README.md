# Tests

This directory contains test suites for AIO Launcher scripts in this project.

## Running Tests

Tests are written in Lua and can be run locally without AIO Launcher dependencies.

### Long Covid Widget Tests

#### Comprehensive Test Suite (Recommended)
Run all focused test suites covering the simplified widget architecture:

```bash
cd tests
lua run_all_tests.lua
```

#### Individual Test Suites
Run specific test suites for targeted testing:

```bash
cd tests
lua test_core_logic.lua          # Core business logic (17 tests)
lua test_logging_functions.lua   # Tasker integration (12 tests)
lua test_dialog_manager.lua      # Dialog state management (11 tests)
lua test_cache_manager.lua       # File caching (10 tests)
lua test_button_mapper.lua       # Button action mapping (12 tests)
lua test_ui_generator.lua        # UI element generation (10 tests)
```

#### Legacy Test (Original)
Run the original comprehensive test for comparison:

```bash
cd tests
lua test_long_covid_widget.lua
```

**Comprehensive Coverage (72 tests total):**
- **Core Business Logic** - File parsing, data management, daily reset, calculations
- **Logging Functions** - Tasker integration, error handling, callback mechanisms
- **Dialog Manager** - State management, data loading, result processing for all dialog types
- **Cache Manager** - File caching, invalidation, multi-day plan management
- **Button Mapper** - Action identification, level validation, special character handling
- **UI Generator** - Element creation, state-based rendering, error content generation

## Test Structure

The test suite is organized into focused, modular files:

### Core Framework Files
- **`test_framework.lua`** - Shared testing utilities and assertion functions
- **`test_data.lua`** - Common test data and mock functions  
- **`run_all_tests.lua`** - Main test runner that executes all test suites

### Framework Features
- Mock AIO Launcher APIs (prefs, ui, files, gui, tasker, dialogs)
- Comprehensive assertions (assert_equals, assert_true, assert_contains, assert_type, etc.)
- Mock data factory for consistent test data across suites
- Callback tracking for testing Tasker integration
- Individual and collective test execution
- Detailed error reporting with performance metrics

### Benefits of Modular Structure
- **Maintainability** - Easy to add tests for new features or edge cases  
- **Isolation** - Individual suites can be run independently for debugging
- **Focus** - Each test suite covers specific functionality area
- **Reusability** - Shared framework reduces code duplication
- **Comprehensive** - 72 tests covering all manager functions in the core module

## Adding New Tests

When adding new functionality to widgets:

1. **Write tests first** - Create tests for the new functionality before implementing
2. **Update existing tests** - Modify tests if changes affect existing behavior
3. **Ensure coverage** - Test both happy path and error cases
4. **Run tests** - Verify all tests pass before committing changes

Example test structure:
```lua
add_test("Test description", function()
    setup_widget_env()
    
    -- Setup test data
    test_files["example.md"] = "test content"
    
    -- Execute functionality
    local result = test_function()
    
    -- Verify results
    assert_equals(expected, result, "Should return expected value")
    assert_true(condition, "Should meet condition")
    assert_contains(result_array, "expected_item", "Should contain expected item")
end)
```

## Test Best Practices

- **Isolated tests** - Each test should be independent
- **Clear descriptions** - Test names should describe what is being tested
- **Comprehensive assertions** - Verify all important aspects of functionality
- **Mock external dependencies** - Don't rely on real file system or network
- **Error testing** - Test error conditions and edge cases