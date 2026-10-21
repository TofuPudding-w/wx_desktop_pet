class_name StoryPlayer
extends Node
signal changed
var active := false
var paused := false
var lines: Array = []
var index := 0
var elapsed := 0.0
var status := "尚未播放"
var pets: Array[Pet] = []
var interaction: InteractionManager
var palette: PetSettings
var bubble: StoryBubble
var previous_pet_pause: Array[bool] = []
var previous_interaction_pause := false

func setup(pair: Array[Pet], manager: InteractionManager, settings: PetSettings) -> void:
	pets = pair
	interaction = manager
	palette = settings
	bubble = StoryBubble.new()
	bubble.visible = false
	add_child(bubble)
	bubble.setup(pets[0].font)
	for pet in pets:
		pet.drag_started.connect(func(_pet): stop("拖动角色，播放已停止"))

func start(project: Dictionary) -> String:
	var error := StoryLibrary.playable(project)
	if not error.is_empty():
		return error
	if pets.size() != 2:
		return "播放需要两个角色。"
	for pet in pets:
		if not pet.controller.window.visible or pet.state in [Pet.State.DRAGGED, Pet.State.FALL]:
			return "请先显示两个角色，并等待他们落地。"
	stop()
	interaction.cancel()
	previous_interaction_pause = interaction.paused
	previous_pet_pause.clear()
	for pet in pets:
		previous_pet_pause.append(pet.paused)
		pet.paused = true
		pet.change_state(Pet.State.IDLE)
	interaction.paused = true
	lines = project.lines.duplicate(true)
	index = 0
	elapsed = 0
	active = true
	paused = false
	present_line()
	return ""

func present_line() -> void:
	var line: Dictionary = lines[index]
	for pet in pets:
		if pet.character_id == line.speaker:
			bubble.present(pet, line.text, palette)
	status = "第 %d / %d 句%s" % [index + 1, lines.size(), " · 已暂停" if paused else ""]
	changed.emit()

func step(delta: float) -> void:
	if not active or paused:
		return
	elapsed += maxf(0, delta)
	while active and elapsed >= float(lines[index].seconds):
		elapsed -= float(lines[index].seconds)
		index += 1
		if index >= lines.size():
			stop("播放结束")
		else:
			present_line()

func _process(delta: float) -> void:
	step(delta)

func toggle_pause() -> void:
	if not active:
		return
	paused = not paused
	status = "第 %d / %d 句%s" % [index + 1, lines.size(), " · 已暂停" if paused else ""]
	changed.emit()

func stop(message := "已停止") -> void:
	if not active:
		return
	active = false
	paused = false
	bubble.clear()
	for i in pets.size():
		pets[i].paused = previous_pet_pause[i]
	interaction.paused = previous_interaction_pause
	lines.clear()
	status = message
	changed.emit()
