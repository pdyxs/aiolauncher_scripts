---
name: push-to-phone
description: |
  Push AIO Launcher script changes to the user's Android phone via ADB over Tailscale.
  TRIGGER when the user says "push to phone", "deploy to device", "push my changes",
  "sync scripts", or similar. Also trigger when a script edit session is wrapping up
  and the user wants to test on-device.
  Do NOT trigger for general script editing, debugging, or testing tasks.
disable-model-invocation: true
allowed-tools: Bash, Read, Glob, Grep
---

## push-to-phone Skill

Push changed AIO Launcher Lua scripts to the Android phone via ADB over Tailscale.

### Step 1: Ensure ADB is connected

Run the `/adb-connect` skill. Proceed to Step 2 only once the device shows `device` status.

### Step 2: Determine which files to push

Use context from the current conversation to identify what was just worked on. If specific files were edited in this session, those are the candidates.

Also check git for changed files in the `my/` and `dev/` folders:

```bash
git -C ~/dev/aiolauncher_scripts diff --name-only HEAD
git -C ~/dev/aiolauncher_scripts diff --name-only --cached
```

**Decision logic:**
- If conversation context clearly identifies 1-3 files just worked on → push those, no confirmation needed
- If git shows a small set of changes consistent with recent work → push those, no confirmation needed
- If changes are ambiguous or numerous → show the list and ask which to push

### Step 3: Push files

Source the env file to get `SCRIPTS_DIR` and `REPOS`:

```bash
source ~/dev/aiolauncher_scripts/env
```

For each file to push:
- Scripts in `my/` or `dev/` root → `adb push <file> $SCRIPTS_DIR`
- Modules in `my/core/` → `adb push <file> ${SCRIPTS_DIR}core/`

### Step 4: Confirm success

Check the ADB push output. If any file failed, report the error. Otherwise, tell the user which files were pushed and that they should be live on the device.
