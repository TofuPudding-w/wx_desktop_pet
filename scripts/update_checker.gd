class_name UpdateChecker
extends Node
signal changed
var busy := false
var message := "点击检查（需要联网）"
var current_version := ""
var endpoints: Array[String] = []
var endpoint_index := 0
var request_node: HTTPRequest

func _ready() -> void:
	request_node = HTTPRequest.new()
	request_node.timeout = 10.0
	request_node.body_size_limit = 262144
	request_node.max_redirects = 0
	add_child(request_node)
	request_node.request_completed.connect(receive)

static func https_url(value: Variant) -> bool:
	if not value is String:
		return false
	var regex := RegEx.new()
	regex.compile("^https://[A-Za-z0-9][A-Za-z0-9.-]*(?::[0-9]+)?(?:/[^\\s]*)?$")
	return regex.search(value) != null

static func version_parts(value: Variant) -> Array:
	if not value is String:
		return []
	var regex := RegEx.new()
	regex.compile("^v?(0|[1-9][0-9]{0,8})\\.(0|[1-9][0-9]{0,8})\\.(0|[1-9][0-9]{0,8})$")
	var found := regex.search(value)
	if found == null:
		return []
	return [int(found.get_string(1)), int(found.get_string(2)), int(found.get_string(3))]

static func evaluate(payload: Variant, installed: String) -> Dictionary:
	if not payload is Dictionary:
		return {}
	# Both GitHub's latest-release response and a small static mirror manifest.
	if payload.get("draft", false) != false or payload.get("prerelease", false) != false:
		return {}
	var remote := version_parts(payload.get("tag_name", payload.get("version", "")))
	var local := version_parts(installed)
	if remote.is_empty() or local.is_empty():
		return {}
	var comparison := 0
	for i in range(3):
		if remote[i] != local[i]:
			comparison = 1 if remote[i] > local[i] else -1
			break
	return {"comparison": comparison, "version": "%d.%d.%d" % remote}

func start(urls: Array, installed: String) -> void:
	if busy:
		return
	endpoints.clear()
	for url in urls:
		if https_url(url):
			endpoints.append(url)
	current_version = installed
	endpoint_index = 0
	if endpoints.is_empty():
		message = "更新地址尚未配置"
		changed.emit()
		return
	busy = true
	message = "正在检查更新…"
	changed.emit()
	send_request()

func send_request() -> void:
	var error := request_node.request(endpoints[endpoint_index], ["Accept: application/json", "User-Agent: WangXian-Desktop-Pet"])
	if error != OK:
		failed("无法连接更新服务，请稍后重试")

func failed(reason: String) -> void:
	if endpoint_index + 1 < endpoints.size():
		endpoint_index += 1
		send_request.call_deferred()
		return
	busy = false
	message = reason
	changed.emit()

func receive(result: int, code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	if result != HTTPRequest.RESULT_SUCCESS:
		failed("无法连接更新服务，请检查网络或稍后重试")
		return
	if code != 200:
		failed("暂未取得发布信息（HTTP %d），请稍后重试" % code)
		return
	var parser := JSON.new()
	if parser.parse(body.get_string_from_utf8()) != OK:
		failed("更新信息无效，请稍后重试")
		return
	var outcome := evaluate(parser.data, current_version)
	if outcome.is_empty():
		failed("更新信息无效，请稍后重试")
		return
	busy = false
	if outcome.comparison > 0:
		message = "发现新版本 %s，请前往下载页面" % outcome.version
	elif outcome.comparison == 0:
		message = "当前已是最新正式版本"
	else:
		message = "当前版本高于最新正式版 %s" % outcome.version
	changed.emit()
