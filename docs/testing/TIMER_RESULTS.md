> Historical timer development notes. The countdown has been replaced by the daily alarm; see ALARM_RESULTS.md.

# Simple countdown timer — development validation

Entry: right-click either character → 工具 / Tools → 倒计时 / Countdown.
One shared, session-only timer; 1 second to 24 hours. Start, pause, resume,
cancel and reset after completion. Closing the window does not cancel.
Pausing or hiding pets does not pause the timer. Exiting the app cancels it.

The timer uses a system-time deadline: time spent asleep counts, with overdue
completion delivered on resume. Changing the system clock affects remaining
time. There is no background service, alarm schedule, focus cycle, sound,
network request or restart persistence.

Verified locally on Ubuntu / XWayland:

- 26 countdown checks pass in headless and native X11 runs: invalid durations,
  active-timer replacement rejection, fractional-second rounding, pause/resume,
  one-shot completion, cancellation, overdue pause, hidden/pet-paused completion,
  singleton menu entry and native window layout.
- Existing app checks: 849 pass; controls: 76 pass; Python tooling: 39 pass.
- Real four-second completion after hiding the timer window preserves X11
  keyboard focus (XGetInputFocus unchanged). This is separate from simulated
  deadline tests; actual machine suspend/resume has not been exercised.
- Inspected native timer layout. Completion appears without requiring the pets
  to become visible. Opening the input window explicitly permits keyboard input.

Windows/macOS timer-window behavior still needs device testing. No public
version/tag or existing release asset is changed by this development work.

## Menu click regression correction

The earlier native test checked stacking but missed clicking after opening a
menu over the same point as the initiating right press. Reproduced with native
XTest input at character-local (160, 240): Settings stayed at the seven-row main
menu before the fix. The opening right press is now consumed before creating
controls; native remapping waits until all mouse buttons are released. The same
native sequence now opens the five-row Settings menu on the first left click.
The overlap probe still passes A → B → A stacking and unchanged keyboard focus.
Controls (76) and countdown (26) regressions pass. Synthetic headless GUI clicks
do not substitute for this native input check.

## Flash-free menu surface

The remapping workaround above is superseded: menus now use a separate small,
transparent, unfocusable Window. Opening a menu or submenu never hides/remaps
either character. Native X11 stacking checks passed for A → B → A with both
character native IDs and positions unchanged, the menu above both, and keyboard
focus unchanged. Three controls regressions assert separate window ownership
and zero character visibility changes on opening/switching menus. Controls now
have 79 passing checks; the update suite's expected root count includes Tools.
