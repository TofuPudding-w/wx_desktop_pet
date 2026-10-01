class_name InteractionManager
extends RefCounted

enum Phase { FREE, APPROACHING, PLAYING }
var phase: Phase = Phase.FREE
var pets: Array[Pet] = []
var pool: Dictionary = {}
var dialogues: Dictionary = {}
var current: Dictionary = {}
var cooldowns: Dictionary = {}
var elapsed := 0.0
var paused := false
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
	return pets.size() == 2 and pets[0].character_id == "A" and pets[1].character_id == "B" and pets[0].foot.x < pets[1].foot.x and absf(pets[0].foot.y - pets[1].foot.y) < 3

func step(delta: float, area: Rect2) -> void:
	for key in cooldowns:
		cooldowns[key] = maxf(0, cooldowns[key] - delta)
	if pets.size() != 2:
		return
	if paused or pets[0].paused or pets[1].paused or pets[0].menu_open or pets[1].menu_open:
		cancel()
		return
	if phase != Phase.FREE and not order_allowed():
		cancel()
		return
	if phase == Phase.FREE:
		if not order_allowed() or not pets[0].available() or not pets[1].available():
			return
		var eligible: Array[String] = []
		var total := 0.0
		for id in pool:
			if cooldowns.get(id, 0.0) <= 0 and pets[0].foot.distance_to(pets[1].foot) < pool[id].trigger_distance and pets[1].foot.x - pool[id].spacing >= area.position.x + DesktopWindowController.FOOT.x:
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
				pet.interaction_frame = 0
	elif phase == Phase.PLAYING:
		var frame := eye_frame(elapsed)
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
	if not order_allowed() or not pets[0].available() or not pets[1].available():
		return
	var item: Dictionary = pool[id]
	var target: float = pets[1].foot.x - item.spacing
	if target < area.position.x + DesktopWindowController.FOOT.x:
		return
	current = item.duplicate()
	current["id"] = id
	# WWX initiates; LWJ reserves his current place and waits, without sliding.
	pets[0].approach_walk_stop = float(item.approach_walk_stop)
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
	for pet in pets:
		pet.heart = false
		pet.interaction_frame = -1
		if pet.state in [Pet.State.APPROACH, Pet.State.INTERACT]:
			pet.change_state(Pet.State.IDLE)
	if current.has("id"):
		cooldowns[current.id] = current.cooldown
	current = {}
	phase = Phase.FREE
	elapsed = 0
