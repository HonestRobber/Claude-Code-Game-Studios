# PROTOTYPE - NOT FOR PRODUCTION — Question: is a readable isometric survival loop (move, loot, evade) achievable here?
extends RefCounted
## Item-id -> count store. Emits `changed` on every mutation.

signal changed

var items: Dictionary = {}


func add(id: String, amount := 1) -> void:
	items[id] = int(items.get(id, 0)) + amount
	changed.emit()


func remove(id: String, amount := 1) -> bool:
	var have: int = int(items.get(id, 0))
	if have < amount:
		return false
	if have == amount:
		items.erase(id)
	else:
		items[id] = have - amount
	changed.emit()
	return true


func count(id: String) -> int:
	return int(items.get(id, 0))


func total() -> int:
	var n := 0
	for id: String in items:
		n += int(items[id])
	return n
