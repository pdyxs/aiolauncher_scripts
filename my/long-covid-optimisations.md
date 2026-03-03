# Long Covid Widget — Pending Optimisations

Options A and D have been implemented. The following are deferred for later.

---

## Option B — Cache `os.time()` / `os.date()` per render (High Impact)

Every call to `is_item_required()`, `is_item_ignored()`, `get_current_capacity()`,
`is_symptom_tracking()` etc. calls `os.time()` and `os.date("*t", ...)` — sometimes
2–3 times per call. A single `render_widget()` runs dozens of these.

**Approach**: Compute `now = os.time()` and `now_date = os.date("*t", now)` once
at the top of `render_widget()` and thread them through the helpers, or store them
in module-level locals that get reset at the start of each render.

**Affected functions**: `is_item_required`, `is_item_ignored`, `get_current_capacity`,
`is_symptom_tracking`, `is_symptom_unresolved`, `get_energy_button_color`,
and anything in `time-utils.lua` that calls `os.date`.

---

## Option C — Single-pass item iteration per render (Medium Impact)

In `render_capacity_selected()`, for both interventions and activities the item list
is iterated up to 3 times:
1. `get_*_button_color()` → `are_any_required()` — full pass
2. `get_latest_required()` — full pass
3. `get_best_ignored_required()` — full pass (only if #2 is nil)

Each pass calls `is_item_required()` (and optionally `is_item_ignored()`) per item.

**Approach**: Combine into a single pass that simultaneously determines:
- whether any item is required (for button colour)
- the best non-ignored required item
- the best ignored required item

This halves (or thirds) the work and also removes the separate `are_any_required`
call.

---

## Option E — Cache tracking symptom flag at setup time (Low Impact)

`get_symptoms_color()` calls `get_tracking_symptoms()` on every render, which
iterates all symptom log values checking `is_symptom_unresolved` and `is_today`.

**Approach**: In `setup_symptoms()`, after computing `prefs.symptom_items`,
also store `prefs.has_tracking_symptoms = #get_tracking_symptoms() > 0`.
Then `get_symptoms_color()` just checks that flag.

Note: this flag will be stale between `setup_symptoms()` calls, but since
`setup_symptoms()` is called after every symptom log, it stays correct.
