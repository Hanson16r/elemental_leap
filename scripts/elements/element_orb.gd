extends Area2D
## 【元素球】—— 地上捡的"火种 / 冰种 / 风种"
##
## 规则（对应你图里的想法）：玩家一次只能拿一个元素。
## 所以碰到的第一下会问玩家"你手空吗？"（player.pick_up 返回 true/false），
## 手空才拿走；手上有东西就站在原地，等玩家先用掉。
##
## 视觉全部用代码画：一个菱形 + 一个汉字，零图片素材。

@export var kind: int = Element.Kind.FIRE

var _taken: bool = false
var _visual: Polygon2D
var _label: Label


func _ready() -> void:
	# 图层 4 = pickup，掩码 = player（2），这样只检测玩家
	collision_layer = 8
	collision_mask = 2
	monitoring = true

	# 碰撞：一个半径 24 的圆，玩家走近就能捡
	var shape := CircleShape2D.new()
	shape.radius = 24.0
	var col := CollisionShape2D.new()
	col.shape = shape
	add_child(col)

	# 视觉：菱形
	_visual = Polygon2D.new()
	_visual.polygon = PackedVector2Array([
		Vector2(0, -16), Vector2(14, 0), Vector2(0, 16), Vector2(-14, 0),
	])
	add_child(_visual)

	# 文字：火 / 冰 / 风
	_label = Label.new()
	_label.add_theme_font_size_override("font_size", 15)
	_label.position = Vector2(-8, -34)
	add_child(_label)

	body_entered.connect(_on_body_entered)
	_refresh()


## 根据 kind 刷新颜色和文字（关卡如果中途改 kind，也可以再调一次）
func _refresh() -> void:
	var c := Element.color_of(kind)
	if _visual != null:
		_visual.color = c
	if _label != null:
		_label.text = Element.name_of(kind)
		_label.add_theme_color_override("font_color", c)


func _on_body_entered(body: Node2D) -> void:
	_try_pick(body)


## 每帧也检查一次"玩家是不是正站在元素球上"。
## 为什么需要：玩家死亡重生时，如果复活点正好压在元素球上，
## Area2D 不会重新发 body_entered，玩家就会"捡不起来"。
## 第 4 关之后的关卡反馈过这个问题，这里用 get_overlapping_bodies 兜底。
func _process(_delta: float) -> void:
	if _taken:
		return
	for b in get_overlapping_bodies():
		if _try_pick(b):
			break


func _try_pick(body: Node2D) -> bool:
	if _taken or not body.is_in_group("player"):
		return false
	if not body.has_method("pick_up"):
		return false
	if not body.pick_up(kind):
		return false
	_taken = true
	Sfx.play_pickup()
	Events.element_picked.emit(kind)
	hide()          # 不 queue_free：死亡重生时还要能刷出来
	return true


## 玩家死亡重生时，关卡会调用所有 reset_hazard()，把元素球放回去，
## 避免"捡了火种后摔死，火种没了，关卡卡死"。
func reset_hazard() -> void:
	_taken = false
	show()
	# 复活时把检测重新打开：即使玩家站在球上，_process 也会把它捡起来
	set_deferred("monitoring", true)
