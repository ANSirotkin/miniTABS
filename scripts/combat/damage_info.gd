class_name DamageInfo
extends RefCounted

var amount: int
var source: Node2D
var knockback_dir: Vector2
var knockback_force: float
var stun_time: float
var poise_damage: float
var throw_force: float


# Used by thrown bodies hitting other units
static func from_impact(source: Node2D, dir: Vector2, amount: int,
		force: float, poise: float) -> DamageInfo:
	var info := DamageInfo.new()
	info.source = source
	info.knockback_dir = dir
	info.amount = amount
	info.knockback_force = force
	info.poise_damage = poise
	return info
