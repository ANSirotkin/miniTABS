# scenes/units/unit.gd
class_name Unit
extends CharacterBody2D

enum State { IDLE, MOVE, WINDUP, RECOVER, STUNNED, THROWN, DOWNED, DEAD }

# Physics layers (set these in Project Settings -> Layer Names -> 2D Physics)
const LAYER_UNITS := 2    # units live on layer 2, and normally only mask walls (layer 1)

# Shared by EVERY unit. Only assigned to a sprite for ~0.1s while it flashes.
const FLASH_MATERIAL: ShaderMaterial = preload("res://resources/materials/hit_flash.tres")
const FLASH_TIME := 0.1

const DEATH_FLASH_MATERIAL: ShaderMaterial = preload("res://resources/materials/death_flash.tres")
const DEATH_BURST: PackedScene = preload("res://scenes/fx/death_burst.tscn")
const DEATH_FLASH_TIME := 0.15

# Targeting
const RETARGET_INTERVAL := 0.4
const FAR_RETARGET_INTERVAL := 1.0   # when no enemy is nearby, search less often

# Knockback
const KNOCKBACK_FRICTION := 500.0
const KNOCKBACK_LOCKOUT := 20.0

# Thrown
const THROWN_FRICTION := 120.0
const THROW_END_SPEED := 25.0
const THROW_MAX_TIME := 1.2
const WALL_SLAM_SPEED := 90.0
const WALL_SLAM_DAMAGE := 8
const IMPACT_DAMAGE := 6
const IMPACT_POISE_PER_SPEED := 0.25

# Poise
const STUNNED_POISE_MULT := 1.5

@export var data: UnitData
@export var team: int = 0

@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D

const SEPARATION_RADIUS := 6.0
const SEPARATION_STRENGTH := 25.0
const SEPARATION_INTERVAL := 0.1

var separation := Vector2.ZERO
var separation_timer := randf() * SEPARATION_INTERVAL

var state: State = State.IDLE
var target: Unit

var intent := Vector2.ZERO        # velocity the unit WANTS
var knockback := Vector2.ZERO     # velocity imposed by hits
var friction := KNOCKBACK_FRICTION

var state_timer := 0.0
var attack_cooldown := 0.0
var stun_immunity := 0.0
var retarget_timer := 0.0
var flash_timer := 0.0

var poise_buildup := 0.0
var poise_regen_timer := 0.0
var poise_immunity := 0.0
var thrown_hits: Array[Unit] = []

var health : int

const TEAM_TINTS: Array[Color] = [Color(0.7, 0.85, 1.0), Color(1.0, 0.65, 0.65)]

func _ready() -> void:
	sprite.sprite_frames = data.sprite_frames
	sprite.offset = data.sprite_offset
	sprite.flip_h = (team == 1)
	
	sprite.self_modulate = TEAM_TINTS[team % TEAM_TINTS.size()]

	health = data.max_health

	retarget_timer = randf() * RETARGET_INTERVAL   # spread searches across frames
	UnitRegistry.register(self)
	_set_state(State.IDLE)


func _exit_tree() -> void:
	UnitRegistry.unregister(self)


func _physics_process(delta: float) -> void:
	attack_cooldown = maxf(attack_cooldown - delta, 0.0)
	stun_immunity = maxf(stun_immunity - delta, 0.0)
	_tick_flash(delta)
	_tick_poise(delta)
	intent = Vector2.ZERO

	separation_timer -= delta
	if separation_timer <= 0.0:
		separation_timer = SEPARATION_INTERVAL
		separation = UnitRegistry.get_separation(self, SEPARATION_RADIUS)

	match state:
		State.IDLE, State.MOVE:
			_tick_seek(delta)
			intent += separation * SEPARATION_STRENGTH
		State.WINDUP:
			_tick_windup(delta)
		State.RECOVER:
			_tick_timed(delta, State.IDLE)
		State.STUNNED:
			_tick_timed(delta, State.IDLE)
		State.THROWN:
			_tick_thrown(delta)
		State.DOWNED:
			_tick_downed(delta)
		State.DEAD:
			pass   # corpses still slide from knockback

	# Two layers: what the unit wants + what hits imposed on it
	velocity = intent + knockback
	knockback = knockback.move_toward(Vector2.ZERO, friction * delta)
	move_and_slide()

	if state == State.THROWN:
		_check_throw_collisions()


