class_name DesktopPlatform
extends RefCounted

# Collect backend facts, not claims of platform certification.
static func snapshot() -> Dictionary:
	var headless := DisplayServer.get_name() == "headless"
	var result := {
		"os": OS.get_name(), "os_version": OS.get_version(),
		"engine": Engine.get_version_info().string,
		"project_version": ProjectSettings.get_setting("application/config/version", ""),
		"backend": DisplayServer.get_name(),
		"renderer": RenderingServer.get_current_rendering_method(),
		"screen_count": 0 if headless else DisplayServer.get_screen_count(),
		"transparent_windows": DisplayServer.has_feature(DisplayServer.FEATURE_WINDOW_TRANSPARENCY)
	}
	if not headless:
		var screen := DisplayServer.get_primary_screen()
		result["primary_screen"] = screen
		result["screen_scale"] = DisplayServer.screen_get_scale(screen)
		result["screen_dpi"] = DisplayServer.screen_get_dpi(screen)
		result["work_area"] = str(DisplayServer.screen_get_usable_rect(screen))
		result["gpu"] = RenderingServer.get_video_adapter_name()
	return result
