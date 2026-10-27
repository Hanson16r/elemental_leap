extends StaticBody2D
## 被按钮打开的门 —— 对应 Day 9
##
## 它监听 Events.button_pressed，编号和自己对得上就开门。
## 开门 = 碰撞形状失效 + 播放一个缩扁的动画（视觉上像门往两边收进去）。

@export var door_id: String = "door_1"
@export var door_size: Vector2 = Vector2(40, 140)

var _visual: Polygon2D
var _col: CollisionShape2D
var _open: bool = false


func setup(id: String, size: Vector2) -> void:
	door_id = id
	door_size = size


func _ready() -> void:
	_visual = get_node_or_null("Visual") as Polygon2D
	_col = get_node_or_null("CollisionShape2D") as CollisionShape2D
	_apply()
	Events.button_pressed.connect(_on_button_pressed)


func _apply() -> void:
	if _col != null:
		var shape := RectangleShape2D.new()
		shape.size = door_size
		_col.shape = shape
	if _visual != null:
		var hw := door_size.x * 0.5
		var hh := door_size.y * 0.5
		_visual.polygon = PackedVector2Array([
			Vector2(-hw, -hh), Vector2(hw, -hh), Vector2(hw, hh), Vector2(-hw, hh),
		])
		_visual.color = Color(0.72, 0.80, 0.90)


func _on_button_pressed(id: String) -> void:
	if id != door_id or _open:
		return
	_open = true
	Sfx.play_click()
	Events.door_opened.emit(door_id)
	if _col != null:
		_col.set_deferred("disabled", true)
	if _visual != null:
		# 往两边缩进去
		var tw := create_tween()
		tw.tween_property(_visual, "scale", Vector2(0.05, 1.0), 0.35)\
			.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)


## 复活时门重新关上：按钮/火盆要重新触发
func reset_hazard() -> void:
	_open = false
	if _col != null:
		_col.set_deferred("disabled", false)
	if _visual != null:
		_visual.scale = Vector2.ONE
		_apply()
