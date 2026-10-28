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

# ---- 触发模式（2026-10-28 为第 13 关加）----
## true = 不走固定周期，由压力板等外部信号调用 press() / release() 控制
@export var triggered: bool = false
## 踩下后多久着火
@export var trigger_delay: float = 2.0
## 着火持续多久
@export var burn_time: float = 1.5
## 离开压力板后多久重新待机（这期间再踩也没用）
@export var reset_time: float = 3.0

var _t: float = 0.0
var _shape: CollisionShape2D
var _flame: Polygon2D
var _core: Polygon2D
var _lamp: Polygon2D
var _particles: CPUParticles2D
var _burning: bool = false

# 触发模式的状态机：0 待机 / 1 蓄势 / 2 燃烧 / 3 冷却
var _tstate: int = 0
var _state_timer: float = 0.0
var _on_plate: bool = false


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

	if triggered:
		_tstate = 0
		_state_timer = 0.0
		_set_burning(false)
		_lamp.color = Color(0.35, 0.35, 0.4)
	else:
		var cycle := off_time + warn_time + on_time
		_t = fmod(phase * cycle, cycle)
		_update_state()


func _process(delta: float) -> void:
	if triggered:
		_process_triggered(delta)
	else:
		var cycle := off_time + warn_time + on_time
		_t = fmod(_t + delta, cycle)
		_update_state()

	var wobble_t := _state_timer if triggered else _t

	# 着火时火焰左右抖，预警时灯闪
	if _burning:
		_flame.scale.x = 1.0 + sin(wobble_t * 38.0) * 0.10
		_core.scale.x = 1.0 + sin(wobble_t * 46.0) * 0.14
	elif not triggered and _t >= off_time and _t < off_time + warn_time:
		var blink := 0.55 + 0.45 * sin(_t * 60.0)
		_lamp.modulate.a = blink
	elif not triggered:
		_lamp.modulate.a = 1.0


## 触发模式的状态机：待机 → 蓄势 → 燃烧 → 冷却 → 待机
func _process_triggered(delta: float) -> void:
	match _tstate:
		0:
			_lamp.color = Color(0.35, 0.35, 0.4)
			_lamp.modulate.a = 1.0
		1:
			_state_timer += delta
			_lamp.color = Color(1.0, 0.25, 0.18)
			_lamp.modulate.a = 0.55 + 0.45 * sin(_state_timer * 24.0)
			if _state_timer >= trigger_delay:
				_tstate = 2
				_state_timer = 0.0
				_set_burning(true)
		2:
			_state_timer += delta
			_lamp.color = Color(1.0, 0.8, 0.3)
			_lamp.modulate.a = 1.0
			if _state_timer >= burn_time:
				_tstate = 3
				_state_timer = 0.0
				_set_burning(false)
		3:
			_lamp.color = Color(0.35, 0.35, 0.4)
			_lamp.modulate.a = 1.0
			# 必须"离开压力板"才开始计时，玩家一直站着不会重置
			if not _on_plate:
				_state_timer += delta
				if _state_timer >= reset_time:
					_tstate = 0
					_state_timer = 0.0


## 压力板踩下：待机状态下开始蓄势
func press() -> void:
	if not triggered:
		return
	_on_plate = true
	if _tstate == 0:
		_tstate = 1
		_state_timer = 0.0
		Sfx.play_click()


## 压力板松开：冷却阶段重新开始计"离开时间"
func release() -> void:
	if not triggered:
		return
	_on_plate = false
	if _tstate == 3:
		_state_timer = 0.0


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
	if triggered:
		_tstate = 0
		_state_timer = 0.0
		_on_plate = false
		_set_burning(false)
		_lamp.color = Color(0.35, 0.35, 0.4)
		_lamp.modulate.a = 1.0
		return
	var cycle := off_time + warn_time + on_time
	_t = fmod(phase * cycle, cycle)
	_burning = true
	_set_burning(false)
