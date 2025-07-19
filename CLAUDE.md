## Overview

This project is to create scripts for AIO Launcher, an android launcher.

Scripts are in Lua. Documentation for creating a script can be found in `README.md`

My scripts are all in the `my` folder.

### Long Covid data

Long covid planning can be found in the filesystem, under 'Long Covid/plans'. 

Please read and follow the instructions in the 'project_instructions.md' file in that folder before making changes to those plans.

The Long Covid planning widget is an AIO script which aims to:
1. Surface data from the plan on an android device (where the equivalent planning folder can be found at "Documents/pdyxs/Long Covid/plans") - allowing me to choose a level of capacity for the day, and displaying the appropriate plan
2. Allow me to make choices in the widget, which are saved to a markdown file to help track my progress

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