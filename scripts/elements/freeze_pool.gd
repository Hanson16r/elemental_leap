extends Node2D
## 【水池 / 冰桥】—— 冰把水冻成桥，火把冰融回水
##
## 结构：
##   水池节点（Node2D，放在"桥面高度"）
##     ├─ 坑壁视觉（只有下沉水池才有：从桥面一路暗到水底）
##     ├─ 水面视觉（永远在，半透明蓝）
##     ├─ 冰平台（AnimatableBody2D，一开始隐藏 + 关碰撞）
##     │    ├─ CollisionShape2D（宽 × 20）
##     │    └─ Polygon2D（冰蓝色）
##     └─ 触发区（Area2D，检测玩家）
##
## 玩家走到水池边：
##   - 带着冰 → 冻结，冰平台出现，可以走过去
##   - 带着火（人泡在坑里时）→ 融冰（如果已经是冰）
##   - 什么都没有 → 什么也不发生，掉下去就回检查点
##
## 用法：关卡里 _add_freeze_pool(Vector2(x, y), 300)
##       其中 y 是"地面顶面"的高度，冰平台顶面会和它齐平。
##       下沉水池写法：_add_freeze_pool(pos, 240, 100, true)
##       → 水面比桥面低 100，没冻住掉进去直接死（第 9 关起点那个坑）。

## 水池宽度（也是冰桥宽度）
@export var width: float = 300.0
## 冰平台的厚度（视觉/碰撞）
@export var thickness: float = 20.0
## 水面比"桥面"低多少像素。
##   0  = 老用法：水面就在池子节点的高度，冻住后冰面和两侧齐平，也在水面高度
##   >0 = 下沉水池：水在坑里，冻住后冰桥浮到桥面高度，和两侧平台齐平
@export var water_drop: float = 0.0
## 没冻住时掉进水里算死（复位到检查点）。
## 老关卡的水池都靠下面的死亡区兜底，默认关掉，不改变既有手感。
@export var drowns: bool = false
## 水体深度（水面往下多少像素）。
## 水面位置 = 池子节点 y + water_drop，水底 = 水面 + water_depth。
## 想改"坑有多高"就调这个和 water_drop，两者之和别超过 210：
## 下层走廊的玩家头顶在平台顶面往下 42 像素处，水底再低就会把走下层的人一起淹了。
@export var water_depth: float = 90.0
## 触发区往上够多高（像素，0 = 用默认值）。
## 水面和桥面齐平、前面又隔着跳跃缺口时，玩家是"跳在半空"才碰到水面的，
## 这个值要比跳跃最高点还高，才能在落地前把水冻住。
@export var trigger_reach: float = 0.0

var _frozen: bool = false
var _water: Polygon2D
var _surface: Polygon2D
var _pit: Polygon2D
var _platform: AnimatableBody2D
var _platform_col: CollisionShape2D
var _ice: Polygon2D
var _trigger: Area2D
var _drown: Area2D
## 水面下沉量（_ready 里规整成 >= 0）
var _drop: float = 0.0


func _ready() -> void:
	var hw := width * 0.5
	_drop = maxf(water_drop, 0.0)
	var depth := maxf(water_depth, 20.0)
	var bottom := _drop + depth

	# ---- 下沉水池的坑：从桥面一路暗到水底，让人一眼看出这是个坑 ----
	if _drop > 0.0:
		_pit = Polygon2D.new()
		_pit.polygon = PackedVector2Array([
			Vector2(-hw, 0), Vector2(hw, 0), Vector2(hw, bottom), Vector2(-hw, bottom),
		])
		_pit.color = Color(0.10, 0.16, 0.26, 0.85)
		add_child(_pit)

	# ---- 水体：从水面往下 water_depth 像素 ----
	_water = Polygon2D.new()
	_water.polygon = PackedVector2Array([
		Vector2(-hw, _drop), Vector2(hw, _drop), Vector2(hw, bottom), Vector2(-hw, bottom),
	])
	_water.color = Color(0.25, 0.6, 1.0, 0.35)
	add_child(_water)

	# ---- 水面亮线 ----
	_surface = Polygon2D.new()
	_surface.polygon = PackedVector2Array([
		Vector2(-hw, _drop), Vector2(hw, _drop), Vector2(hw, _drop + 8), Vector2(-hw, _drop + 8),
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
	# 触发区：老水池 -30~90（站在岸边就能冻住，和以前完全一样）；
	# 下沉水池往上多伸到 -60，让玩家站在池边（脚就在桥面高度）拿着冰就能把水冻住，
	# 不用先跳出去赌一把 —— 这是"下沉水池"比老水池多出来的一步操作体验。
	var t_top := -60.0 if _drop > 0.0 else -30.0
	# 想让玩家"跳在半空就把水冻住"，就把触发区往上抬高
	t_top = minf(t_top, -trigger_reach)
	var t_bottom := 90.0
	_trigger = Area2D.new()
	_trigger.collision_layer = 0
	_trigger.collision_mask = 2
	_trigger.monitoring = true
	_trigger.position = Vector2(0, (t_top + t_bottom) * 0.5)
	var tshape := RectangleShape2D.new()
	tshape.size = Vector2(width, t_bottom - t_top)
	var tcol := CollisionShape2D.new()
	tcol.shape = tshape
	_trigger.add_child(tcol)
	_trigger.body_entered.connect(_on_body_entered)
	add_child(_trigger)

	# ---- 落水区（可选）：没冻住就死 ----
	if drowns:
		_drown = Area2D.new()
		_drown.collision_layer = 0
		_drown.collision_mask = 2
		_drown.monitoring = true
		_drown.position = Vector2(0, _drop + depth * 0.5)
		var dshape := RectangleShape2D.new()
		dshape.size = Vector2(width, depth)
		var dcol := CollisionShape2D.new()
		dcol.shape = dshape
		_drown.add_child(dcol)
		_drown.body_entered.connect(_on_drown_entered)
		add_child(_drown)


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
		# 下沉水池：只有人已经泡进坑里才算融冰。
		# 站在冰面上（脚在桥面高度）拿着火经过，不该把脚下的桥融掉。
		if _drop > 0.0 and body.global_position.y < global_position.y + _drop - 10.0:
			return
		body.consume()
		_set_frozen(false)
		Sfx.play_element_use()
		Events.element_used.emit(Element.Kind.FIRE)


## 落水：没冻住就复位（和掉进死亡区一样走 die() → 回检查点）
func _on_drown_entered(body: Node2D) -> void:
	if _frozen:
		return
	if not body.is_in_group("player"):
		return
	if body.has_method("die"):
		body.call("die")


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