# ---------- Seeking and attacking ----------

func _tick_seek(delta: float) -> void:
	if knockback.length() > KNOCKBACK_LOCKOUT:
		_set_state(State.IDLE)   # being launched, can't walk yet
		return

	retarget_timer -= delta
	if retarget_timer <= 0.0 or _target_lost():
		_retarget()

	if target == null:
		_set_state(State.IDLE)
		return

	var to_target := target.global_position - global_position
	sprite.flip_h = to_target.x < 0.0

	if to_target.length() > data.attack.attack_range:
		intent = to_target.normalized() * data.move_speed
		_set_state(State.MOVE)
	elif attack_cooldown <= 0.0:
		_set_state(State.WINDUP, data.attack.windup)
	else:
		_set_state(State.IDLE)


func _target_lost() -> bool:
	# true only if we HAD a target and it died or was freed
	return target != null and (not is_instance_valid(target) or target.state == State.DEAD)


func _retarget() -> void:
	target = UnitRegistry.find_nearest_enemy(self)
	retarget_timer = RETARGET_INTERVAL if target != null else FAR_RETARGET_INTERVAL


func _tick_windup(delta: float) -> void:
	state_timer -= delta
	if state_timer > 0.0:
		return
	_spawn_attack()
	attack_cooldown = data.attack.cooldown
	_set_state(State.RECOVER, data.attack.recovery)


func _spawn_attack() -> void:
	var atk := data.attack
	var dir := Vector2.LEFT if sprite.flip_h else Vector2.RIGHT
	if is_instance_valid(target):
		dir = (target.global_position - global_position).normalized()

	var hb := atk.hit_scene.instantiate() as Hitbox
	get_tree().current_scene.add_child(hb)
	hb.global_position = global_position + atk.spawn_offset.rotated(dir.angle())
	hb.setup(self, atk.hit, dir)


func _tick_timed(delta: float, next: State) -> void:
	state_timer -= delta
	if state_timer > 0.0:
		return
	if state == State.STUNNED:
		stun_immunity = data.stun_immunity_time
	_set_state(next)


# ---------- Taking hits ----------

func _take_damage(amount: int) -> void:
	if state == State.DEAD:
		return
	health -= amount
	if health <= 0:
		_on_died()
		
func receive_hit(info: DamageInfo) -> void:
	if state == State.DEAD:
		return
		
	_take_damage(info.amount)
	Events.unit_damaged.emit(self, info)

	if state == State.DEAD:
		_apply_knockback(info)      # corpses still fly
		return

	# Airborne or on the ground: damage only
	if state == State.THROWN or state == State.DOWNED:
		_flash()
		return

	# Poise may convert this hit into a throw (replaces knockback and stun)
	if _add_poise(info):
		_flash()
		return

	_apply_knockback(info)

	var stun = info.stun_time * (1.0 - data.stun_resistance)
	if stun > 0.0 and state != State.STUNNED and stun_immunity <= 0.0:
		_set_state(State.STUNNED, stun)

	_flash()


func _apply_knockback(info: DamageInfo) -> void:
	var force = info.knockback_force * (1.0 - data.knockback_resistance)
	if force > 0.0:
		knockback += info.knockback_dir * force


# ---------- Poise (no UI, just state) ----------

func _tick_poise(delta: float) -> void:
	poise_immunity = maxf(poise_immunity - delta, 0.0)
	if poise_regen_timer > 0.0:
		poise_regen_timer -= delta
	elif poise_buildup > 0.0:
		poise_buildup = maxf(poise_buildup - data.poise_regen_rate * delta, 0.0)


