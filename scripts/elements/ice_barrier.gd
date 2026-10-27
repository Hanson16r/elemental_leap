extends StaticBody2D
## 【冰墙 / 冰障碍】—— 只有火能融掉
##
## 实现分两层：
##   1. StaticBody2D 本体：真的挡住玩家（碰撞层 1 = world）
##   2. 前面一块更大的 Area2D 触发区：玩家**还没撞上墙**就检测到手上有火，
##      于是"用火融墙"，而不是"撞墙之后才反应过来"
##
## 用法：关卡里 _add_ice_barrier(Vector2(x, y), Vector2(40, 160))

## 冰墙大小（宽, 高）
@export var size: Vector2 = Vector2(40, 160)
## 需要哪种元素才能融（默认火）
@export var required: int = Element.Kind.FIRE

var _melted: bool = false
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

	# 冰体：半透明冰蓝
	_visual = Polygon2D.new()
	_visual.polygon = PackedVector2Array([
		Vector2(-hw, -hh), Vector2(hw, -hh), Vector2(hw, hh), Vector2(-hw, hh),
	])
	_visual.color = Color(0.62, 0.9, 1.0, 0.85)
	add_child(_visual)

	# 顶部一条亮色，像积雪/冰棱
	_cap = Polygon2D.new()
	_cap.polygon = PackedVector2Array([
		Vector2(-hw, -hh), Vector2(hw, -hh), Vector2(hw, -hh + 10), Vector2(-hw, -hh + 10),
	])
	_cap.color = Color(0.95, 1.0, 1.0, 0.95)
	add_child(_cap)

	# 触发区：比墙宽 80 像素，玩家走近就检测
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
	if _melted or not body.is_in_group("player"):
		return
	if not body.has_element(required):
		return

	body.consume()
	_melt()


func _melt() -> void:
	_melted = true
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


## 复活时把冰墙恢复：玩家要重新拿火来融
func reset_hazard() -> void:
	_melted = false
	_col.set_deferred("disabled", false)
	_trigger.set_deferred("monitoring", true)
	_visual.modulate.a = 1.0
	_cap.modulate.a = 1.0
	_visual.scale = Vector2.ONE
	_cap.scale = Vector2.ONE
