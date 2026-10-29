extends "res://scripts/enemies/walker.gd"
## 【水史莱姆】—— 普通史莱姆的水形态（第 9 关「分岔」新增）
##
## 平时和普通史莱姆一样左右巡逻、踩上去会压扁、横向撞到会撞死人。
## 区别只有一个：只有"冰霜地带正在有效"的时候走进区域，才会被冻住：
##   · 冻住 2.5 秒：停下不动、不再攻击玩家、变成有棱角的冰晶形态；
##   · 碰撞保留：冻住期间它是实心的，玩家不能直接穿过去；
##   · 冻满时间自动恢复水态；就算冰霜地带提前结束，它也会把剩下时间走完；
##   · 地带消失以后再走进来不会触发（它自己每帧查"区域是否仍然有效"）。

## 被冻住的时长（秒）
@export var freeze_time: float = 2.5

var _frozen_left: float = 0.0
var _frozen_monitoring_off: bool = false
var _crystal: Polygon2D
var _solid: StaticBody2D


func _ready() -> void:
	super()
	_build_crystal()
	_build_solid()


func _process(delta: float) -> void:
	if _frozen_left > 0.0:
		_frozen_left -= delta
		if _frozen_left <= 0.0:
			# 区域还罩着它：继续冻着，不闪回水态（否则会"解冻一帧又冻上"）
			if _in_active_zone():
				_frozen_left = freeze_time
			else:
				_thaw()
		return

	# 解冻后玩家还站在身上时先不恢复攻击区，免得一解冻就把人撞死
	if _frozen_monitoring_off and not _player_near():
		_frozen_monitoring_off = false
		monitoring = true

	if not _squished and _in_active_zone():
		_freeze()
		return
	super(delta)


## 是不是正站在"正在有效"的冰霜地带里
func _in_active_zone() -> bool:
	for node in get_tree().get_nodes_in_group("frost_zone"):
		var zone := node as Node2D
		if zone == null or not zone.has_method("is_active"):
			continue
		if not bool(zone.call("is_active")):
			continue
		# 只认脚下这一层的地带（上层桥面不算）
		if absf(float(zone.call("floor_y")) - global_position.y) > 60.0:
			continue
		# 判定比冰面视觉宽 36 像素：让它"踩进冰面边缘之前"就冻住。
		# 否则玩家站在地带边线上时，史莱姆正好在它被冻住的那一帧撞到人，
		# 先判死亡再判冻结，玩家会觉得"明明该冻住却被撞死"。
		var half_width: float = float(zone.get("width")) * 0.5
		var dx: float = global_position.x - zone.global_position.x
		if absf(dx) <= half_width + 36.0:
			return true
	return false


func _freeze() -> void:
	_frozen_left = freeze_time
	_rotation_visual_off()
	_crystal.visible = true
	_crystal.scale = Vector2(0.4, 0.4)
	var tw := create_tween()
	tw.tween_property(_crystal, "scale", Vector2.ONE, 0.16)
	_solid.set_deferred("collision_layer", 1)
	_frozen_monitoring_off = true
	set_deferred("monitoring", false)


func _thaw() -> void:
	_frozen_left = 0.0
	_crystal.visible = false
	_sprite.show()
	_sprite.rotation = 0.0
	_solid.set_deferred("collision_layer", 0)


func _rotation_visual_off() -> void:
	# 冻住时不再摆头晃身，直接藏起水流身体、只留冰晶
	_sprite.rotation = 0.0
	_sprite.hide()


func _build_crystal() -> void:
	_crystal = Polygon2D.new()
	_crystal.polygon = PackedVector2Array([
		Vector2(0, -30), Vector2(15, -12), Vector2(12, 10),
		Vector2(0, 22), Vector2(-12, 10), Vector2(-15, -12),
	])
	_crystal.color = Color(0.72, 0.92, 1.0, 0.92)
	_crystal.position = Vector2(0, -6)
	_crystal.visible = false
	add_child(_crystal)

	var facet := Polygon2D.new()
	facet.polygon = PackedVector2Array([
		Vector2(0, -30), Vector2(6, -10), Vector2(0, 8), Vector2(-6, -10),
	])
	facet.color = Color(0.95, 0.99, 1.0, 0.85)
	_crystal.add_child(facet)


func _build_solid() -> void:
	# 平时 collision_layer = 0（不挡路）；冻住时改成 1，玩家就撞得上去
	_solid = StaticBody2D.new()
	_solid.collision_layer = 0
	_solid.collision_mask = 0
	var shape := RectangleShape2D.new()
	shape.size = Vector2(26, 34)
	var col := CollisionShape2D.new()
	col.shape = shape
	col.position = Vector2(0, -4)
	_solid.add_child(col)
	add_child(_solid)


func reset_hazard() -> void:
	if _frozen_left > 0.0:
		_thaw()
	if _frozen_monitoring_off:
		_frozen_monitoring_off = false
		monitoring = true
	super()
