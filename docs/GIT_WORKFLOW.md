# Git Workflow

- Inspect `git status` before staging.
- Keep each user-requested edit turn to one coherent commit when the active
  integration requires automatic commits; do not include unrelated work.
- A commit must restore a complete playable project. Never commit a parse-broken
  or dependency-incomplete state.
- Stage intended source, scene, data, configuration, and required assets. Exclude
  caches, secrets, scratch files, and generated reports unless explicitly needed.
- Report the full commit hash after committing.
- Push according to the active integration's remote-sync rule; report failures.
- Before reset/revert, warn that uncommitted work will be lost.
