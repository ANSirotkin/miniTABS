extends CPUParticles2D

func _ready() -> void:
	emitting = false
	await get_tree().create_timer(lifetime + 0.1).timeout
	queue_free()
