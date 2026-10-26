class_name Hitbox
extends Area2D

var data: HitData
var team: int
var direction := Vector2.RIGHT
var origin := Vector2.ZERO          # source position at spawn (source may die)
var life := 0.0
var hit_count := 0
var already_hit: Array[Unit] = []


func _ready() -> void:
	body_entered.connect(_on_body_entered)


# Call AFTER add_child and after setting global_position
func setup(source: Unit, hit_data: HitData, dir: Vector2) -> void:
	data = hit_data
	team = source.team
	origin = source.global_position
	direction = dir.normalized()
	life = data.lifetime
	rotation = direction.angle()
	if direction.x < 0.0:
		scale.y = -1.0      # keeps sprites upright when facing left


func _physics_process(delta: float) -> void:
	global_position += direction * data.speed * delta
	life -= delta
	if life <= 0.0:
		queue_free()


func _on_body_entered(body: Node2D) -> void:
	var unit := body as Unit
	if unit == null:
		if data.destroyed_by_walls:
			queue_free()
		return
	if unit.team == team or unit in already_hit or unit.state == Unit.State.DEAD:
		return

	already_hit.append(unit)
	unit.receive_hit(_build_info(unit))

	hit_count += 1
	if data.max_hits > 0 and hit_count >= data.max_hits:
		queue_free()


func _build_info(target: Unit) -> DamageInfo:
	var info := DamageInfo.new()
	info.amount = data.damage
	info.knockback_force = data.knockback_force
	info.stun_time = data.stun_time
	info.poise_damage = data.poise_damage
	info.throw_force = data.throw_force

	match data.knockback_mode:
		HitData.KnockbackMode.AWAY_FROM_SOURCE:
			info.knockback_dir = (target.global_position - origin).normalized()
		HitData.KnockbackMode.ALONG_TRAVEL:
			info.knockback_dir = direction
		HitData.KnockbackMode.AWAY_FROM_HITBOX:
			info.knockback_dir = (target.global_position - global_position).normalized()

	if info.knockback_dir == Vector2.ZERO:
		info.knockback_dir = direction
	return info
