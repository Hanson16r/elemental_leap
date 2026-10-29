extends StaticBody2D
## 【周期风门】—— 方向二：纯时机型机关（不改怪物 AI）
##
## 规则：风带每 period 秒吹 blow_time 秒；**只在吹的时候门开**，其余时间门是实心墙。
## 玩家要站在风带里等，看到风带箭头动起来再冲过去。
##
## 结构（都在本节点下，坐标相对门中心）：
##   · 门：StaticBody2D 本体 + 矩形碰撞 + 门板（开门时往上缩、变半透明）
##   · 风带：门左边紧贴的一块 Area2D（只检测玩家），吹的时候给一次水平加速
##   · 指示灯：关=红，开=绿
##
## 用法：_add_wind_gate(Vector2(1320, 830)) → 门 1300~1340，风带 1200~1300（尺寸 40×100 / 100×100）

@export var door_size: Vector2 = Vector2(40, 100)
@export var belt_size: Vector2 = Vector2(100, 100)
## 一个完整周期（秒）
@export var period: float = 6.0
## 每个周期里"吹"的时长（秒）
@export var blow_time: float = 3.0
## 相位（0~1 个周期），用来和别的节奏错开
@export var phase: float = 0.0
## 吹风时给玩家的水平加速（和风区同一套 apply_wind）
@export var boost_speed: float = 380.0
@export var boost_time: float = 0.6

var _t: float = 0.0
var _blowing: bool = false
var _player_inside: bool = false
var _col: CollisionShape2D
var _door: Polygon2D
var _lamp: Polygon2D
var _belt_band: Polygon2D
var _belt_x: float = 0.0
var _arrows: Array[Polygon2D] = []
var _tween: Tween = null


func _ready() -> void:
	collision_layer = 1
	collision_mask = 0

	var hw := door_size.x * 0.5
	var hh := door_size.y * 0.5

	var shape := RectangleShape2D.new()
	shape.size = door_size
	_col = CollisionShape2D.new()
	_col.shape = shape
	add_child(_col)

	# 门板：深灰蓝 + 三条横梁
	_door = Polygon2D.new()
	_door.polygon = _rect(-hw, -hh, hw, hh)
	_door.color = Color(0.30, 0.34, 0.46)
	add_child(_door)
	for i in 3:
		var slat := Polygon2D.new()
		var y0 := -hh + 12.0 + 26.0 * float(i)
		slat.polygon = _rect(-hw + 5.0, y0, hw - 5.0, y0 + 10.0)
		slat.color = Color(0.14, 0.16, 0.22)
		_door.add_child(slat)

	# 指示灯：关=红，开=绿
	_lamp = Polygon2D.new()
	var pts := PackedVector2Array()
	for i in 10:
		var a := TAU * float(i) / 10.0
		pts.append(Vector2(cos(a), sin(a)) * 5.0)
	_lamp.polygon = pts
	_lamp.position = Vector2(0, -hh - 12.0)
	_lamp.color = Color(1.0, 0.35, 0.3)
	add_child(_lamp)

	# 风带：紧贴门的左边
	var bhw := belt_size.x * 0.5
	var bhh := belt_size.y * 0.5
	_belt_x = -(hw + bhw)
	_belt_band = Polygon2D.new()
	_belt_band.polygon = _rect(-bhw, -bhh, bhw, bhh)
	_belt_band.position = Vector2(_belt_x, 0.0)
	_belt_band.color = Color(0.55, 1.0, 0.75, 0.06)
	add_child(_belt_band)

	for i in 3:
		var arrow := Polygon2D.new()
		arrow.polygon = PackedVector2Array([
			Vector2(-13, -8), Vector2(7, 0), Vector2(-13, 8),
		])
		arrow.position = Vector2(_belt_x, -bhh * 0.42 + bhh * 0.42 * float(i))
		arrow.color = Color(0.65, 1.0, 0.82, 0.5)
		add_child(arrow)
		_arrows.append(arrow)

	# 风带检测区：只检测玩家
	var belt := Area2D.new()
	belt.collision_layer = 0
	belt.collision_mask = 2
	belt.monitoring = true
	belt.position = Vector2(_belt_x, 0.0)
	var bshape := RectangleShape2D.new()
	bshape.size = belt_size
	var bcol := CollisionShape2D.new()
	bcol.shape = bshape
	belt.add_child(bcol)
	belt.body_entered.connect(_on_belt_entered)
	belt.body_exited.connect(_on_belt_exited)
	add_child(belt)

	_t = fmod(phase * period, period)
	_set_blowing(_t < blow_time)


func _process(delta: float) -> void:
	_t = fmod(_t + delta, period)
	var blowing := _t < blow_time
	if blowing != _blowing:
		_set_blowing(blowing)

	# 风带动画：吹的时候箭头往右跑，不吹的时候只剩一层很淡的底色
	if _blowing:
		var shift := fmod(_t * 150.0, 52.0)
		for i in _arrows.size():
			_arrows[i].position.x = _belt_x + shift - 26.0
			_arrows[i].modulate.a = 0.55 + 0.35 * sin(_t * 12.0 + float(i))
	else:
		for i in _arrows.size():
			_arrows[i].position.x = _belt_x
			_arrows[i].modulate.a = 0.22


func _set_blowing(v: bool) -> void:
	_blowing = v
	if v:
		_col.set_deferred("disabled", true)
		_lamp.color = Color(0.35, 1.0, 0.5)
		_belt_band.color.a = 0.18
		_door_tween(true, 0.28)
		# 风刚起来时玩家如果已经站在风带里，也补一次加速
		if _player_inside:
			_boost_player()
	else:
		_col.set_deferred("disabled", false)
		_lamp.color = Color(1.0, 0.35, 0.3)
		_belt_band.color.a = 0.09
		_door_tween(false, 0.22)


## 开门 = 门板横向缩进门框（和钥匙门同一种"打开"语言），关门 = 恢复原宽
func _door_tween(open: bool, time: float) -> void:
	if _tween != null and _tween.is_valid():
		_tween.kill()
	_tween = create_tween()
	_tween.set_parallel(true)
	_tween.tween_property(_door, "scale", Vector2(0.06, 1.0) if open else Vector2.ONE, time)
	_tween.tween_property(_door, "modulate:a", 0.45 if open else 1.0, time)


func _on_belt_entered(body: Node2D) -> void:
	if not body.is_in_group("player"):
		return
	_player_inside = true
	if _blowing:
		_boost_player()


func _on_belt_exited(body: Node2D) -> void:
	if not body.is_in_group("player"):
		return
	_player_inside = false


func _boost_player() -> void:
	var p := get_tree().get_first_node_in_group("player")
	if p != null and p.has_method("apply_wind"):
		p.apply_wind(boost_speed, boost_time)


## 复活时回到周期的起点：门先关着，等下一轮风
func reset_hazard() -> void:
	_player_inside = false
	_t = fmod(phase * period, period)
	_set_blowing(_t < blow_time)


func _rect(x0: float, y0: float, x1: float, y1: float) -> PackedVector2Array:
	return PackedVector2Array([
		Vector2(x0, y0), Vector2(x1, y0), Vector2(x1, y1), Vector2(x0, y1),
	])
