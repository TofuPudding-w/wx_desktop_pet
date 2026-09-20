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

func step(delta: float, area: Rect2) -> void:
	for key in cooldowns:
		cooldowns[key] = maxf(0, cooldowns[key] - delta)
	if paused or pets.size() != 2:
		return
	if phase == Phase.FREE:
		if not pets[0].available() or not pets[1].available():
			return
		var eligible: Array[String] = []
		var total := 0.0
		for id in pool:
			if cooldowns.get(id, 0.0) <= 0 and pets[0].foot.distance_to(pets[1].foot) < pool[id].trigger_distance:
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
		elif absf(pets[0].foot.x-pets[0].target_x) < 1 and absf(pets[1].foot.x-pets[1].target_x) < 1:
			phase = Phase.PLAYING
			elapsed = 0
			for pet in pets:
				pet.change_state(Pet.State.INTERACT)
				pet.heart = true
			dialogue.start(pets, dialogues[current.dialogue], current.duration)
	elif phase == Phase.PLAYING:
		dialogue.update(elapsed)
		if elapsed >= current.duration:
			completed += 1
			release()

func begin(id: String, area: Rect2) -> void:
	current = pool[id].duplicate()
	current["id"] = id
	var half: float = current.spacing / 2.0
	if area.size.x < 240 + current.spacing:
		return
	var midpoint := clampf((pets[0].foot.x + pets[1].foot.x) / 2,
		area.position.x + 120 + half, area.end.x - 120 - half)
	var direction := 1.0 if pets[0].foot.x <= pets[1].foot.x else -1.0
	pets[0].target_x = midpoint - half * direction
	pets[1].target_x = midpoint + half * direction
	pets[0].facing = direction
	pets[1].facing = -direction
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
		if pet.state in [Pet.State.APPROACH, Pet.State.INTERACT]:
			pet.change_state(Pet.State.IDLE)
	if current.has("id"):
		cooldowns[current.id] = current.cooldown
	current = {}
	phase = Phase.FREE
	elapsed = 0
