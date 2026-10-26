# scripts/autoload/unit_registry.gd
extends Node

var units: Array[Unit] = []


func register(u: Unit) -> void:
	if not units.has(u):
		units.append(u)


func unregister(u: Unit) -> void:
	units.erase(u)


func find_nearest_enemy(from: Unit) -> Unit:
	var best: Unit = null
	var best_d := INF
	for u in units:
		if u.team == from.team or u.state == Unit.State.DEAD:
			continue
		var d := from.global_position.distance_squared_to(u.global_position)
		if d < best_d:
			best_d = d
			best = u
	return best

const CELL := 16   # keep this >= the separation radius

var grid: Dictionary = {}   # Vector2i -> Array[Unit]

func _physics_process(_delta: float) -> void:
	grid.clear()
	for u in units:
		var cell := Vector2i((u.global_position / CELL).floor())
		if grid.has(cell):
			grid[cell].append(u)
		else:
			grid[cell] = [u]


func get_separation(from: Unit, radius: float) -> Vector2:
	var push := Vector2.ZERO
	var center := Vector2i((from.global_position / CELL).floor())
	for x in range(-1, 2):
		for y in range(-1, 2):
			var bucket: Array = grid.get(center + Vector2i(x, y), [])
			for u: Unit in bucket:
				if u == from or u.state == Unit.State.DEAD:
					continue
				var offset := from.global_position - u.global_position
				var d := offset.length()
				if d >= radius:
					continue
				if d < 0.01:
					offset = Vector2.from_angle(randf() * TAU)   # exactly stacked: pick a direction
					d = 1.0
				push += offset / d * (1.0 - d / radius)   # stronger the closer they are
	return push
