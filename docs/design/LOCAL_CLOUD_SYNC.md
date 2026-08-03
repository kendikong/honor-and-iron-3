# Local ↔ Cloud sync (Honor & Iron)

**Purpose:** Keep **local Agent** and **Cloud Agent** on the same git commit so both see the same game.

**Authority:** Cloud Agents clone GitHub — they never see uncommitted or unpushed local files.

---

## One rule

| Before… | You / agent must… |
|---------|-------------------|
| Starting **Cloud** | Local clean + **pushed** to `origin/<branch>` |
| Resuming **local** after Cloud | **Pull** (or merge Cloud PR) so local matches remote |

---

## Agent automation (already required)

| Hook | Behavior |
|------|----------|
| Every edit turn | Full-backup `git commit` (`.cursor/rules/auto-commit-absolute.mdc`) |
| Every **3** local commits **or** session end / Cloud handoff | `git push origin <branch>` (`.agents/AGENTS.md`) |
| Before Cloud handoff | Run `.\scripts\sync_local_remote.ps1 -Mode Push` — fail loud if dirty or push fails |
| After Cloud merge | Run `.\scripts\sync_local_remote.ps1 -Mode Pull` before next local edit |

---

## Owner checklist (manual — cannot be done by the agent alone)

1. **Connect GitHub** in [Cursor Integrations](https://cursor.com/dashboard/integrations) (once).
2. **Cloud environment** at [Cloud Agents → Environments](https://cursor.com/dashboard/cloud-agents#environments): create snapshot for this repo; install **Godot 4.7** on the VM if Cloud must run `run_bruiser_qa_gate.ps1`.
3. **Approve push** when the agent asks / when auth prompts (first time or expired token).
4. **Start Cloud Agent** (Agents Window → Cloud) or **Automation** at [cursor.com/automations](https://cursor.com/automations) — paste prompt from `docs/design/prompts/B6-REOPEN-CLOUD.md`.
5. **Merge Cloud PR** (or merge its branch) when the run finishes.
6. **Pull locally** (or tell local agent: `sync pull`).

---

## Commands

```powershell
# Status: ahead/behind/dirty
.\scripts\sync_local_remote.ps1 -Mode Status

# Pull latest from origin (after Cloud merge)
.\scripts\sync_local_remote.ps1 -Mode Pull

# Push local commits (before Cloud) — refuses if dirty tree has game-needed files uncommitted
.\scripts\sync_local_remote.ps1 -Mode Push
```

---

## B6-REOPEN handoff (current)

- Matrix: **31/31** PASS · full-matrix critic **96** · template **LOCKED**
- Prompt: [`docs/design/prompts/B6-REOPEN-CLOUD.md`](prompts/B6-REOPEN-CLOUD.md)
- Run card: [`docs/design/runs/B6-REOPEN.md`](runs/B6-REOPEN.md)
