extends StaticBody2D
## 【岩石墙】—— 只有岩石元素能砸开
##
## 和冰墙（ice_barrier.gd）是同一个套路，只是：
##   · 需要的元素换成 ROCK
##   · 视觉换成深灰/棕色 + 裂纹
## 为什么单独写一个而不是给冰墙加参数？
## 因为新手看代码时，"冰墙"和"岩石墙"分开更好懂；等熟练了再合并。
##
## 用法：关卡里 _add_rock_wall(Vector2(x, y), Vector2(40, 160))

## 岩石墙大小（宽, 高）
@export var size: Vector2 = Vector2(40, 160)
## 需要哪种元素（默认岩石）
@export var required: int = Element.Kind.ROCK

var _broken: bool = false
var _visual: Polygon2D
var _cap: Polygon2D
var _trigger: Area2D
var _col: CollisionShape2D


func _ready() -> void:
	collision_layer = 1          # world：玩家会撞上
	collision_mask = 0

	var shape := RectangleShape2D.new()
	shape.size = size
	_col = CollisionShape2D.new()
	_col.shape = shape
	add_child(_col)

	var hw := size.x * 0.5
	var hh := size.y * 0.5

	# 石体：深灰棕
	_visual = Polygon2D.new()
	_visual.polygon = PackedVector2Array([
		Vector2(-hw, -hh), Vector2(hw, -hh), Vector2(hw, hh), Vector2(-hw, hh),
	])
	_visual.color = Color(0.42, 0.38, 0.34, 0.95)
	add_child(_visual)

	# 顶部亮一点的石帽
	_cap = Polygon2D.new()
	_cap.polygon = PackedVector2Array([
		Vector2(-hw, -hh), Vector2(hw, -hh), Vector2(hw, -hh + 10), Vector2(-hw, -hh + 10),
	])
	_cap.color = Color(0.62, 0.56, 0.48, 0.95)
	add_child(_cap)

	# 裂纹：两条细线
	for i in 2:
		var crack := Polygon2D.new()
		var cx := -hw * 0.35 + hw * 0.7 * float(i)
		crack.polygon = PackedVector2Array([
			Vector2(cx - 2, -hh + 22), Vector2(cx + 2, -hh + 22),
			Vector2(cx + 12, hh - 18), Vector2(cx + 8, hh - 18),
		])
		crack.color = Color(0.18, 0.15, 0.13, 0.8)
		add_child(crack)

	# 触发区：比墙宽 80，玩家走近就检测
	_trigger = Area2D.new()
	_trigger.collision_layer = 0
	_trigger.collision_mask = 2
	_trigger.monitoring = true
	var tshape := RectangleShape2D.new()
	tshape.size = size + Vector2(80.0, 0.0)
	var tcol := CollisionShape2D.new()
	tcol.shape = tshape
	_trigger.add_child(tcol)
	_trigger.body_entered.connect(_on_body_entered)
	add_child(_trigger)


func _on_body_entered(body: Node2D) -> void:
	if _broken or not body.is_in_group("player"):
		return
	if not body.has_element(required):
		return

	body.consume()
	_break()


func _break() -> void:
	_broken = true
	Sfx.play_element_use()
	Events.element_used.emit(required)

	_col.set_deferred("disabled", true)
	_trigger.set_deferred("monitoring", false)

	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(_visual, "modulate:a", 0.0, 0.35)
	tw.tween_property(_cap, "modulate:a", 0.0, 0.35)
	tw.tween_property(_visual, "scale", Vector2(1.0, 0.15), 0.35)
	tw.tween_property(_cap, "scale", Vector2(1.0, 0.15), 0.35)


## 复活时把石墙恢复：玩家要重新拿岩石来砸
func reset_hazard() -> void:
	_broken = false
	_col.set_deferred("disabled", false)
	_trigger.set_deferred("monitoring", true)
	_visual.modulate.a = 1.0
	_cap.modulate.a = 1.0
	_visual.scale = Vector2.ONE
	_cap.scale = Vector2.ONE
