extends Area2D
## 按钮 —— 对应 Day 9「加一个开关：踩按钮后门打开」
##
## 按钮不知道门在哪儿，它只负责喊一声"我被踩了，编号是 xxx"。
## 门在另一头听着，编号对上了就开门。这就是**信号解耦**：
## 加第 2 个按钮和第 2 扇门时，两边都不用改代码。

@export var door_id: String = "door_1"
@export var width: float = 56.0
@export var height: float = 14.0

var _visual: Polygon2D
var _pressed: bool = false


func setup(id: String) -> void:
	door_id = id


func _ready() -> void:
	_visual = get_node_or_null("Visual") as Polygon2D
	body_entered.connect(_on_body_entered)
	_apply()


func _apply() -> void:
	var shape := RectangleShape2D.new()
	shape.size = Vector2(width, height)
	var col := get_node_or_null("CollisionShape2D") as CollisionShape2D
	if col != null:
		# 踩按钮是在物理回调里触发的，这时直接改 shape 会报
		# "Can't change this state while flushing queries"，必须延迟到帧末。
		col.set_deferred("shape", shape)
	if _visual != null:
		var hw := width * 0.5
		# 按下去会矮一截，给出"我踩到了"的反馈
		var hh := height * 0.5 * (0.45 if _pressed else 1.0)
		_visual.polygon = PackedVector2Array([
			Vector2(-hw, -hh), Vector2(hw, -hh), Vector2(hw, hh), Vector2(-hw, hh),
		])
		_visual.color = Color(0.40, 0.95, 0.75) if _pressed else Color(0.85, 0.90, 0.55)


func _on_body_entered(body: Node2D) -> void:
	if _pressed or not body.is_in_group("player"):
		return
	_pressed = true
	_apply()
	Sfx.play_click()
	Events.button_pressed.emit(door_id)      # ← 喊一声，门自己会听


## 复活时按钮弹回：门会由 door.gd 的 reset_hazard() 重新关上
func reset_hazard() -> void:
	_pressed = false
	_apply()
