extends SceneTree
class FallbackChecker extends UpdateChecker:
	var requests: Array = []
	func send_request() -> void:
		requests.append(endpoints[endpoint_index])
		if endpoint_index == 0:
			receive(HTTPRequest.RESULT_TIMEOUT, 0, [], PackedByteArray())
		else:
			receive(HTTPRequest.RESULT_SUCCESS, 200, [], '{"version":"0.3.0"}'.to_utf8_buffer())
var checks := 0
var failures := 0
func check(value: bool, description: String) -> void:
	checks += 1
	if not value:
		failures += 1
		push_error(description)
func _initialize() -> void:
	run.call_deferred()
func run() -> void:
	check(UpdateChecker.evaluate({"tag_name":"v0.10.0"}, "0.9.9").comparison == 1, "numeric version ordering")
	check(UpdateChecker.evaluate({"version":"0.2.2"}, "0.2.2").comparison == 0, "mirror manifest equality")
	check(UpdateChecker.evaluate({"tag_name":"v0.2.1"}, "0.2.2").comparison == -1, "newer local version never downgraded")
	for invalid in [null, [], "text", {}, {"version":2}, {"version":"0.3.0-rc1"}, {"version":"1.0.0", "draft":true}, {"version":"1.0.0", "prerelease":true}, {"version":"01.2.3"}]:
		check(UpdateChecker.evaluate(invalid, "0.2.2").is_empty(), "reject invalid or non-stable release")
	for invalid in ["http://example.com", "file:///tmp/a", "javascript:alert(1)", "https://example.com/a b", null, "https://user@example.com"]:
		check(not UpdateChecker.https_url(invalid), "reject unsafe URL")
	check(UpdateChecker.https_url("https://example.com/update.json"), "HTTPS manifest accepted")
	var checker := UpdateChecker.new()
	root.add_child(checker)
	check(not checker.busy and checker.request_node.get_http_client_status() == HTTPClient.STATUS_DISCONNECTED, "startup does not make network request")
	checker.start([], "0.2.2")
	check(not checker.busy and "未配置" in checker.message, "missing configuration is explicit")
	checker.current_version = "0.2.2"
	for response in [[HTTPRequest.RESULT_TIMEOUT, 0, ""], [HTTPRequest.RESULT_CANT_RESOLVE, 0, ""], [HTTPRequest.RESULT_SUCCESS, 403, "{}"], [HTTPRequest.RESULT_SUCCESS, 404, "{}"], [HTTPRequest.RESULT_SUCCESS, 200, "broken"], [HTTPRequest.RESULT_SUCCESS, 200, "[]"]]:
		checker.busy = true
		checker.receive(response[0], response[1], [], response[2].to_utf8_buffer())
		check(not checker.busy and "最新" not in checker.message, "network or format failure never reports up to date")
	checker.receive(HTTPRequest.RESULT_SUCCESS, 200, [], '{"tag_name":"v0.3.0"}'.to_utf8_buffer())
	check("发现新版本 0.3.0" in checker.message, "new version result")
	checker.busy = true
	var before := checker.message
	checker.start([], "0.0.0")
	check(checker.current_version == "0.2.2" and checker.message == before, "duplicate checks ignored")
	checker.busy = false
	var fallback := FallbackChecker.new()
	root.add_child(fallback)
	fallback.start(["https://primary.example/version.json", "https://backup.example/version.json"], "0.2.2")
	await process_frame
	check(fallback.requests.size() == 2 and "发现新版本" in fallback.message, "failed primary falls back and succeeds")
	fallback.queue_free()
	var app = load("res://scenes/Main.tscn").instantiate()
	app.settings_path = ""
	root.add_child(app)
	await process_frame
	await process_frame
	app.toggle_menu(app.pets[0])
	app.show_updates()
	check(app.update_panel and not app.update_button.disabled, "update menu available")
	app.update_checker.current_version = "0.2.2"
	app.update_checker.busy = true
	app.update_checker.message = "正在检查更新…"
	app.refresh_update_menu()
	check(app.update_button.disabled, "busy button prevents repeated requests")
	app.close_menu()
	app.update_checker.receive(HTTPRequest.RESULT_SUCCESS, 200, [], '{"version":"0.2.2"}'.to_utf8_buffer())
	app.toggle_menu(app.pets[0])
	app.show_updates()
	check("最新正式版本" in app.update_status.text, "result retained across closed menu")
	app.online.guide_url = "https://example.com/guide"
	app.show_help()
	app.guide_locator = func(): return ""
	app.open_guide()
	check("在线指南" in app.guide_button.text, "missing guide directs to configured online fallback")
	var opened: Array = []
	app.guide_opener = func(url): opened.append(url); return OK
	app.open_online("guide_url")
	check(opened == ["https://example.com/guide"] and app.menu == null, "online guide opens only on explicit click")
	app.online.guide_url = "file:///tmp/a"
	app.open_online("guide_url")
	check(opened.size() == 1, "online links cannot open local files")
	app.toggle_menu(app.pets[0])
	app.show_feedback()
	var column = app.menu.get_child(0)
	check(column.get_child(0).text == "3185470689@qq.com", "feedback email displayed")
	column.get_child(1).pressed.emit()
	check(opened[-1].begins_with("mailto:3185470689@qq.com?subject="), "feedback opens mail draft, does not send")
	app.queue_free()
	checker.queue_free()
	await process_frame
	print("UPDATES: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
