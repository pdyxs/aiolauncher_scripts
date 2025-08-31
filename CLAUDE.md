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

**IMPORTANT**: When adding new functionality to any widget, follow this TDD process:

1. **Write failing tests first** - Create comprehensive tests for the new functionality (RED phase)
2. **Implement minimum code** to make tests pass (GREEN phase)  
3. **Refactor and improve** code while keeping tests passing (REFACTOR phase)
4. **Update existing tests** if your changes affect current behavior
5. **Verify all tests pass** - Run the full test suite to ensure nothing is broken

This RED-GREEN-REFACTOR cycle ensures reliable, well-tested implementations.

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

**CRITICAL: Test Cleanup Process**
When creating temporary test harnesses or simulation files:
1. **Temporary tests** (simulation, reproduction, debugging) must be REMOVED after use
2. **Permanent tests** (actual feature/bug tests) must be ADDED to `run_all_tests.lua`
3. **Always run `lua run_all_tests.lua`** to verify integration before marking complete

**Test File Categories:**
- ✅ **Keep & Add to run_all_tests.lua**: `test_[feature_name].lua`, `test_[component].lua`
- ❌ **Remove after debugging**: `test_[bug]_reproduction.lua`, `test_[feature]_simulation.lua`

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
2. **Run tests** - Ensure all tests pass after implementation changes
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


## Bug/Feature Development Workflow

### Requirements Structure

**Project Requirements Location**: See CLAUDE.local.md for machine-specific path to `Long Covid/project/`

**Directory Structure**:
```
Long Covid/project/
├── ideas/                   # Half-formed concepts for exploration
│   ├── idea-001-sleep-correlation.md
│   ├── idea-002-energy-predictions.md
├── features/               # Refined, ready-to-implement features  
│   ├── feature-001-sleep-tracking.md
│   └── feature-002-export-data.md
└── bugs/                   # Bug reports
    ├── bug-001-login-failure.md
    └── bug-002-widget-crash.md
```

**Templates**: Use Obsidian templates from Templates path (see CLAUDE.local.md):
- `Bug.md` - For bug reports with properties (name, status, severity, etc.)
- `Feature.md` - For implementation-ready features with acceptance criteria
- `Idea.md` - For half-formed concepts requiring exploration

### Development Pathways

#### **Pathway A: Idea Exploration**
For half-formed concepts requiring conversation and refinement:

1. **Create Idea file** using Idea.md template
2. **Conversational exploration** with `idea-explorer` sub-agent
3. **Update exploration notes** in the idea file during discussion
4. **Graduate to Feature** when concept is refined and ready

#### **Pathway B: Direct Implementation**
For well-defined bugs/features using standard templates:

1. **Requirements validation** with `requirements-analyst` sub-agent
2. **Architecture discovery** with `architecture-mapper` sub-agent (for complex features)
3. **Optional refactoring** with `refactoring-specialist` sub-agent (if technical debt identified)
4. **Technical planning** with `technical-planner` sub-agent  
5. **Integration testing** with `integration-tester` sub-agent
6. **Test-first development** following TDD process (see Testing section above)
7. **Documentation updates** with `documentation-maintainer` sub-agent

### Sub-Agent Architecture

#### Core Development Sub-Agents

1. **`idea-explorer`** - Conversational idea refinement
   - Tools: Read, Edit, WebFetch (for research)
   - Purpose: Ask probing questions, help clarify concepts, research feasibility
   - Behavior: Focus on understanding, NOT implementation
   - **Question Pacing**: Ask ONE question at a time, wait for complete response, then ask follow-ups

2. **`requirements-analyst`** - Validates requirements completeness  
   - Tools: Read, Grep
   - Capabilities: Parse YAML frontmatter properties, validate against templates
   - Purpose: Check completeness, ask clarifying questions about missing details
   - **Question Pacing**: Ask ONE clarifying question at a time, get complete answer before proceeding

3. **`architecture-mapper`** - Maps existing code architecture for complex features
   - Tools: Read, Grep, Glob
   - Purpose: Trace actual code paths, identify integration points, document parsing systems
   - Capabilities: Map legacy vs new systems, flag compatibility issues, create integration guides
   - **When to Use**: Complex features that modify existing UI flows or core logic

4. **`technical-planner`** - Creates implementation plans
   - Tools: Read, Write, Edit
   - Capabilities: Update status properties during planning process, must map actual widget integration points
   - Purpose: Design technical architecture, create test strategies, update status

5. **`integration-tester`** - Creates end-to-end integration tests
   - Tools: Read, Write, Edit, Bash
   - Purpose: Test actual widget flows, verify production parsing systems, simulate device behavior
   - **Critical**: Must test with same code paths the widget uses, not isolated unit tests

