# Menu appearance validation

- Background/text are saved in the existing settings file; defaults preserve the original palette.
- Main menus and the rabbit menu share the palette. Circular HSV picker, hex input, preview, cancel and restore-default draft supported.
- Editor surface, labels, buttons and hex input use the palette saved when opened. Draft colors affect only the bordered preview until applied.
- Menus sit 120 logical pixels higher than their old position, scaled with pet size and clamped to the main display work area.
- With the menu in its own window, exposed character artwork remains draggable; pet input regions no longer expand to the old menu rectangle.

Validation on Ubuntu/XWayland: 29 appearance/settings/position checks, 79 controls checks, 849 app checks pass. Editor inspected in a native screenshot with default light palette; saved custom editor palette verified in tests. Earlier update/menu suite: 41 checks passed. Linux development package rebuilt; Windows/macOS visual checks pending. Public release assets unchanged.
