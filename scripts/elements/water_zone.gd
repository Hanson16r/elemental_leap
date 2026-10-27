extends Area2D
## 【水幕 / 水池】—— 走进去会浇灭手里的火
##
## 为什么只清"火"，不清冰和风？
## 照你图里的设定：水克制火，但水不克制冰（冰本来就是水变的）。
## 规则越干净，玩家越容易记住。
##
## 用法：关卡里 _add_water_zone(Vector2(x, y), Vector2(60, 160))

## 水幕的大小（宽, 高）
@export var size: Vector2 = Vector2(60, 160)

var _visual: Polygon2D
var _surface: Polygon2D


func _ready() -> void:
	collision_layer = 4          # hazard 层
	collision_mask = 2           # 只检测玩家
	monitoring = true

	var shape := RectangleShape2D.new()
	shape.size = size
	var col := CollisionShape2D.new()
	col.shape = shape
	add_child(col)

	var hw := size.x * 0.5
	var hh := size.y * 0.5

	# 水体：半透明蓝
	_visual = Polygon2D.new()
	_visual.polygon = PackedVector2Array([
		Vector2(-hw, -hh), Vector2(hw, -hh), Vector2(hw, hh), Vector2(-hw, hh),
	])
	_visual.color = Color(0.25, 0.6, 1.0, 0.35)
	add_child(_visual)

	# 水面：亮一点的一条线，让玩家一眼看出"这是水"
	_surface = Polygon2D.new()
	_surface.polygon = PackedVector2Array([
		Vector2(-hw, -hh), Vector2(hw, -hh), Vector2(hw, -hh + 8), Vector2(-hw, -hh + 8),
	])
	_surface.color = Color(0.55, 0.85, 1.0, 0.7)
	add_child(_surface)

	body_entered.connect(_on_body_entered)


func _on_body_entered(body: Node2D) -> void:
	if not body.is_in_group("player"):
		return
	if not body.has_element(Element.Kind.FIRE):
		return

	# 火被浇灭：清空手里，但**不**消耗元素球（球已经捡走了，靠 R 重开或死亡重置）
	body.clear_element()
	Sfx.play_element_clear()
	Events.element_cleared.emit(Element.Kind.FIRE)