6. **`test-developer`** - Writes comprehensive tests
   - Tools: Read, Write, Edit, Bash
   - Capabilities: Update progress properties when writing tests
   - Purpose: Create test suites, mock frameworks, ensure coverage

7. **`implementation-developer`** - Builds features following TDD
   - Tools: Read, Write, Edit, MultiEdit, Bash  
   - Capabilities: Update completion status properties
   - Purpose: Implement code to pass tests, refactor, optimize

8. **`documentation-maintainer`** - Updates project documentation
   - Tools: Read, Edit, MultiEdit
   - Purpose: Keep widget_design.md, CLAUDE.md, and technical docs current

9. **`refactoring-specialist`** - Identifies and executes code simplification opportunities
   - Tools: Read, Write, Edit, MultiEdit, Bash
   - Purpose: Analyze technical debt, propose consolidation of duplicate code paths, execute refactoring
   - **When to Use**: When architecture-mapper or technical-planner identifies complex/duplicate code related to new feature

10. **`process-improver`** - Analyzes and improves the development workflow
   - Tools: Read, Edit, MultiEdit
   - Purpose: Fix systemic issues, enhance sub-agent capabilities, update process documentation

### Obsidian Integration

**Property-Based Status Tracking**:
- **Ideas**: `Exploring → Refined → Abandoned`
- **Features**: `Requested → Planning → In Progress → Completed`  
- **Bugs**: `Open → Investigating → Fixed`

**Priority/Severity Levels**: `Critical/High/Medium/Low`

**Obsidian Benefits**:
- Property-based filtering and queries
- Template consistency via Obsidian template system
- Visual progress tracking in properties view
- Search and organization using Obsidian's tools

### Implementation Process

**Standard Workflow Example**:

1. **You**: "I've created feature-002-weekly-requirements.md using the Feature template"
2. **`requirements-analyst`**: Reads file, parses YAML properties, validates completeness
3. **Ask clarifying questions** about any missing details or unclear requirements (ONE at a time)
4. **`architecture-mapper`** (for complex features): Maps existing code paths, identifies integration points
5. **OPTIONAL REFACTORING DECISION**: If architecture-mapper identifies duplicate/complex code paths:
   - **`refactoring-specialist`**: Proposes code simplification options
   - **User approval required** for refactoring before feature implementation
   - **If approved**: Separate refactoring implementation with full testing
6. **`technical-planner`**: Updates `status: Requested → Planning`, creates detailed technical plan with specific integration points
7. **Present plan for approval**, get your feedback and approval
8. **`integration-tester`**: Creates end-to-end tests using actual widget flow, updates `status: Planning → In Progress`
9. **`test-developer`**: Writes comprehensive unit tests following TDD process
10. **`implementation-developer`**: Implements solution to pass all tests (using simplified code paths if refactoring occurred)
11. **CRITICAL: Device verification** - User must update widget on device and verify no immediate issues
12. **`documentation-maintainer`**: Updates widget_design.md, asks about process improvements, updates `status: In Progress → Completed`
13. **`process-improver`** (if needed): Analyzes issues, improves workflow, updates process docs

**Idea Exploration Example**:

1. **You**: "I have this half-formed idea about predicting energy crashes..."
2. **`idea-explorer`**: Engages in conversational exploration, asks probing questions (ONE at a time)
3. **Update idea file** with exploration notes throughout discussion
4. **Graduation decision**: When ready, create formal Feature.md from refined concept
5. **Switch to standard workflow** using requirements-analyst → technical-planner → etc.

### Key Principles

- **Requirements completeness** - Always validate before implementation
- **Code path simplification** - Prefer editing existing pathways over creating new ones
- **Proactive refactoring** - Address technical debt BEFORE implementing new features
- **Technical planning approval** - Get user sign-off on approach before coding
- **Test-first development** - Write tests before implementation code
- **Test cleanup and integration** - Remove temporary tests, add permanent tests to run_all_tests.lua
- **Full test suite validation** - Run `lua run_all_tests.lua` before marking anything complete
- **Device verification** - MANDATORY device testing after implementation to verify functionality
- **Sequential questioning** - Ask ONE question at a time during exploration/validation phases
- **Property-based tracking** - Use Obsidian properties for status management  
- **Documentation maintenance** - Keep all docs current with implementation changes
- **Flexible idea exploration** - Low-barrier entry for half-formed concepts
- **Continuous process improvement** - Built-in feedback loop after each implementation

### Sub-Agent Task Examples

**Using the Task tool with general-purpose agent for each sub-agent role:**

