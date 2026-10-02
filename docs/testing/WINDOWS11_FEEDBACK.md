# Windows 11 test feedback

Build ID: 20261002T052143Z-27932d36
System: Windows 11 / Intel x64 / 100% scaling (user confirmed)
Windows build number:
GPU:
Resolution:

Fill in PASS / FAIL / NOT TESTED:

- Extracted full ZIP and launched CPPet.exe without Godot: PASS
- Two transparent characters, no rectangular background: PASS
- Click-through around/between characters: PASS
- Typing focus stays with editor/browser during movement: PASS
- Drag both characters, release, land and remain in bounds: PASS
- Eye contact including return/cancellation: PASS
- Hug including combined-window transparency and cancellation: PASS
- Pause/resume and reset: PASS
- Exit closes all pet windows and process: PASS
- No invisible blocking area after hug/cancellation: PASS
- 15-minute initial run: PASS
- Optional follow-up: another scaling setting / sleep-wake: NOT TESTED

If a failure occurs, describe the action, expected/actual behavior, whether it happens repeatedly, and which launcher you used.
Use diagnose.cmd to capture pet.log and telemetry.json under %LOCALAPPDATA%\WangXianPet\Stage1\.

## Follow-up build: 20261002T091131Z-13c5fb54

2026-10-02: User reports all Windows tests completed and everything works correctly. This includes the requested size/settings and screen-boundary follow-up. Exact additional display-scale values were not supplied, so no values are inferred. Original build feedback above is retained as historical evidence.
