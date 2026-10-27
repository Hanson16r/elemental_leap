extends Area2D
## 蓝色火焰 —— 对应 Day 9「蓝色火焰用 Area2D 实现，碰到就死亡」
##
## 用 Area2D 而不是 StaticBody2D，是因为它要检测"谁进来了"而不是"挡住谁"。
## Area2D 的 body_entered 信号一响，就知道有东西进来了；
## 再判断进来的是不是玩家（用 group 判断，比判断节点名字可靠）。
##
## 火焰的形状用 Polygon2D 画，并且每帧随时间抖动，
## 看起来像在燃烧。不需要任何火焰图片或粒子素材。

@export var flame_size: Vector2 = Vector2(32, 44)

var _visual: Polygon2D
var _col: CollisionShape2D
var _t: float = 0.0
var _base: float = 0.0


func setup(sz: Vector2) -> void:
	flame_size = sz
	_t = randf() * 10.0    # 每团火焰的相位错开，不会整齐划一地跳
	_base = _t
	_apply_shape()


func _ready() -> void:
	_visual = get_node_or_null("Visual") as Polygon2D
	_col = get_node_or_null("CollisionShape2D") as CollisionShape2D
	_apply_shape()
	body_entered.connect(_on_body_entered)

	# 粒子火舌：让静态蓝火也有"在烧"的感觉
	var particles := CPUParticles2D.new()
	particles.amount = 14
	particles.lifetime = 0.55
	particles.direction = Vector2(0, -1)
	particles.spread = 14.0
	particles.initial_velocity_min = 20.0
	particles.initial_velocity_max = 60.0
	particles.gravity = Vector2(0, -60.0)
	particles.scale_amount_min = 1.5
	particles.scale_amount_max = 3.0
	particles.color = Color(0.35, 0.75, 1.0, 0.6)
	particles.emitting = true
	add_child(particles)


func _apply_shape() -> void:
	if _col != null:
		var shape := RectangleShape2D.new()
		# 碰撞盒比视觉略小一点，玩家不会"擦边就死"，手感更宽容
		shape.size = flame_size * 0.8
		_col.shape = shape
	if _visual != null:
		_visual.position = Vector2(0.0, flame_size.y * 0.5)   # 火焰底部对齐节点位置


func _process(delta: float) -> void:
	_t += delta
	if _visual == null:
		return
	var w := flame_size.x
	var h := flame_size.y
	# 火焰轮廓：底部宽，往上收窄并左右摆动
	var sway := sin(_t * 5.2) * w * 0.12
	var flick := 0.86 + 0.14 * sin(_t * 9.0)
	_visual.polygon = PackedVector2Array([
		Vector2(-w * 0.5, 0.0),
		Vector2(-w * 0.34 + sway * 0.4, -h * 0.42 * flick),
		Vector2(sway, -h * flick),
		Vector2(w * 0.34 + sway * 0.4, -h * 0.42 * flick),
		Vector2(w * 0.5, 0.0),
	])
	# 颜色在深蓝和青白之间呼吸
	var k := 0.5 + 0.5 * sin(_t * 6.0)
	_visual.color = Color(0.2, 0.55 + 0.35 * k, 1.0, 0.95)


func _on_body_entered(body: Node2D) -> void:
	# 只对玩家生效。用 group 判断比判断类名更稳（Day 6 也这么干）
	if body.is_in_group("player") and body.has_method("die"):
		body.die()
