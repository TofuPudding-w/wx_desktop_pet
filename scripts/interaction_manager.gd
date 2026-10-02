class_name InteractionManager
extends RefCounted

enum Phase { FREE, APPROACHING, PLAYING }
var size_factor := 1.0
var phase: Phase = Phase.FREE
var pets: Array[Pet] = []
var pool: Dictionary = {}
var dialogues: Dictionary = {}
var current: Dictionary = {}
var cooldowns: Dictionary = {}
var elapsed := 0.0
var rest_remaining := 0.0
var combined_frame := -1
var paused := false
var automatic_enabled := true
var completed := 0
var cancelled := 0
var dialogue := DialogueManager.new()

func setup(pair: Array[Pet], interactions: Dictionary, text: Dictionary) -> void:
	pets = pair
	pool = interactions
	dialogues = text
	for pet in pets:
		pet.drag_started.connect(func(_pet): cancel())

func order_allowed() -> bool:
	return pets.size() == 2 and pets[0].character_id == "A" and pets[1].character_id == "B" and pets[0].foot.x < pets[1].foot.x and absf(pets[0].foot.y - pets[1].foot.y) < 3 * size_factor

func advance_cooldowns(delta: float) -> void:
	rest_remaining = maxf(0, rest_remaining - delta)
	for key in cooldowns:
		cooldowns[key] = maxf(0, cooldowns[key] - delta)

func step(delta: float, area: Rect2, cooldown_delta := -1.0) -> void:
	advance_cooldowns(delta if cooldown_delta < 0 else cooldown_delta)
	if pets.size() != 2:
		return
	if paused or pets[0].paused or pets[1].paused or pets[0].menu_open or pets[1].menu_open:
		cancel()
		return
	if phase != Phase.FREE and not order_allowed():
		cancel()
		return
	if phase == Phase.FREE:
		if not automatic_enabled or rest_remaining > 0:
			return
		if not order_allowed() or not pets[0].available() or not pets[1].available():
			return
		var eligible: Array[String] = []
		var total := 0.0
		for id in pool:
			if cooldowns.get(id, 0.0) <= 0 and pets[0].foot.distance_to(pets[1].foot) < pool[id].trigger_distance * size_factor and pets[1].foot.x - pool[id].spacing * size_factor >= area.position.x + DesktopWindowController.FOOT.x * size_factor:
				eligible.append(id)
				total += pool[id].weight
		if eligible.is_empty():
			return
		var roll := randf() * total
		for id in eligible:
			roll -= pool[id].weight
			if roll <= 0:
				begin(id, area)
				break
		return
	elapsed += delta
	if phase == Phase.APPROACHING:
		if elapsed >= current.approach_timeout:
			cancel()
		elif absf(pets[0].foot.x - pets[0].target_x) < 1:
			phase = Phase.PLAYING
			elapsed = 0
			pets[0].facing = 1
			pets[1].facing = -1
			for pet in pets:
				pet.change_state(Pet.State.INTERACT)
				pet.interaction_frame = -1 if current.kind == "hug" else 0
			if current.kind == "hug":
				combined_frame = 0
	elif phase == Phase.PLAYING:
		var frame := -1 if current.kind == "hug" else eye_frame(elapsed)
		if current.kind == "hug":
			combined_frame = HugSequence.frame_at(elapsed, current.frame_durations, int(current.hold_repeats))
		for pet in pets:
			if pet.interaction_frame != frame and frame == -1:
				pet.state_time = 0 # shared idle begins at the matching first frame
			pet.interaction_frame = frame
		if elapsed >= current.duration:
			completed += 1
			release()

func eye_frame(seconds: float) -> int:
	var fps: float = current.fps
	var forward := 5.0 / fps
	if seconds < forward:
		return mini(int(seconds * fps), 4)
	if seconds < forward + current.hold:
		return 4
	if seconds < 2 * forward + current.hold:
		return 5 + mini(int((seconds - forward - current.hold) * fps), 4)
	return -1

func begin(id: String, area: Rect2) -> void:
	if phase != Phase.FREE or not pool.has(id) or not order_allowed() or not pets[0].available() or not pets[1].available():
		return
	var item: Dictionary = pool[id]
	var target: float = pets[1].foot.x - item.spacing * size_factor
	if target < area.position.x + DesktopWindowController.FOOT.x * size_factor:
		return
	current = item.duplicate()
	current["id"] = id
	# WWX initiates; LWJ reserves his current place and waits, without sliding.
	pets[0].approach_walk_stop = float(item.approach_walk_stop) * size_factor
	pets[0].target_x = target
	pets[1].target_x = pets[1].foot.x
	pets[0].facing = 1 if target >= pets[0].foot.x else -1
	pets[1].facing = -1
	for pet in pets:
		pet.change_state(Pet.State.APPROACH)
	phase = Phase.APPROACHING
	elapsed = 0

func cancel() -> void:
	if phase != Phase.FREE:
		cancelled += 1
		release()

func release() -> void:
	dialogue.clear()
	combined_frame = -1
	for pet in pets:
		pet.heart = false
		pet.interaction_frame = -1
		if pet.state in [Pet.State.APPROACH, Pet.State.INTERACT]:
			pet.change_state(Pet.State.IDLE)
	if current.has("id"):
		cooldowns[current.id] = current.cooldown
		rest_remaining = current.rest_after
	current = {}
	phase = Phase.FREE
	elapsed = 0

# Manual selection uses the same placement and cooldown rules as automatic encounters.
func request_reason(id: String, area: Rect2, allow_menu := false) -> String:
	if not pool.has(id):
		return "当前不可用"
	if pets.size() != 2:
		return "需要两位角色"
	if paused or pets[0].paused or pets[1].paused:
		return "请先继续活动"
	if phase != Phase.FREE:
		return "正在互动"
	for pet in pets:
		if pet.state not in [Pet.State.IDLE, Pet.State.WALK] or (pet.menu_open and not allow_menu):
			return "请等待落地"
	if not order_allowed():
		return "魏左蓝右，并排落地"
	if cooldowns.get(id, 0.0) > 0:
		return "冷却 %d 秒" % ceili(cooldowns[id])
	if rest_remaining > 0:
		return "间隔 %d 秒" % ceili(rest_remaining)
	var item: Dictionary = pool[id]
	if pets[0].foot.distance_to(pets[1].foot) >= item.trigger_distance * size_factor:
		return "请将两人拖近一些"
	if pets[1].foot.x - item.spacing * size_factor < area.position.x + DesktopWindowController.FOOT.x * size_factor:
		return "请移离左边缘"
	return ""

func request(id: String, area: Rect2) -> bool:
	if not request_reason(id, area).is_empty():
		return false
	begin(id, area)
	return phase == Phase.APPROACHING