func _add_poise(info: DamageInfo) -> bool:
	if poise_immunity > 0.0 or info.poise_damage <= 0.0:
		return false

	var mult := STUNNED_POISE_MULT if state == State.STUNNED else 1.0
	poise_buildup += info.poise_damage * mult
	poise_regen_timer = data.poise_regen_delay

	if poise_buildup < data.max_poise:
		return false

	var overflow := (poise_buildup - data.max_poise) / data.max_poise
	_get_thrown(info, overflow)
	return true


# ---------- Thrown / Downed ----------

func _get_thrown(info: DamageInfo, overflow: float) -> void:
	poise_buildup = 0.0
	thrown_hits.clear()

	var force := info.throw_force * (1.0 + overflow) * (1.0 - data.knockback_resistance)
	knockback = info.knockback_dir * force
	friction = THROWN_FRICTION

	# Only thrown units physically collide with other units (bowling)
	#set_collision_mask_value(LAYER_UNITS, true)

	_set_state(State.THROWN, THROW_MAX_TIME)
	Events.unit_thrown.emit(self, info)


func _tick_thrown(delta: float) -> void:
	state_timer -= delta
	if state_timer <= 0.0 or knockback.length() < THROW_END_SPEED:
		_land()


func _land() -> void:
	knockback = Vector2.ZERO
	friction = KNOCKBACK_FRICTION
	set_collision_mask_value(LAYER_UNITS, false)
	Events.unit_landed.emit(self)
	_set_state(State.DOWNED, data.downed_time)


func _tick_downed(delta: float) -> void:
	state_timer -= delta
	if state_timer > 0.0:
		return
	poise_immunity = data.throw_immunity_time
	stun_immunity = data.stun_immunity_time
	attack_cooldown = maxf(attack_cooldown, 0.3)   # don't swing the instant they stand
	_set_state(State.IDLE)


func _check_throw_collisions() -> void:
	var speed := knockback.length()
	for i in get_slide_collision_count():
		var col := get_slide_collision(i)
		var other := col.get_collider() as Unit

		if other != null:
			if other in thrown_hits or other.state == State.DEAD:
				continue
			thrown_hits.append(other)
			var info := DamageInfo.from_impact(
				self, knockback.normalized(), IMPACT_DAMAGE,
				speed * 0.4, speed * IMPACT_POISE_PER_SPEED)
			other.receive_hit(info)
			knockback *= 0.6   # lose momentum
		elif speed > WALL_SLAM_SPEED:
			knockback = knockback.bounce(col.get_normal()) * 0.3
			Events.unit_wall_slammed.emit(self)
			break


# ---------- Death ----------

func _on_died() -> void:
	_set_state(State.DEAD)
	UnitRegistry.unregister(self)   # stop being a target immediately
	$CollisionShape2D.set_deferred("disabled", true)
	Events.unit_died.emit(self)

	# Red flash, frozen on the current frame (still slides from knockback)
	flash_timer = 0.0
	sprite.material = DEATH_FLASH_MATERIAL
	sprite.pause()

	await get_tree().create_timer(DEATH_FLASH_TIME).timeout
	if not is_inside_tree():
		return

	var burst := DEATH_BURST.instantiate() as Node2D
	get_tree().current_scene.add_child(burst)
	burst.global_position = global_position
	burst.emitting = true
	queue_free()


# ---------- State and visuals ----------

func _set_state(new_state: State, duration: float = 0.0) -> void:
	if new_state == state and duration == 0.0:
		return
	state = new_state
	state_timer = duration
	match new_state:
		State.IDLE:    sprite.play("idle")
		State.MOVE:    sprite.play("walk")
		State.WINDUP:  sprite.play("attack")
		State.STUNNED: sprite.play("stun")
		State.THROWN:  sprite.play("thrown")
		State.DOWNED:  sprite.play("downed")
		State.DEAD:    pass
		# RECOVER: let the attack animation finish on its own


# Hit flash: swap in one shared all-white material briefly, then restore.
# No per-unit materials, no tweens, no allocations.
func _flash() -> void:
	flash_timer = FLASH_TIME
	sprite.material = FLASH_MATERIAL


func _tick_flash(delta: float) -> void:
	if flash_timer <= 0.0:
		return
	flash_timer -= delta
	if flash_timer <= 0.0:
		sprite.material = null
