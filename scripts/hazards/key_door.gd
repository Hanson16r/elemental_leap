extends StaticBody2D
## 【钥匙门】—— 玩家带着钥匙走近就开；没有钥匙就挡住
##
## 和按钮门（door.gd）的区别：
##   · 按钮门靠 Events.button_pressed 开；
##   · 钥匙门靠 player.has_key 开，不需要按钮。
##
## 用法：关卡里 _add_key_door(Vector2(x, y), Vector2(40, 200))

@export var size: Vector2 = Vector2(40, 200)

var _open: bool = false
var _col: CollisionShape2D
var _visual: Polygon2D
var _hole: Polygon2D
var _trigger: Area2D


func _ready() -> void:
	collision_layer = 1
	collision_mask = 0

	var shape := RectangleShape2D.new()
	shape.size = size
	_col = CollisionShape2D.new()
	_col.shape = shape
	add_child(_col)

	var hw := size.x * 0.5
	var hh := size.y * 0.5
	_visual = Polygon2D.new()
	_visual.polygon = PackedVector2Array([
		Vector2(-hw, -hh), Vector2(hw, -hh), Vector2(hw, hh), Vector2(-hw, hh),
	])
	_visual.color = Color(0.28, 0.38, 0.55)
	add_child(_visual)

	# 钥匙孔
	_hole = Polygon2D.new()
	var pts := PackedVector2Array()
	for i in 12:
		var a := TAU * float(i) / 12.0
		pts.append(Vector2(cos(a), sin(a)) * 7.0 + Vector2(0, -hh * 0.25))
	_hole.polygon = pts
	_hole.color = Color(0.98, 0.82, 0.25, 0.85)
	add_child(_hole)

	# 触发区：门两边各宽 40
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
	if _open or not body.is_in_group("player"):
		return
	if not bool(body.get("has_key")):
		return
	_open_door()


func _open_door() -> void:
	_open = true
	_col.set_deferred("disabled", true)
	_trigger.set_deferred("monitoring", false)
	Sfx.play_click()

	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(_visual, "scale", Vector2(0.06, 1.0), 0.35)
	tw.tween_property(_hole, "modulate:a", 0.0, 0.2)


## 复活时门重新关上、钥匙孔恢复：玩家要重新去拿钥匙
func reset_hazard() -> void:
	_open = false
	_col.set_deferred("disabled", false)
	_trigger.set_deferred("monitoring", true)
	_visual.scale = Vector2.ONE
	_hole.modulate.a = 1.0
