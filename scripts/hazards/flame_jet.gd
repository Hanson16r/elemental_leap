extends Area2D
## 【间歇火焰喷口】—— 周期性喷火：灭 1.5 秒 → 预警 0.4 秒 → 着火 1 秒
##
## 和普通火焰的区别：
##   · 普通火焰一直在，只放在坑底（掉下去才死）；
##   · 这个喷口在可走地面/天花板上，玩家要**读节奏**，趁灭的时候过。
##
## 视觉上做了三件事，让玩家一眼看出"这是个喷口"：
##   1. 深色金属格栅（三条缝）；
##   2. 一盏小警示灯：灭=灰，预警=红闪，着火=橙亮；
##   3. 着火时火焰会左右抖动。
##
## 用法：
##   _add_flame_jet(Vector2(x, y), true, 0.0, 60.0)   # 地火，短火焰，可跳过
##   _add_flame_jet(Vector2(x, y), false, 0.5, 145.0) # 天火，长火焰

## true = 地火（向上喷）；false = 天火（向下喷）
@export var up: bool = true
## 火焰长度
@export var length: float = 110.0
## 火焰宽度
@export var width: float = 26.0
## 灭的时间
@export var off_time: float = 1.5
## 预警时间（喷口灯变红，但还没火）
@export var warn_time: float = 0.4
## 着火时间
@export var on_time: float = 1.0
## 相位（0~1 个周期），用来错开多个喷口
@export var phase: float = 0.0

var _t: float = 0.0
var _shape: CollisionShape2D
var _flame: Polygon2D
var _core: Polygon2D
var _lamp: Polygon2D
var _particles: CPUParticles2D
var _burning: bool = false


func _ready() -> void:
	collision_layer = 4
	collision_mask = 2
	monitoring = false

	var dir := -1.0 if up else 1.0

	# 深色金属格栅
	var grate := Polygon2D.new()
	grate.polygon = PackedVector2Array([
		Vector2(-18, -6), Vector2(18, -6), Vector2(14, 8), Vector2(-14, 8),
	])
	grate.color = Color(0.22, 0.24, 0.28)
	add_child(grate)
	for i in 3:
		var slat := Polygon2D.new()
		var x := -10.0 + 10.0 * float(i)
		slat.polygon = PackedVector2Array([
			Vector2(x - 2, -5), Vector2(x + 2, -5), Vector2(x + 2, 6), Vector2(x - 2, 6),
		])
		slat.color = Color(0.08, 0.09, 0.11)
		add_child(slat)

	# 警示灯：灭=灰，预警=红闪，着火=橙亮
	_lamp = Polygon2D.new()
	var pts := PackedVector2Array()
	for i in 10:
		var a := TAU * float(i) / 10.0
		pts.append(Vector2(cos(a), sin(a)) * 4.0)
	_lamp.polygon = pts
	_lamp.position = Vector2(0, 12)
	_lamp.color = Color(0.35, 0.35, 0.4)
	add_child(_lamp)

	# 火焰柱（从喷口往外长）
	_flame = Polygon2D.new()
	_flame.polygon = PackedVector2Array([
		Vector2(-width * 0.5, 0),
		Vector2(-width * 0.18, dir * length),
		Vector2(width * 0.18, dir * length),
		Vector2(width * 0.5, 0),
	])
	_flame.color = Color(1.0, 0.45, 0.2, 0.85)
	_flame.visible = false
	add_child(_flame)

	_core = Polygon2D.new()
	_core.polygon = PackedVector2Array([
		Vector2(-width * 0.22, 0),
		Vector2(0, dir * length * 0.88),
		Vector2(width * 0.22, 0),
	])
	_core.color = Color(1.0, 0.85, 0.35, 0.95)
	_core.visible = false
	add_child(_core)

	# 粒子火舌：比纯多边形更像火
	_particles = CPUParticles2D.new()
	_particles.amount = 28
	_particles.lifetime = 0.45
	_particles.direction = Vector2(0, dir)
	_particles.spread = 10.0
	_particles.initial_velocity_min = 100.0
	_particles.initial_velocity_max = 220.0
	_particles.gravity = Vector2(0, dir * 260.0)
	_particles.scale_amount_min = 2.0
	_particles.scale_amount_max = 4.5
	_particles.color = Color(1.0, 0.55, 0.2, 0.75)
	_particles.emitting = false
	add_child(_particles)

	# 碰撞：一条和火焰一样长的窄矩形
	var rect := RectangleShape2D.new()
	rect.size = Vector2(width, length)
	_shape = CollisionShape2D.new()
	_shape.shape = rect
	_shape.position = Vector2(0, dir * length * 0.5)
	_shape.disabled = true
	add_child(_shape)

	body_entered.connect(_on_body_entered)

	var cycle := off_time + warn_time + on_time
	_t = fmod(phase * cycle, cycle)
	_update_state()


func _process(delta: float) -> void:
	var cycle := off_time + warn_time + on_time
	_t = fmod(_t + delta, cycle)
	_update_state()

	# 着火时火焰左右抖，预警时灯闪
	if _burning:
		_flame.scale.x = 1.0 + sin(_t * 38.0) * 0.10
		_core.scale.x = 1.0 + sin(_t * 46.0) * 0.14
	elif _t >= off_time and _t < off_time + warn_time:
		var blink := 0.55 + 0.45 * sin(_t * 60.0)
		_lamp.modulate.a = blink
	else:
		_lamp.modulate.a = 1.0


func _update_state() -> void:
	var t := _t
	if t < off_time:
		_set_burning(false)
		_lamp.color = Color(0.35, 0.35, 0.4)
	elif t < off_time + warn_time:
		# 预警：灯变红闪，但还没有伤害
		_set_burning(false)
		_lamp.color = Color(1.0, 0.25, 0.18)
	else:
		_set_burning(true)
		_lamp.color = Color(1.0, 0.8, 0.3)


func _set_burning(v: bool) -> void:
	if v == _burning:
		return
	_burning = v
	_shape.set_deferred("disabled", not v)
	_flame.visible = v
	_core.visible = v
	_particles.emitting = v
	_lamp.modulate.a = 1.0
	set_deferred("monitoring", v)
	if not v:
		_flame.scale = Vector2.ONE
		_core.scale = Vector2.ONE

	# 由灭转着火的瞬间：如果玩家正好站在里面，直接判死。
	# 用 call_deferred：_ready 时物理服务器还没准备好，马上查重叠会报错。
	if v and is_inside_tree():
		call_deferred("_check_overlap")


func _check_overlap() -> void:
	if not _burning:
		return
	for b in get_overlapping_bodies():
		if b.is_in_group("player") and b.has_method("die"):
			b.die()


func _on_body_entered(body: Node2D) -> void:
	if not _burning or not body.is_in_group("player"):
		return
	if body.has_method("die"):
		body.die()


func reset_hazard() -> void:
	var cycle := off_time + warn_time + on_time
	_t = fmod(phase * cycle, cycle)
	_burning = true
	_set_burning(false)
