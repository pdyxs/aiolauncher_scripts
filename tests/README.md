# Tests

This directory contains test suites for AIO Launcher scripts in this project.

## Running Tests

Tests are written in Lua and can be run locally without AIO Launcher dependencies.

### Long Covid Widget Tests

```bash
cd tests
lua test_long_covid_widget.lua
```

**Coverage:**
- Initial preferences state and defaults
- Daily reset functionality
- Current day calculation
- Decision criteria parsing from markdown
- Day file parsing with sections and categories
- Daily choice saving and tracking
- Widget rendering and UI state
- Click handling for capacity selection
- Reset button functionality
- Level upgrade prevention business logic

## Test Structure

Tests use a simple framework with:
- Mock AIO Launcher APIs (prefs, ui, files, gui)
- Assertion helpers (assert_equals, assert_true, assert_contains)
- Setup/teardown for each test
- Comprehensive error reporting

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