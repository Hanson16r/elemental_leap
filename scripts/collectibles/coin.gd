extends Area2D
## 【金币】—— 收集品，不影响通关，只加分数
##
## 每关 5 枚：3 枚在主路，2 枚在支路/危险处。
## HUD 显示“金币 3/5”，通关界面显示本关金币数。
##
## ★ 复活规则（2026-10-27 改）★
##   以前复活时所有金币都回到地图上，HUD 也清零 —— 玩家过了检查点再死，
##   之前吃到的金币就白吃了。现在分两种：
##     · 检查点**之前**吃掉的：复活后保持消失，HUD 数量保留（算作已存档的成绩）；
##     · 检查点**之后**吃掉的：复活后重新出现在地图上（这段还没存档）。
##   关卡脚本（level_base.gd）会在检查点时把"已吃金币编号"存档，
##   复活时先 _reset_hazards() 让金币全部出现，再对这些编号调用 set_taken_state(true)。

## 关卡脚本在 _add_coin() 里分配的编号，用来做上面那套存档
@export var coin_id: int = -1

var _taken: bool = false
var _visual: Polygon2D
var _t: float = 0.0


func _ready() -> void:
	collision_layer = 8
	collision_mask = 2
	monitoring = true

	var shape := CircleShape2D.new()
	shape.radius = 18.0
	var col := CollisionShape2D.new()
	col.shape = shape
	add_child(col)

	# 圆形金币（用 16 边形近似）
	_visual = Polygon2D.new()
	var pts := PackedVector2Array()
	for i in 16:
		var a := TAU * float(i) / 16.0
		pts.append(Vector2(cos(a), sin(a)) * 12.0)
	_visual.polygon = pts
	_visual.color = Color(1.0, 0.82, 0.28)
	add_child(_visual)

	var inner := Polygon2D.new()
	var pts2 := PackedVector2Array()
	for i in 16:
		var a := TAU * float(i) / 16.0
		pts2.append(Vector2(cos(a), sin(a)) * 7.0)
	inner.polygon = pts2
	inner.color = Color(1.0, 0.93, 0.6)
	add_child(inner)

	body_entered.connect(_on_body_entered)


func _process(delta: float) -> void:
	# 上下浮动，让金币显眼
	_t += delta
	_visual.position.y = sin(_t * 3.0) * 4.0


func _on_body_entered(body: Node2D) -> void:
	if _taken or not body.is_in_group("player"):
		return
	_taken = true
	GameState.add_coin()
	Sfx.play_pickup()
	hide()
	set_deferred("monitoring", false)


## 这枚金币现在是不是已经被吃掉了？（关卡脚本存检查点时用）
func is_taken() -> bool:
	return _taken


## 直接设定"已吃 / 未吃"，不加分、不播音效。
## 复活时关卡脚本用它把"检查点之前吃掉的"金币重新藏起来。
func set_taken_state(taken: bool) -> void:
	_taken = taken
	if taken:
		hide()
		set_deferred("monitoring", false)
	else:
		show()
		set_deferred("monitoring", true)


## 玩家死亡重生时，金币回到"地图上有"的状态。
## 注意：检查点之前已经吃掉的那些，关卡脚本随后会再调 set_taken_state(true) 藏掉。
func reset_hazard() -> void:
	set_taken_state(false)
