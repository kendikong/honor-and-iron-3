# Development Environment

- Project engine: Godot 4.7-stable.
- Windows scripts under `scripts/` use the local Godot executable.
- On the Linux Cloud VM, invoke `godot` directly and use the Compatibility
  renderer with software GL for GUI runs.
- The entry scene is `res://scenes/MainMenu.tscn`; the fastest combat route is
  Skill Test Arena → `TestBattle.tscn`.
- Software rendering may emit benign shader and dummy-audio warnings. These do
  not invalidate headless simulation tests.
- Temporary environment caveats and known failures belong here, not in the
  always-loaded agent rules.
