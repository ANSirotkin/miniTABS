# Throwaway test scene: spawns two armies of the same unit.
extends Node2D

@export var unit_scene: PackedScene
@export var unit_data: UnitData
@export var per_team: int = 10


func _ready() -> void:
	for team in 2:
		for i in per_team:
			var u := unit_scene.instantiate() as Unit
			u.data = unit_data          # set BEFORE add_child (Unit._ready reads it)
			u.team = team
			u.position = Vector2(40 if team == 0 else 280, 30 + i * 10)
			add_child(u)
