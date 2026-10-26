class_name UnitData
extends Resource

@export_group("Info")
@export var display_name : String = "UnitName"

@export_group("Stats")
@export var max_health : int = 100
@export var move_speed : float = 5
@export var cost : int = 10

@export_group("Combat")
@export var attack : AttackData
@export_range(0.0, 1.0) var knockback_resistance : float = 0.0
@export_range(0.0, 1.0) var stun_resistance : float = 0.0
@export var stun_immunity_time : float = 0.5

@export_group("Poise")
@export var max_poise : int = 100
@export var poise_regen_delay : float = 1.5
@export var poise_regen_rate : int = 10
@export var downed_time : float = 1.2
@export var throw_immunity_time : float = 2.0

@export_group("Sprite")
@export var sprite_frames : SpriteFrames
@export var sprite_offset : Vector2 = Vector2.ZERO
