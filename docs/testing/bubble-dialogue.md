# Offline bubble dialogue — 2026-10-20

Local development feature; no release/tag published.

Entry: right-click either pet → 工具 → 气泡对白.

Implemented: named scripts, add/remove/reorder lines, speaker and duration selection,
copy/delete scripts, automatic local save, previous-save backup recovery, play/pause/
resume/stop. Playback uses a snapshot of the script, holds both pets idle, and restores
previous pause flags on completion or cancellation. Dragging, hiding, resetting,
resizing or changing global pause stops playback. Native bubbles pass mouse input
through and cannot take keyboard focus. User text is plain text, never executable.

Storage: Godot user data `stories/library.json`, schema version 1; `.bak` contains the
previous save. 100 scripts, 200 lines/script, 160 characters and four newline characters
per line, 1–60 seconds/line; total serialized library limited to 2 MB. Invalid drafts do
not overwrite saved data. If primary and backup are invalid, preserve both and disable
saving until repaired. This is one backup, not a full revision-history system.

Validation:
- Dialogue suite: 34 headless checks; 35 native X11 checks, all passed.
- Existing app (849), controls (79), appearance (29), simulation (29) checks passed.
- Existing daily-alarm suite passed; offline guide rendering: 2 checks passed.
- Native Godot viewport captures inspected: editor, duration field, wrapped bubble.
- Tests cover Chinese text, bubble growth/shrinkage, backup recovery, invalid input,
  copying/reordering/deleting, snapshot isolation, pause, completion, dragging and hiding.

Still requires user validation on Windows/macOS. No cloud sync, AI generation,
custom speaker avatars, import/export UI or social-media image export in this feature.
