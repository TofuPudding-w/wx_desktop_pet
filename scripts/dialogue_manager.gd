class_name DialogueManager
extends RefCounted

var participants: Array[Pet] = []
var lines: Array = []
var duration := 4.0
var last_index := -1

func start(pets: Array[Pet], dialogue: Array, seconds: float) -> void:
	clear()
	participants = pets.duplicate()
	lines = dialogue
	duration = seconds
	update(0)

func update(elapsed: float) -> void:
	if lines.is_empty():
		return
	var index := mini(int(elapsed / duration * lines.size()), lines.size() - 1)
	if index == last_index:
		return
	last_index = index
	for pet in participants:
		pet.set_bubble(str(lines[index].text) if pet.character_id == lines[index].speaker else "")

func clear() -> void:
	for pet in participants:
		pet.set_bubble("")
	participants.clear()
	lines = []
	last_index = -1
