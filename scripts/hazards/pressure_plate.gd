extends Area2D
## 【压力板】—— 踩上去发 pressed、松开发 released。第 13 关用来触发天花板火焰。
##
## 和 button.gd 的区别：按钮只按一次就锁死（开门用），压力板要能反复"踩下 / 松开"，
## 所以用 body_entered + body_exited 两个信号，并且记录当前是否被踩住。
## 它自己不知道谁会听：关卡里把 pressed/released 接到火焰喷口的 press()/release() 上。

signal pressed
signal released

@export var width: float = 72.0
@export var height: float = 18.0

var _down: bool = false
var _base: Polygon2D
var _pad: Polygon2D


func _ready() -> void:
	collision_layer = 0
	collision_mask = 2
	monitoring = true

	var shape := RectangleShape2D.new()
	shape.size = Vector2(width, height)
	var col := CollisionShape2D.new()
	col.shape = shape
	add_child(col)

	# 深色底座：嵌在地面里
	_base = Polygon2D.new()
	var hw := width * 0.5
	_base.polygon = PackedVector2Array([
		Vector2(-hw - 4, -height * 0.5), Vector2(hw + 4, -height * 0.5),
		Vector2(hw + 4, height * 0.5), Vector2(-hw - 4, height * 0.5),
	])
	_base.color = Color(0.18, 0.20, 0.24)
	add_child(_base)

	# 中间的活动踏板：踩下去下沉 4 像素
	_pad = Polygon2D.new()
	_pad.polygon = PackedVector2Array([
		Vector2(-hw, -height * 0.5), Vector2(hw, -height * 0.5),
		Vector2(hw, height * 0.5), Vector2(-hw, height * 0.5),
	])
	add_child(_pad)

	_update_visual()
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)


func _update_visual() -> void:
	_pad.position.y = 4.0 if _down else 0.0
	_pad.color = Color(0.98, 0.55, 0.25) if _down else Color(0.75, 0.80, 0.86)


func _on_body_entered(body: Node2D) -> void:
	if _down or not body.is_in_group("player"):
		return
	_down = true
	_update_visual()
	Sfx.play_click()
	pressed.emit()


func _on_body_exited(body: Node2D) -> void:
	if not _down or not body.is_in_group("player"):
		return
	_down = false
	_update_visual()
	released.emit()


## 复活时弹回来。火焰喷口自己也会 reset_hazard()，两边不需要互相通知。
func reset_hazard() -> void:
	_down = false
	_update_visual()
