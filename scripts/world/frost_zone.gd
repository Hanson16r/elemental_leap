extends Node2D
## 【冰霜地带】—— 玩家经过时激活的短暂冰霜区域（第 3 关「分岔」新增）
##
## 规则（对应设计表「重点机制：冰霜区域如何工作」）：
##   · 状态 A（未激活）：地面有淡蓝色纹路 / 冰晶标记，水史莱姆正常巡逻；
##   · 状态 B（玩家经过）：玩家第一次踏进区域时，冰霜从脚底往两侧扩散，持续 2 秒（active_time），
##     区域内的地面变成明显的浅蓝冰面；只影响这一个区域，不冻结别处的敌人；
##   · 状态 C（水史莱姆进入有效区域）：立刻冻住 2.5 秒，停止移动和攻击、变成冰晶形态，
##     碰撞保留（不能直接穿过）；冻满时间自动恢复，即使区域提前结束也把剩余时间走完；
##   · 区域消失后再进入的水史莱姆不会被冻（水史莱姆自己按"区域是否仍然有效"判断）；
##   · 触发有 1 秒冷却，防止玩家站在边界反复刷新效果；
##   · 不需要额外按键：走过去就算触发。
##
## 本节点只负责"区域本身"（触发、计时、地面视觉）；冻结水史莱姆由
## scripts/enemies/water_slime.gd 自己每帧查询区域状态完成（只有区域有效时才冻）。

## 区域宽度（像素）
@export var width: float = 140.0
## 一次激活持续多久（秒）
@export var active_time: float = 2.0
## 两次触发之间的冷却（秒）
@export var cooldown: float = 1.0
## 触发区高度（像素）：以地面为底往上这么高
@export var trigger_height: float = 90.0

## 区域刚被激活时发出（调试用）
signal activated

var _active: bool = false
var _left: float = 0.0
var _cooldown_left: float = 0.0

var _trigger: Area2D
## 地面常态的淡蓝纹路
var _tracks: Polygon2D
## 激活后亮起来的冰面，包在一个 Node2D 里方便从脚底往外扩
var _ice: Node2D
var _ice_poly: Polygon2D
var _ice_core: Polygon2D


func _ready() -> void:
	add_to_group("frost_zone")
	_build_visuals()
	_build_trigger()


func _process(delta: float) -> void:
	if _active:
		_left -= delta
		if _left <= 0.0:
			_deactivate()
		return
	if _cooldown_left > 0.0:
		_cooldown_left -= delta
		return
	var body := _player_inside()
	if body != null:
		_activate(body)


## 区域此刻是否有效（水史莱姆靠这个判断能不能冻）
func is_active() -> bool:
	return _active


## 某个世界坐标 x 是否落在区域范围内
func contains_x(world_x: float) -> bool:
	return absf(world_x - global_position.x) <= width * 0.5


## 地面在世界坐标里的 y（水史莱姆用它判断"我们是不是同一层"）
func floor_y() -> float:
	return global_position.y


# ===================================================================== 内部

func _build_visuals() -> void:
	var hw := width * 0.5

	# 常态：贴着地面的一条淡蓝纹路 + 几道竖向冰晶
	_tracks = Polygon2D.new()
	_tracks.polygon = PackedVector2Array([
		Vector2(-hw, 1), Vector2(hw, 1), Vector2(hw, 7), Vector2(-hw, 7),
	])
	_tracks.color = Color(0.58, 0.82, 1.0, 0.20)
	add_child(_tracks)

	var marks := Line2D.new()
	marks.width = 1.5
	marks.default_color = Color(0.70, 0.90, 1.0, 0.35)
	marks.closed = false
	marks.points = PackedVector2Array([
		Vector2(-hw * 0.55, 2), Vector2(-hw * 0.35, -6), Vector2(-hw * 0.15, 2),
	])
	add_child(marks)

	# 激活后的冰面：从脚底往两侧扩，所以放在一个可缩放的空节点里
	_ice = Node2D.new()
	_ice.modulate = Color(1, 1, 1, 0)   # 用 modulate.a 淡入淡出
	_ice.scale = Vector2(0.08, 1.0)
	add_child(_ice)

	_ice_poly = Polygon2D.new()
	_ice_poly.polygon = PackedVector2Array([
		Vector2(-hw, 0), Vector2(hw, 0), Vector2(hw, 10), Vector2(-hw, 10),
	])
	_ice_poly.color = Color(0.72, 0.91, 1.0, 0.55)
	_ice.add_child(_ice_poly)

	_ice_core = Polygon2D.new()
	_ice_core.polygon = PackedVector2Array([
		Vector2(-hw * 0.8, 1), Vector2(hw * 0.8, 1), Vector2(hw * 0.8, 4), Vector2(-hw * 0.8, 4),
	])
	_ice_core.color = Color(0.95, 0.99, 1.0, 0.80)
	_ice.add_child(_ice_core)


func _build_trigger() -> void:
	_trigger = Area2D.new()
	_trigger.collision_layer = 0
	_trigger.collision_mask = 2   # 只关心玩家（第 2 层）
	_trigger.monitoring = true
	_trigger.position = Vector2(0, -trigger_height * 0.5)
	var shape := RectangleShape2D.new()
	shape.size = Vector2(width, trigger_height)
	var col := CollisionShape2D.new()
	col.shape = shape
	_trigger.add_child(col)
	add_child(_trigger)


## 触发区里有没有玩家（返回第一个）
func _player_inside() -> Node2D:
	for body in _trigger.get_overlapping_bodies():
		if body.is_in_group("player"):
			return body as Node2D
	return null


func _activate(body: Node2D) -> void:
	_active = true
	_left = active_time

	# 冰霜从玩家脚底往两侧扩散：把冰面搬到他脚下，再从 8% 拉到 100%
	var origin_x := clampf(body.global_position.x - global_position.x, -width * 0.5, width * 0.5)
	_ice.position = Vector2(origin_x, 0.0)
	_ice.scale = Vector2(0.08, 1.0)
	var tw := create_tween()
	tw.tween_property(_ice, "modulate:a", 1.0, 0.22)
	tw.parallel().tween_property(_ice, "scale:x", 1.0, 0.30)
	activated.emit()


func _deactivate() -> void:
	_active = false
	_left = 0.0
	_cooldown_left = cooldown
	var tw := create_tween()
	tw.tween_property(_ice, "modulate:a", 0.0, 0.18)
