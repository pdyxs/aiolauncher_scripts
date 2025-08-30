# Bug/Feature Development Process - Quick Context

## What This Is
A systematic workflow for implementing bugs/features in the Long Covid AIO widget using sub-agents and TDD.

## Key Files to Read First
- `CLAUDE.md` - Complete workflow documentation (lines 280-500+)  
- `tests/run_all_tests.lua` - Test suite structure that must be maintained
- `widget_design.md` - Current implementation state
- Template files: `Bug.md`, `Feature.md`, `Idea.md` (paths in CLAUDE.local.md)

## Current Process Status
- ✅ **Implemented**: Full workflow with 6 sub-agents + process-improver
- ✅ **Working**: Idea exploration → requirements → technical planning → tests → implementation → docs
- ✅ **Recently Fixed**: Test cleanup issues (agents now update run_all_tests.lua properly)
- ✅ **Recently Added**: Process improvement feedback loop after each implementation

## Quick Process Summary
1. **Requirements**: Create bug/feature/idea file using Obsidian templates with YAML properties
2. **Sub-Agent Chain**: Use Task tool sub-agents in sequence:
   - `requirements-analyst` → validates completeness, asks clarifying questions
   - `technical-planner` → creates implementation plan, updates status to "Planning"  
   - `test-developer` → writes failing tests, updates run_all_tests.lua, removes temp tests
   - `implementation-developer` → implements to pass tests, runs full test suite
   - `documentation-maintainer` → updates widget_design.md, prompts for process improvements
   - `process-improver` → analyzes issues, improves workflow (when needed)
3. **Tracking**: All progress tracked via Obsidian properties (status, priority, etc.)

## Sub-Agent Architecture
- **Pathway A**: Idea exploration for half-formed concepts
- **Pathway B**: Direct implementation for well-defined requirements
- **Process improvement**: Built-in feedback loop after each implementation

## Critical Success Factors
- ✅ **Test Integration**: New tests must be added to `run_all_tests.lua`
- ✅ **Test Cleanup**: Remove temporary/simulation tests after debugging
- ✅ **Full Validation**: Run `lua run_all_tests.lua` before marking complete
- ✅ **Documentation Sync**: Keep widget_design.md current with implementation
- ✅ **Process Evolution**: Capture improvements after each implementation

## Common Issues & Recent Fixes
- **Test integration**: Fixed agents to properly update run_all_tests.lua (Dec 2024)
- **Documentation drift**: Consolidated duplicate workflow docs in CLAUDE.md (Dec 2024)
- **Process improvement gap**: Added systematic feedback loop and process-improver sub-agent

## File Structure Integration
```
Long Covid/project/
├── ideas/          # Half-formed concepts (Idea.md template)
├── features/       # Ready features (Feature.md template)  
└── bugs/          # Bug reports (Bug.md template)

aiolauncher_scripts/
├── PROCESS_CONTEXT.md    # This file - quick context for process improvements
├── CLAUDE.md            # Complete workflow documentation
├── tests/
│   ├── run_all_tests.lua    # CRITICAL: Must be updated with new tests
│   └── test_*.lua           # Individual test suites
└── my/long-covid-pacing.lua # Main widget implementation
```

## When to Update This File
- After significant process improvements
- When workflow steps change  
- After fixing systemic issues
- When sub-agent capabilities are enhanced
- After adding new tools or validation steps

## Quick Troubleshooting
- **Tests not running**: Check if new tests added to run_all_tests.lua
- **Implementation errors not caught**: Ensure full test suite ran before completion
- **Documentation drift**: Run documentation-maintainer sub-agent
- **Process issues**: Use process-improver sub-agent with specific examples