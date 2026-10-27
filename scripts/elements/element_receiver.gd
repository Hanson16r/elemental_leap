extends Area2D
## 【元素接收器 / 火盆】—— 把手里元素"用掉"的地方
##
## 沿用原来的"按钮 → 门"信号：接收器只负责喊一声
##   Events.button_pressed.emit(door_id)
## 门自己会听、自己会开。接收器完全不知道门在哪 —— 这就是解耦。
##
## 用法：关卡里 _add_element_receiver(pos, Element.Kind.FIRE, "gate")

## 需要哪种元素（Element.Kind）
@export var required: int = Element.Kind.FIRE
## 消耗后要打开哪扇门（和 door.gd 的 door_id 对上）
@export var door_id: String = "gate"

var _used: bool = false
var _visual: Polygon2D
var _label: Label


func _ready() -> void:
	collision_layer = 8
	collision_mask = 2
	monitoring = true

	var shape := CircleShape2D.new()
	shape.radius = 34.0
	var col := CollisionShape2D.new()
	col.shape = shape
	add_child(col)

	# 一个碗的形状
	_visual = Polygon2D.new()
	_visual.polygon = PackedVector2Array([
		Vector2(-28, -8), Vector2(28, -8), Vector2(20, 16), Vector2(-20, 16),
	])
	add_child(_visual)

	_label = Label.new()
	_label.add_theme_font_size_override("font_size", 15)
	_label.position = Vector2(-18, -42)
	add_child(_label)

	body_entered.connect(_on_body_entered)
	_refresh()


func _refresh() -> void:
	var c := Element.color_of(required)
	if _visual != null:
		_visual.color = Color(c.r, c.g, c.b, 0.95 if _used else 0.35)
	if _label != null:
		_label.text = "%s盆" % Element.name_of(required)
		_label.add_theme_color_override("font_color", c)


func _on_body_entered(body: Node2D) -> void:
	if _used or not body.is_in_group("player"):
		return
	if not body.has_method("has_element"):
		return
	if not body.has_element(required):
		# 手里没有对的东西：什么也不发生，玩家可以回去再拿
		return

	body.consume()
	_used = true
	Sfx.play_element_use()
	Events.element_used.emit(required)
	Events.button_pressed.emit(door_id)      # ← 复用原来的开门信号
	_refresh()


## 复活时火盆恢复成"没用过"：玩家要重新拿火来点
func reset_hazard() -> void:
	_used = false
	_refresh()