#### 1. Idea-Explorer Sub-Agent
```
Task: Act as an idea-explorer sub-agent for the Long Covid widget project. I have a half-formed idea about [concept].

Your role is to:
1. Read the existing idea file at [path]
2. Ask probing questions to help clarify the concept and understand user needs
3. Research feasibility using existing widget capabilities and AIO Launcher constraints
4. Update the idea file with exploration notes during our discussion
5. Help determine when the idea is refined enough to graduate to a formal Feature.md

IMPORTANT QUESTIONING APPROACH:
- Ask ONE probing question at a time
- Wait for the user's complete response before asking follow-ups
- Build on previous answers to deepen understanding
- Focus on understanding the concept deeply, NOT on implementation details
```

#### 2. Requirements-Analyst Sub-Agent
```
Task: Act as a requirements-analyst sub-agent for the Long Covid widget project. Validate [bug/feature file].

Your role is to:
1. Read the [bug/feature] file at [path]
2. Parse the YAML frontmatter properties and validate against template
3. Check for completeness of all required sections
4. Identify any missing details or unclear requirements
5. Ask specific clarifying questions about gaps or ambiguities
6. Ensure the [bug/feature] is ready for technical planning

IMPORTANT QUESTIONING APPROACH:
- Ask ONE clarifying question at a time about missing or unclear details
- Wait for the user's complete answer before asking the next question
- Address all gaps systematically, but sequentially rather than in batch
```

#### 3. Architecture-Mapper Sub-Agent
```
Task: Act as an architecture-mapper sub-agent for the Long Covid widget project. Map existing code architecture for [complex feature].

Your role is to:
1. Read the validated [feature/bug] file at [path] to understand requirements
2. Trace the actual widget code flow that will be affected by this feature
3. Identify ALL integration points - every function that needs modification
4. Document existing parsing systems and which ones are used in production
5. Map legacy vs new code patterns and flag potential compatibility issues
6. Create detailed integration guide showing exact code paths
7. Provide findings to technical-planner for implementation planning

CRITICAL FOCUS AREAS:
- Follow button color logic from UI to core functions
- Identify which parsing functions the widget actually uses (not just tests)
- Document function signatures and parameter requirements
- Flag technical debt or dual systems that could cause integration issues

REFACTORING ASSESSMENT:
- Identify duplicate code pathways that could be consolidated
- Flag overly complex functions that could be simplified
- Assess if existing code paths can be extended vs creating new ones
- If significant technical debt is found, recommend refactoring-specialist consultation

IMPORTANT: If you find duplicate/complex code paths related to the new feature, explicitly recommend refactoring as a separate step before implementation.

Only use for complex features that modify existing UI flows or core logic.
```

#### 4. Technical-Planner Sub-Agent
```
Task: Act as a technical-planner sub-agent for the Long Covid widget project. Create implementation plan for [feature/bug].

Your role is to:
1. Read the validated [feature/bug] file at [path]
2. Read architecture-mapper findings (if available) to understand integration points
3. Update the status property to "Planning"
4. Create DETAILED implementation plan specifying exactly which functions to modify
5. Map out all call sites that need updates (include function signatures)
6. Create test strategy following TDD process (see Testing section above)
7. Present implementation plan with specific integration details for user approval

CRITICAL REQUIREMENTS:
- Plan must be specific enough that implementation becomes mechanical, not exploratory
- PREFER extending existing code paths over creating entirely new ones
- Include exact function names, parameter changes, and call site updates
- Address any legacy vs new system compatibility issues identified by architecture-mapper
- If refactoring occurred, plan implementation using the simplified code structure
- If no architecture-mapper was used, perform basic integration point discovery yourself

CODE PATH PREFERENCE:
- Always assess if existing functions can be extended rather than creating new ones
- Consolidate similar logic rather than duplicating patterns
- Use the simplest approach that maintains code clarity and testability
```

#### 5. Integration-Tester Sub-Agent
```
Task: Act as an integration-tester sub-agent for the Long Covid widget project. Create end-to-end integration tests for [feature/bug].

Your role is to:
1. Read the technical plan and architecture findings for [feature/bug]
2. Create tests that simulate the EXACT widget flow that users experience
3. Test with the SAME parsing systems the widget uses in production (not just test parsing)
4. Simulate device behavior as closely as possible with proper date mocking
5. Verify all integration points work correctly BEFORE unit test development
6. Update status to "In Progress" when integration tests are complete

CRITICAL TESTING APPROACH:
- Use same code paths as the actual widget (trace from UI buttons to core functions)
- Test with production parsing functions (e.g., parse_required_interventions, not just parse_interventions)
- Create device simulation tests that catch integration bugs early
- Focus on end-to-end flows, not isolated unit logic
- Tests should FAIL initially, proving they catch real integration issues
```

