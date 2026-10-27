extends Area2D
## 终点旗 —— 对应 Day 6 / Day 11「终点放 Area2D，碰到就切换关卡」
##
## 碰到它 → 发 reached 信号 → 关卡脚本负责结算和弹通关界面。
## 旗子本身不知道"下一关是什么"，也不负责切场景，这样职责才清楚。

@export var flag_height: float = 110.0

var _reached: bool = false
var _t: float = 0.0
var _base_pos: Vector2 = Vector2.ZERO

signal reached(pos: Vector2)


func setup(pos: Vector2) -> void:
	_base_pos = pos


func _ready() -> void:
	_base_pos = global_position
	var shape := RectangleShape2D.new()
	shape.size = Vector2(52, flag_height)
	var col := get_node_or_null("CollisionShape2D") as CollisionShape2D
	if col != null:
		col.shape = shape
		col.position = Vector2(0, -flag_height * 0.5)
	body_entered.connect(_on_body_entered)


func _process(delta: float) -> void:
	_t += delta
	queue_redraw()


func _on_body_entered(body: Node2D) -> void:
	if _reached or not body.is_in_group("player"):
		return
	_reached = true
	reached.emit(global_position)


func _draw() -> void:
	var pole := Color(0.80, 0.88, 0.96)
	var h := flag_height
	# 旗杆
	draw_line(Vector2(0, 0), Vector2(0, -h), pole, 4.0)
	draw_circle(Vector2(0, -h), 5.0, Color(0.95, 0.85, 0.35))

	# 旗面：用 sin 让边缘像被风吹起来
	var w := 52.0
	var top := -h + 12.0
	var bottom := -h + 46.0
	var pts := PackedVector2Array()
	var steps := 8
	for i in steps + 1:
		var k := float(i) / float(steps)
		var wave := sin(_t * 3.0 + k * 3.5) * 5.0 * k
		pts.append(Vector2(k * w, top + wave))
	for i in steps + 1:
		var k := 1.0 - float(i) / float(steps)
		var wave := sin(_t * 3.0 + k * 3.5) * 5.0 * k
		pts.append(Vector2(k * w, bottom + wave))
	draw_colored_polygon(pts, Color(0.30, 0.90, 1.0))

	# 地面上的底座，让旗子看起来是插在地上的
	draw_rect(Rect2(-12, -4, 24, 8), Color(0.35, 0.45, 0.58))
