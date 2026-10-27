extends Node2D
## 【水池 / 冰桥】—— 冰把水冻成桥，火把冰融回水
##
## 结构：
##   水池节点（Node2D，放在"地面高度"）
##     ├─ 水面视觉（永远在，半透明蓝）
##     ├─ 冰平台（AnimatableBody2D，一开始隐藏 + 关碰撞）
##     │    ├─ CollisionShape2D（宽 × 20）
##     │    └─ Polygon2D（冰蓝色）
##     └─ 触发区（Area2D，检测玩家）
##
## 玩家走到水池边：
##   - 带着冰 → 冻结，冰平台出现，可以走过去
##   - 带着火 → 融冰（如果已经是冰）
##   - 什么都没有 → 什么也不发生，掉下去就回检查点
##
## 用法：关卡里 _add_freeze_pool(Vector2(x, y), 300)
##       其中 y 是"地面顶面"的高度，冰平台顶面会和它齐平。

## 水池宽度（也是冰桥宽度）
@export var width: float = 300.0
## 冰平台的厚度（视觉/碰撞）
@export var thickness: float = 20.0

var _frozen: bool = false
var _water: Polygon2D
var _surface: Polygon2D
var _platform: AnimatableBody2D
var _platform_col: CollisionShape2D
var _ice: Polygon2D
var _trigger: Area2D


func _ready() -> void:
	var hw := width * 0.5

	# ---- 水体：从地面顶面往下 90 像素 ----
	_water = Polygon2D.new()
	_water.polygon = PackedVector2Array([
		Vector2(-hw, 0), Vector2(hw, 0), Vector2(hw, 90), Vector2(-hw, 90),
	])
	_water.color = Color(0.25, 0.6, 1.0, 0.35)
	add_child(_water)

	# ---- 水面亮线 ----
	_surface = Polygon2D.new()
	_surface.polygon = PackedVector2Array([
		Vector2(-hw, 0), Vector2(hw, 0), Vector2(hw, 8), Vector2(-hw, 8),
	])
	_surface.color = Color(0.55, 0.85, 1.0, 0.65)
	add_child(_surface)

	# ---- 冰平台：中心 y = thickness/2，这样顶面正好在 y=0 ----
	_platform = AnimatableBody2D.new()
	_platform.collision_layer = 1
	_platform.collision_mask = 0
	_platform.position = Vector2(0, thickness * 0.5)

	_platform_col = CollisionShape2D.new()
	var pshape := RectangleShape2D.new()
	pshape.size = Vector2(width, thickness)
	_platform_col.shape = pshape
	_platform.add_child(_platform_col)

	_ice = Polygon2D.new()
	_ice.polygon = PackedVector2Array([
		Vector2(-hw, -thickness * 0.5), Vector2(hw, -thickness * 0.5),
		Vector2(hw, thickness * 0.5), Vector2(-hw, thickness * 0.5),
	])
	_ice.color = Color(0.68, 0.94, 1.0, 0.95)
	_platform.add_child(_ice)

	add_child(_platform)
	_platform.visible = false
	_platform_col.set_deferred("disabled", true)

	# ---- 触发区：盖住整个水池 ----
	_trigger = Area2D.new()
	_trigger.collision_layer = 0
	_trigger.collision_mask = 2
	_trigger.monitoring = true
	_trigger.position = Vector2(0, 30)
	var tshape := RectangleShape2D.new()
	tshape.size = Vector2(width, 120)
	var tcol := CollisionShape2D.new()
	tcol.shape = tshape
	_trigger.add_child(tcol)
	_trigger.body_entered.connect(_on_body_entered)
	add_child(_trigger)


func _on_body_entered(body: Node2D) -> void:
	if not body.is_in_group("player"):
		return

	# 没冻住 + 手上有冰 → 冻成桥
	if not _frozen and body.has_element(Element.Kind.ICE):
		body.consume()
		_set_frozen(true)
		Sfx.play_element_use()
		Events.element_used.emit(Element.Kind.ICE)
		return

	# 已经冻住 + 手上有火 → 融回水
	if _frozen and body.has_element(Element.Kind.FIRE):
		body.consume()
		_set_frozen(false)
		Sfx.play_element_use()
		Events.element_used.emit(Element.Kind.FIRE)


func _set_frozen(v: bool) -> void:
	_frozen = v
	_platform.visible = v
	_platform_col.set_deferred("disabled", not v)
	_water.color = Color(0.6, 0.9, 1.0, 0.5) if v else Color(0.25, 0.6, 1.0, 0.35)
	_surface.color = Color(0.95, 1.0, 1.0, 0.9) if v else Color(0.55, 0.85, 1.0, 0.65)


## 玩家脚本会问它："这块冰滑不滑？"
## 冻住后是滑的：摩擦力只有 15%，会带着惯性滑出去。
func is_slippery() -> bool:
	return _frozen


## 复活时把冰桥恢复成水：玩家要重新拿冰再冻一次
func reset_hazard() -> void:
	_set_frozen(false)
