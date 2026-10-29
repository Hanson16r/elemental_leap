extends Area2D
## 检查点 —— 对应 Day 6「加检查点节点，碰到后更新复活点」
##
## 玩家碰到它 → 更新复活点 + 播检查点音效 + 变绿表示已激活。
## 注意：已激活的检查点不会重复触发，否则玩家反复经过会响个不停。

@export var radius: float = 26.0
## 触发区竖向高度：> 0 时把触发区拉成长条（从地面往上这么高），
## 上下两条路线（比如桥面和地面）经过都能碰到
@export var reach: float = 0.0

var _active: bool = false
var _visual: Node2D
var _my_pos: Vector2 = Vector2.ZERO


func setup(pos: Vector2) -> void:
	# 复活点要站在检查点的正上方一点，不能和检查点本身重叠
	_my_pos = pos + Vector2(0.0, -30.0)


func _ready() -> void:
	_visual = get_node_or_null("Visual") as Node2D
	var col := get_node_or_null("CollisionShape2D") as CollisionShape2D
	if col != null:
		if reach > 0.0:
			# 竖向长条：底边落在地面上，往上覆盖 reach 像素
			var rect := RectangleShape2D.new()
			rect.size = Vector2(radius * 2.0, reach)
			col.shape = rect
			col.position = Vector2(0.0, -reach * 0.5)
		else:
			var shape := CircleShape2D.new()
			shape.radius = radius
			col.shape = shape
	body_entered.connect(_on_body_entered)
	if _my_pos == Vector2.ZERO:
		_my_pos = global_position + Vector2(0.0, -30.0)
	queue_redraw()


func _on_body_entered(body: Node2D) -> void:
	if _active or not body.is_in_group("player"):
		return
	_active = true
	Sfx.play_checkpoint()
	Events.checkpoint_reached.emit(global_position + Vector2(0.0, -30.0))
	queue_redraw()
	# 轻轻弹一下作为反馈
	if _visual != null:
		var tw := create_tween()
		tw.tween_property(_visual, "scale", Vector2(1.5, 1.5), 0.12)
		tw.tween_property(_visual, "scale", Vector2.ONE, 0.2)


func _draw() -> void:
	# 一根杆 + 一面小旗；未激活是灰蓝，激活后是亮青色
	var pole := Color(0.55, 0.66, 0.80)
	var cloth := Color(0.25, 0.95, 0.75) if _active else Color(0.42, 0.52, 0.68)
	draw_line(Vector2(0, 20), Vector2(0, -28), pole, 3.0)
	draw_colored_polygon(PackedVector2Array([
		Vector2(1, -26), Vector2(22, -18), Vector2(1, -10),
	]), cloth)
	if _active:
		draw_arc(Vector2.ZERO, radius, 0.0, TAU, 24, Color(0.25, 0.95, 0.75, 0.35), 2.0)
