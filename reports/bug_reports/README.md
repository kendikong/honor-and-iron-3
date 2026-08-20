# Bug Reports Directory

> [!IMPORTANT]
> **MANDATORY FOR ALL AGENTS AND MODELS FIXING BUG REPORTS:**
> You are strictly forbidden from writing or proposing heuristic / band-aid fixes.
> Before attempting any fix, you **MUST** read and obey the core rules:
> - `.cursor/rules/global-systems-first.mdc`
> - `.cursor/rules/no-bandaid-fixes.mdc`
> - `.cursor/rules/move-preview-intent-truth.mdc`
> - `.cursor/rules/action-range-latest-stand.mdc`
> - `.cursor/rules/qa-after-gameplay-changes.mdc`
>
> ### Major Architectural Sources of Truth:
> 1. **Simulation Truth:** `Simulator.simulate_player_turn(state, timeline, events)` is pure RefCounted deterministic resolution.
> 2. **Commit Authority Truth:** `CombatDirector.validate_commit_slots(unit_id, slots)` is the single authority on action legality and commit success.
> 3. **Move Preview & Intent Truth:** `CombatPlanningPreview` & `TacticalPlanningOverlay` — what is previewed on hover is what gets committed.
> 4. **Action Range & Stand Origin Truth:** Range tiles paint from the committed stand position on active timeline, never turn-start `base_board`.
> 5. **Ability Data Truth:** `AbilitySystem` & `AbilityData` Resources — abilities are data, not hardcoded engine branches.
> 6. **Input Buffers vs. Render Truth:** Input buffers (`_drag_route`, waypoint caches) are transient input staging. They must never directly dictate screen rendering or bypass simulation validation.
