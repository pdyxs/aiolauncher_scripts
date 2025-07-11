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