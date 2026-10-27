extends Area2D
## 【火球】—— 怪物喷出来的火球，碰到就死
##
## 由 fire_shooter.gd 生成；水平飞，飞出 3 秒或撞到玩家后消失。
## 视觉：橙色光球 + 核心 + 拖尾粒子（参考你图里的火球）。

var direction: float = -1.0
var speed: float = 170.0
var life: float = 3.0
var _glow: Polygon2D
var _core: Polygon2D
var _trail: CPUParticles2D
var _t: float = 0.0


func setup(dir: float, spd: float = 170.0) -> void:
	direction = signf(dir)
	speed = spd


func _ready() -> void:
	collision_layer = 4
	collision_mask = 2
	monitoring = true

	var shape := CircleShape2D.new()
	shape.radius = 11.0
	var col := CollisionShape2D.new()
	col.shape = shape
	add_child(col)

	_glow = Polygon2D.new()
	_glow.polygon = _circle(13.0, 14)
	_glow.color = Color(1.0, 0.45, 0.15, 0.9)
	add_child(_glow)

	_core = Polygon2D.new()
	_core.polygon = _circle(7.0, 12)
	_core.color = Color(1.0, 0.9, 0.4)
	add_child(_core)

	_trail = CPUParticles2D.new()
	_trail.amount = 14
	_trail.lifetime = 0.35
	_trail.direction = Vector2(-direction, 0)
	_trail.spread = 12.0
	_trail.initial_velocity_min = 20.0
	_trail.initial_velocity_max = 60.0
	_trail.gravity = Vector2.ZERO
	_trail.scale_amount_min = 1.5
	_trail.scale_amount_max = 3.5
	_trail.color = Color(1.0, 0.5, 0.2, 0.7)
	_trail.emitting = true
	add_child(_trail)

	body_entered.connect(_on_body_entered)


func _physics_process(delta: float) -> void:
	position.x += direction * speed * delta
	_t += delta
	_glow.scale = Vector2.ONE * (1.0 + sin(_t * 20.0) * 0.08)
	life -= delta
	if life <= 0.0:
		queue_free()


func _on_body_entered(body: Node2D) -> void:
	if not body.is_in_group("player"):
		return
	if body.has_method("die"):
		body.die()
	queue_free()


func _circle(r: float, n: int) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in n:
		var a := TAU * float(i) / float(n)
		pts.append(Vector2(cos(a), sin(a)) * r)
	return pts


## 复活时把空中的火球清掉，避免玩家一出生就被旧火球打死
func reset_hazard() -> void:
	queue_free()
