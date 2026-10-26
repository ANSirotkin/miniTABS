class_name HitData
extends Resource

enum KnockbackMode { AWAY_FROM_SOURCE, ALONG_TRAVEL, AWAY_FROM_HITBOX }

@export_group("Impact")
@export var damage: int = 10
@export var knockback_force: float = 80.0
@export var knockback_mode: KnockbackMode = KnockbackMode.AWAY_FROM_SOURCE
@export var stun_time: float = 0.0

@export_group("Poise")
@export var poise_damage: float = 15.0
@export var throw_force: float = 120.0   # ~57px slide at THROWN_FRICTION 120

@export_group("Travel")
@export var speed: float = 0.0           # 0 = stationary (melee, explosions)
@export var lifetime: float = 0.1
@export var max_hits: int = 1            # 0 = unlimited (cleave / pierce)
@export var destroyed_by_walls: bool = true
