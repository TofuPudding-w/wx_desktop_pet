# Stage 1 desktop foundation checklist

This is a local test build, not a release. Record each item as PASS / FAIL / NOT TESTED.
Windows and macOS exports are not evidence of native desktop compatibility.

## Record your environment

- Build ID (BUILD_INFO.json):
- OS and version:
- CPU architecture (x64 / Apple Silicon):
- Graphics adapter:
- Screen resolution and scaling (100% / 125% / 150% / Retina):
- Number of monitors and primary monitor:
- For Linux: desktop environment and X11 / Wayland + XWayland:

## Launch and transparency

1. Close any older copy first. Extract the entire ZIP to a normal writable folder.
2. Launch without Godot or the project source. Both characters appear; no solid rectangular background.
3. Click empty space around/between characters: the application behind receives clicks.
4. Type in an editor while the pets walk and interact: no input focus is stolen.
5. Confirm all artwork is sharp enough and not clipped; Chinese menu text renders.

## Movement and input

6. Drag each character left/right/up, release, and confirm they land at the usable screen bottom.
7. Repeat near all screen edges. Check the taskbar/Dock/panel does not hide the feet.
8. Right-click either character: pause/resume, reset positions, exit. Paused pets still allow dragging.
9. Confirm exit closes both character windows and any combined hug window, leaving no pet process.

## Eye contact and hug

10. Test each interaction separately. Windows: test-eye-contact.cmd and test-hug.cmd.
    Linux: ./run.sh -- --eye-demo or ./run.sh -- --hug-demo.
    macOS: in Terminal, run the executable under the .app's Contents/MacOS with -- --eye-demo or -- --hug-demo.
11. WWX must be left of LWJ; reset to center is easiest. Both must land, be unpaused, and have menus closed.
    Completed/cancelled interactions have a shared 30-second cooldown; resetting positions preserves it.
12. Eye contact uses 4 FPS and authored return frames; walk stops 40px before the final 160px position, then snaps into place without idle sliding.
13. Hug uses 1 -> 2 -> (3 -> 4) x3 -> idle. First two frames: 6 FPS; held frames: 2 FPS.
    Final hug spacing is about 147.57px. Confirm no duplicated sprites, clipping or opaque rectangle while the combined window appears/disappears.
14. Drag either side during approach, eye contact and hug. The interaction cancels; partner returns to normal, and the dragged character remains draggable.
15. Open the menu during interaction. Confirm both recover and no invisible window blocks clicks afterwards.

## Desktop changes

16. Try another display scaling setting, restart the pet, repeat dragging/hug and inspect alignment.
17. Sleep/wake, change resolution and (if available) disconnect a secondary display. Confirm recovery within the primary usable area.
18. macOS volunteers: test Retina, Spaces/virtual desktops, full-screen app switching, Dock behavior and quitting.
19. Run for at least 15 minutes for initial feedback. Report stalls, unexpected CPU/memory use and repeated focus changes.
    This does not certify a two-hour stability test.

## If something fails

- Describe the exact action and whether it happens in eye-only, hug-only or normal mode.
- Windows: close the pet and launch diagnose.cmd. Reproduce, exit, attach pet.log and telemetry.json from %LOCALAPPDATA%\WangXianPet\Stage1\.
- Linux: ./run.sh --log-file /tmp/wx-stage1.log -- --telemetry=/tmp/wx-stage1.json
- Include this filled checklist and optionally a short recording. Do not mark untested items passed.
- No need to install development tools on Windows. Do not disable system-wide security to run experimental builds.
