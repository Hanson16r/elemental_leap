extends Area2D
## 【钥匙】—— 一次性拾取，不进元素槽（可以同时拿钥匙 + 一个元素）
##
## 拿到后 player.has_key = true，HUD 显示钥匙图标；
## 钥匙门（key_door.gd）检测到这个标志才会开。
##
## 用法：关卡里 _add_key(Vector2(x, y))

var _taken: bool = false
var _visual: Node2D
var _t: float = 0.0


func _ready() -> void:
	collision_layer = 8
	collision_mask = 2
	monitoring = true

	var shape := CircleShape2D.new()
	shape.radius = 22.0
	var col := CollisionShape2D.new()
	col.shape = shape
	add_child(col)

	_visual = Node2D.new()
	add_child(_visual)

	# 钥匙：一个环 + 一根杆 + 两个齿
	var ring := Polygon2D.new()
	var pts := PackedVector2Array()
	for i in 16:
		var a := TAU * float(i) / 16.0
		pts.append(Vector2(cos(a), sin(a)) * 9.0 + Vector2(0, -12))
	ring.polygon = pts
	ring.color = Color(0.98, 0.82, 0.25)
	_visual.add_child(ring)

	var hole := Polygon2D.new()
	var pts2 := PackedVector2Array()
	for i in 16:
		var a := TAU * float(i) / 16.0
		pts2.append(Vector2(cos(a), sin(a)) * 4.0 + Vector2(0, -12))
	hole.polygon = pts2
	hole.color = Color(0.07, 0.1, 0.16)
	_visual.add_child(hole)

	var shaft := Polygon2D.new()
	shaft.polygon = PackedVector2Array([
		Vector2(-3, -3), Vector2(3, -3), Vector2(3, 18), Vector2(-3, 18),
	])
	shaft.color = Color(0.98, 0.82, 0.25)
	_visual.add_child(shaft)

	var tooth1 := Polygon2D.new()
	tooth1.polygon = PackedVector2Array([
		Vector2(3, 8), Vector2(10, 8), Vector2(10, 12), Vector2(3, 12),
	])
	tooth1.color = Color(0.98, 0.82, 0.25)
	_visual.add_child(tooth1)

	var tooth2 := Polygon2D.new()
	tooth2.polygon = PackedVector2Array([
		Vector2(3, 13), Vector2(8, 13), Vector2(8, 17), Vector2(3, 17),
	])
	tooth2.color = Color(0.98, 0.82, 0.25)
	_visual.add_child(tooth2)

	body_entered.connect(_on_body_entered)


func _process(delta: float) -> void:
	_t += delta
	_visual.position.y = sin(_t * 2.5) * 4.0
	if _taken:
		return
	# 和元素球一样：玩家重生时可能正站在钥匙上，用重叠检测兜底
	for b in get_overlapping_bodies():
		if _try_pick(b):
			break


func _on_body_entered(body: Node2D) -> void:
	_try_pick(body)


func _try_pick(body: Node2D) -> bool:
	if _taken or not body.is_in_group("player"):
		return false
	_taken = true
	body.has_key = true
	Events.key_collected.emit()
	Sfx.play_pickup()
	hide()
	set_deferred("monitoring", false)
	return true


func reset_hazard() -> void:
	_taken = false
	show()
	set_deferred("monitoring", true)
