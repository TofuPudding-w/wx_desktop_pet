# Daily alarm — local development validation

Replaces the countdown feature. Entry: right-click → 工具 → 每日闹钟.
One daily local-time alarm, 24-hour hour/minute input, enable/disable, edit time,
acknowledge reminder, optional short generated chime. Settings are stored in
`user://alarm.cfg`, independently of pet settings; `--no-settings` disables I/O.
No countdown, focus cycles, server dependency or public release is added.

Scheduling follows local calendar dates, rather than UTC plus a fixed 24-hour
interval. A time already passed is scheduled for tomorrow. One reminder per
local date; missed running-session days are coalesced on resume. Desktop exit
stops reminders; relaunch loads the next future occurrence without sending old
missed reminders. Pausing/hiding pets and closing the alarm window leave it active.

Validation:

- 31 alarm checks pass: invalid input, daily rollover, midnight/year boundary,
  backward clock/duplicate suppression, missed-day coalescing, disable, saved
  time/enabled/sound state, restart duplicate prevention, invalid config, menu
  integration, hidden/paused pets, acknowledgement, editing and layout.
- 79 controls, 41 update/menu checks and 39 Python tooling tests pass.
- Native Ubuntu/XWayland reminder popup preserves keyboard focus, verified with
  XGetInputFocus before/after a short clock-driven alarm. Sound was muted for this
  probe. Native window layout inspected; generated chime is 0.9 seconds, -14 dB.
- Existing flash-free menu windows are preserved. No character remapping added.

Actual machine sleep/DST transition and Windows/macOS alarm behavior remain
manual device checks. Linux development package is separate from public v0.3.0.
