## Overview

My scripts are all in the `my` folder. Modules (which can be shared by multiple scripts) are all in my/core

My preferred approach for developing UI is Rich UI (see `README_RICH_UI.md`).

## AIO Launcher Development Guidelines

### FontAwesome Icon Usage

- Use `%%fa:icon%%` for icons within text
- Use `fa:icon` for icon-only buttons
- Escape special characters in patterns: `rotate%-right` not `rotate-right`

## Testing

### Test Suite Location

All tests are located in the `tests/` directory and can be run locally without AIO Launcher dependencies.

### Debugging On-Device Issues with Test Harnesses

**CRITICAL**: When encountering bugs or unexpected behavior on the AIO device, always create test harnesses to simulate the issue locally before attempting fixes.

**Process for device-specific issues:**
1. **Analyze the device behavior** - Note exact sequences, timing, and unexpected results
2. **Create a test harness** - Write a test that simulates the device's API calls and behavior patterns
3. **Reproduce the issue locally** - Ensure the test shows the same problem as the device
4. **Debug and fix locally** - Use the test to understand root cause and verify fix
5. **Test final fix on device** - Only after local test confirms the fix works

**Test harness naming convention:**
```
tests/test_[feature]_simulation.lua    # For simulating device behavior
tests/test_[bug]_reproduction.lua      # For reproducing specific bugs
```

**CRITICAL: Test Cleanup Process**
When creating temporary test harnesses or simulation files:
1. **Temporary tests** (simulation, reproduction, debugging) must be REMOVED after use

This approach transforms frustrating device debugging sessions into efficient local development cycles.
