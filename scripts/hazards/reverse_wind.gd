extends Area2D
## 【逆向风场】—— 一条水平向左吹的气流，玩家要按住 D 才顶得过去
##
## 和 wind_zone.gd（顺风加速）的区别：
##   · wind_zone 只提高"最大速度"，不改变方向；
##   · 这里改的是玩家的**目标速度**：不按方向键会被吹到 push（往左），
##     按住 D 也只能到 240 + push，形成"顶风慢速前进"。
##
## 用法：_add_reverse_wind(Vector2(x, y), Vector2(200, 70), -80.0)

@export var size: Vector2 = Vector2(200, 70)
## 目标速度偏移（px/s）：负 = 向左吹
@export var push: float = -80.0

var _band: Polygon2D
var _arrows: Array[Polygon2D] = []
var _t: float = 0.0


func _ready() -> void:
	collision_layer = 4
	collision_mask = 2
	monitoring = true

	var shape := RectangleShape2D.new()
	shape.size = size
	var col := CollisionShape2D.new()
	col.shape = shape
	add_child(col)

	var hw := size.x * 0.5
	var hh := size.y * 0.5

	# 冷蓝色的风带（和上升风场的绿色区分开）
	_band = Polygon2D.new()
	_band.polygon = PackedVector2Array([
		Vector2(-hw, -hh), Vector2(hw, -hh), Vector2(hw, hh), Vector2(-hw, hh),
	])
	_band.color = Color(0.55, 0.68, 1.0, 0.14)
	add_child(_band)

	# 三支向左的箭头
	for i in 3:
		var y := -hh * 0.55 + hh * 0.55 * float(i)
		var arrow := Polygon2D.new()
		arrow.polygon = PackedVector2Array([
			Vector2(10, y - 7), Vector2(-10, y), Vector2(10, y + 7),
		])
		arrow.color = Color(0.70, 0.82, 1.0, 0.65)
		add_child(arrow)
		_arrows.append(arrow)

	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)


func _process(delta: float) -> void:
	_t += delta
	var hw := size.x * 0.5
	var shift := fmod(_t * 130.0, hw * 2.0)
	for i in _arrows.size():
		_arrows[i].position.x = hw - shift
		_arrows[i].modulate.a = 0.6 + 0.35 * sin(_t * 9.0 + float(i))


func _on_body_entered(body: Node2D) -> void:
	if not body.is_in_group("player"):
		return
	if body.has_method("set_side_wind"):
		body.set_side_wind(push)
		Sfx.play_click()


func _on_body_exited(body: Node2D) -> void:
	if not body.is_in_group("player"):
		return
	if body.has_method("set_side_wind"):
		body.set_side_wind(0.0)