#### 6. Test-Developer Sub-Agent
```
Task: Act as a test-developer sub-agent for the Long Covid widget project. Write comprehensive tests for [feature/bug].

Your role is to:
1. Read the technical plan for [feature/bug]
2. Update status to "In Progress"
3. Write comprehensive tests covering all scenarios (see Test Coverage Requirements above)
4. Follow existing test framework patterns and TDD process
5. Tests should FAIL initially (RED phase of TDD cycle)
6. CRITICAL: Update run_all_tests.lua to include new permanent tests
7. CRITICAL: Remove any temporary/simulation test files that were created for debugging
8. Run updated test suite to verify framework integration
```

#### 7. Implementation-Developer Sub-Agent
```
Task: Act as an implementation-developer sub-agent for the Long Covid widget project. Implement [feature/bug] to make all tests pass.

Your role is to:
1. Read the failing test suite for [feature/bug]
2. Implement minimum code needed to make tests pass (GREEN phase of TDD cycle)  
3. Follow existing code patterns and AIO Launcher guidelines (see Development Guidelines above)
4. Run tests continuously during development
5. CRITICAL: Run the full test suite (lua run_all_tests.lua) to ensure no regressions
6. Fix any issues found by the comprehensive test suite
7. Update status to "Completed/Fixed" ONLY when ALL tests pass including run_all_tests.lua
8. MANDATORY: Prompt user to update widget on device and verify no immediate issues before marking complete
```

#### 8. Documentation-Maintainer Sub-Agent
```
Task: Act as a documentation-maintainer sub-agent for the Long Covid widget project. Update documentation for completed [feature/bug].

Your role is to:
1. Read the completed implementation and test suite
2. Update widget_design.md following Documentation Maintenance Guidelines
3. Update test coverage numbers (count actual tests)
4. Verify all documentation is accurate and current
5. Run validation commands to check for outdated references
6. IMPORTANT: Confirm device testing was completed successfully
7. Ask the user if they encountered any process issues or have improvement ideas
8. If improvements are identified, recommend using the process-improver sub-agent
```

#### 9. Process-Improver Sub-Agent
```
Task: Act as a process-improver sub-agent for the Long Covid widget project. Analyze and improve the development workflow.

Your role is to:
1. Read PROCESS_CONTEXT.md and current workflow documentation in CLAUDE.md
2. Analyze the specific implementation issue or improvement idea provided
3. Identify if this is a systemic problem or one-off issue
4. Research similar issues in the workflow documentation
5. Propose specific workflow improvements and documentation updates
6. Update CLAUDE.md with improved sub-agent instructions if needed
7. Update PROCESS_CONTEXT.md with new fixes and process status
8. Provide updated Task tool examples for any changed sub-agents
```

#### 10. Refactoring-Specialist Sub-Agent
```
Task: Act as a refactoring-specialist sub-agent for the Long Covid widget project. Analyze and simplify complex/duplicate code paths before implementing [feature/bug].

Your role is to:
1. Read the architecture-mapper findings that identified technical debt
2. Analyze the specific duplicate/complex code paths flagged
3. Propose consolidation options that would simplify the codebase
4. Create refactoring plan that maintains existing functionality
5. Present refactoring options with pros/cons to user for approval
6. If approved: Execute refactoring as separate implementation cycle
7. Write tests to verify refactored code maintains existing behavior
8. Run full test suite to ensure no regressions before feature implementation

REFACTORING PRINCIPLES:
- Prefer extending existing code paths over creating new ones
- Consolidate duplicate logic into shared functions
- Simplify complex functions while maintaining behavior
- Remove dead code and unused pathways
- Update all call sites consistently

CRITICAL REQUIREMENTS:
- Refactoring must be completed and fully tested BEFORE feature implementation
- All existing functionality must be preserved exactly
- Must provide clear migration path from old to new code structure
- Changes must be reviewable and understandable

This is a SEPARATE implementation cycle with its own testing and device verification.
```

### Process Improvement Quick Start

**For new conversations focused on process improvement:**

1. **Quick Context Setup**: "Please read `PROCESS_CONTEXT.md` and the workflow section in `CLAUDE.md` (lines 280-520) to understand the current system."

2. **Issue Description Template**:
   ```
   **Specific Issue**: [what went wrong during implementation]
   **Implementation Context**: [which bug/feature you were working on]  
   **Proposed Improvement**: [your idea for fixing it]
   ```

3. **Launch Process Improver**: Use the process-improver sub-agent Task example above

**The documentation-maintainer will automatically prompt for this feedback after each implementation.**