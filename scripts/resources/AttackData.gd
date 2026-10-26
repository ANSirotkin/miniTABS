class_name AttackData
extends Resource

@export_group("Timing")
@export var windup: float = 0.25
@export var recovery: float = 0.35
@export var cooldown: float = 0.8

@export_group("AI")
@export var attack_range: float = 14.0   # distance at which the unit starts a windup

@export_group("Hit")
@export var hit_scene: PackedScene       # slash.tscn, arrow.tscn, ...
@export var hit: HitData
@export var spawn_offset: Vector2 = Vector2(8, 0)   # in the attack's facing direction
