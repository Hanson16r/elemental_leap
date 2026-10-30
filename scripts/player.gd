extends CharacterBody2D
## 玩家控制器 —— Day 2「角色能显示」+ Day 3「能跑能跳」+ Day 4「手感调优」三天内容。
##
## Day 2 的四件事，在 scenes/player.tscn 里：
##   CharacterBody2D（会碰撞会移动的身体）
##     ├─ AnimatedSprite2D  （行走图：idle / run 两套动画；具体用哪张由「选择角色」决定）
##     ├─ CollisionShape2D  （胶囊形碰撞盒，比矩形过拐角更顺）
##     └─ Camera2D          （已勾选平滑跟随）
##
## Day 4 的两个关键手感机制，在 _physics_process 的 ① ② 两处：
##   ① 土狼时间（coyote time）：刚离开平台的 0.1 秒内按跳，仍然算数。
##      解决"我明明还在平台上，怎么就跳不起来"——玩家最容易骂人的地方。
##   ② 跳跃缓冲（jump buffer）：落地前 0.12 秒内按过跳，落地瞬间自动起跳。
##      解决"我按了跳怎么没反应"——预判玩家的输入意图。
##   各十行代码，是整个项目里投入产出比最高的手感改动。
##
## Day 8 的移动平台"带人"：见 ③。

# ===================================================================== 手感参数（Day 4 就调这里）
## 水平最大速度（像素/秒）
@export var speed: float = 240.0
## 冰面上的最高速度：冰面摩擦力低，速度能冲到更高，所以滑得更快
@export var ice_max_speed: float = 348.0
## 地面加速度相对最大速度的倍数。
## 15 倍意味着约 1/15 秒就到全速（跑 8 像素）。
## 这个数字很关键：跳跃只有 0.3~0.4 秒，如果加速太慢，玩家跳起来的时候还没跑满速，
## 就跨不过本该跨得过去的坑 —— 那会变成"必须在平台边缘起跳才行"的坏手感。
## 工具「关卡检查.bat」会读这个值来验算关卡，改它一定重跑一次。
@export var ground_accel_mult: float = 15.0
## 空中加速度相对地面的比例。小于 1 表示空中转向有一点惯性，不会太"硬"
@export var air_accel_ratio: float = 0.5
## 起跳瞬间速度，负数 = 向上。摸高 = 480²/(2×1250) ≈ 92 像素
@export var jump_velocity: float = -480.0
## 重力加速度（像素/秒²）
@export var gravity: float = 1250.0
## 下坠时重力倍率。上升慢、下落快 → 跳跃干脆，平台跳跃的通用做法
@export var fall_gravity_mult: float = 1.35
## 松开跳跃键时把上升速度砍掉多少 → 实现"短按小跳、长按大跳"
@export var jump_cut_mult: float = 0.45
## 最大下落速度，防止掉太快穿过薄平台
@export var max_fall_speed: float = 900.0

## 土狼时间窗口（秒）
@export var coyote_time: float = 0.10
## 跳跃缓冲窗口（秒）
@export var jump_buffer_time: float = 0.12

# ===================================================================== 内部状态
var _coyote: float = 0.0          # 距离上次站在地面过了多久
var _buffer: float = 0.0          # 距离上次按跳过了多久
var _facing: float = 1.0          # 1 = 朝右，-1 = 朝左
var _was_on_floor: bool = false
var _platform_step: Vector2 = Vector2.ZERO   # ③ 脚下平台这一物理帧的位移
var _dead: bool = false
var _spawn: Vector2 = Vector2.ZERO

## 手里拿着的元素（Element.Kind）。一次只能拿一个，NONE = 空手
var held_element: int = Element.Kind.NONE

## 风区给的临时加速（0 = 没有风）
var _wind_timer: float = 0.0
var _wind_speed: float = 0.0
## 是否站在风场（上升气流）里
var in_updraft: bool = false
var _updraft_speed: float = 260.0
## 是否带着钥匙（第 10 关起的钥匙门用）
var has_key: bool = false
## 脚下是不是冰面（冰面摩擦力低，会滑）
var _on_ice: bool = false
## 侧风：目标水平速度偏移（px/s，负 = 向左）。由 hazards/reverse_wind.gd 设置。
var side_wind: float = 0.0

## 角色显示放大倍数。碰撞盒不变（判定还是原来的大小，视觉大一点更显眼）。
## 改了这里，AnimatedSprite2D 的 offset 也要跟着改，保证脚底对齐：
## offset_y = 21 / VISUAL_SCALE.y - 24
const VISUAL_SCALE := Vector2(1.8, 1.8)

@onready var _visual: AnimatedSprite2D = $AnimatedSprite2D
@onready var _camera: Camera2D = $Camera2D

## 死亡动画播完后发出，关卡脚本接住它做重生
signal died


func _ready() -> void:
	_spawn = global_position
	_camera.limit_smoothed = true
	_visual.scale = VISUAL_SCALE
	_apply_character()                 # 换成玩家在主菜单选的角色（没选过就用默认）
	if _visual.sprite_frames != null and _visual.sprite_frames.has_animation("idle"):
		_visual.play("idle")
	print("[Player] 就绪。A/D 移动，空格跳，R 重开，Esc 暂停。")


## 把 AnimatedSprite2D 的行走图换成「选择角色」里选中的那张。
## 切片逻辑在 scripts/autoload/character_db.gd（Characters 单例），玩家这边只管换。
## 换不到（图丢了 / id 不认识）就保持 player.tscn 里手摆的那一份，游戏照常能玩。
func _apply_character() -> void:
	var frames := Characters.build_frames(Characters.selected_id())
	if frames == null:
		push_warning("[Player] 角色行走图加载失败，沿用 player.tscn 里的默认图")
		return
	_visual.sprite_frames = frames


## 关卡脚本在玩家碰到检查点后调用它，改掉"复活点"
func set_spawn(pos: Vector2) -> void:
	_spawn = pos


func get_spawn() -> Vector2:
	return _spawn


func is_dead() -> bool:
	return _dead


## 敌人用：判断玩家是不是“从上方踩下来”的。
## 踩踏：玩家正在下落，且脚底还在敌人中心上方一点 → 双方都不受伤（史莱姆不会被打死）。
## 其他方向（横向 / 从下往上）不满足这个条件，由敌人按“碰到即死”处理。
func is_stomping_on(enemy: Node2D) -> bool:
	if _dead or velocity.y <= 0.0:
		return false

	var half_h := 21.0
	var shape: Shape2D = $CollisionShape2D.shape
	if shape is CapsuleShape2D:
		half_h = (shape as CapsuleShape2D).height * 0.5
	elif shape is RectangleShape2D:
		half_h = (shape as RectangleShape2D).size.y * 0.5

	var feet := global_position.y + half_h
	return feet < enemy.global_position.y + 6.0


## 踩到敌人时被弹起。力度由敌人传入（普通跳的 0.6~0.8 倍）
func bounce(up_speed: float) -> void:
	if _dead:
		return
	velocity.y = -absf(up_speed)


# ===================================================================== 元素系统（Day 4~7）
## 元素球调用它："你手空吗？空的话我把元素给你。"
## 返回 true 表示拿成功了；false 表示手里已经有东西，元素球会留在原地。
func pick_up(kind: int) -> bool:
	if held_element != Element.Kind.NONE:
		return false
	held_element = kind
	queue_redraw()                      # 重画头顶的元素球
	Events.element_changed.emit(kind)
	return true


## 把元素用掉（火盆 / 融冰 / 冻水）。用掉后手里变空，可以拿下一个。
func consume() -> void:
	if held_element == Element.Kind.NONE:
		return
	var kind := held_element
	held_element = Element.Kind.NONE
	queue_redraw()
	Events.element_changed.emit(Element.Kind.NONE)
	Events.element_used.emit(kind)


## 元素被外力清空（走进水幕浇灭火）。和 consume() 的区别只是发的事件不同。
func clear_element() -> void:
	if held_element == Element.Kind.NONE:
		return
	var kind := held_element
	held_element = Element.Kind.NONE
	queue_redraw()
	Events.element_changed.emit(Element.Kind.NONE)
	Events.element_cleared.emit(kind)


func has_element(kind: int) -> bool:
	return held_element == kind


func has_any_element() -> bool:
	return held_element != Element.Kind.NONE


## 风区调用：给一段时间的水平加速。
## 不是持续推力，而是"把最大速度临时提高"——玩家松手后还会慢慢降回 240。
func apply_wind(extra_speed: float, duration: float) -> void:
	_wind_timer = maxf(_wind_timer, duration)
	_wind_speed = maxf(_wind_speed, extra_speed)


## 风场调用：true = 进入上升气流；false = 离开
func set_updraft(v: bool, speed: float = 260.0) -> void:
	in_updraft = v
	if v:
		_updraft_speed = speed


## 逆向风场调用：设置目标速度偏移（负 = 向左吹）。离开时传 0 复位。
func set_side_wind(offset: float) -> void:
	side_wind = offset


func _physics_process(delta: float) -> void:
	if _dead:
		return

	# ---------- ① 两个计时器每帧推进 ----------
	# 站在地面上就把土狼计时清零；离地就累加。999 当作"早就过期了"
	if is_on_floor():
		_coyote = 0.0
	else:
		_coyote = minf(_coyote + delta, 999.0)
	_buffer = minf(_buffer + delta, 999.0)

	# ---------- 重力 ----------
	if not is_on_floor():
		if in_updraft:
			# 风场里持续上升，不受重力
			velocity.y = minf(velocity.y, -_updraft_speed)
		else:
			var g := gravity
			if velocity.y > 0.0:
				g *= fall_gravity_mult
			velocity.y = minf(velocity.y + g * delta, max_fall_speed)

	# ---------- ② 按跳只记录"意图"，不当帧判断能不能跳 ----------
	if Input.is_action_just_pressed("jump"):
		_buffer = 0.0
	# 松手就砍掉上升速度 → 长按跳更高
	if Input.is_action_just_released("jump") and velocity.y < 0.0:
		velocity.y *= jump_cut_mult

	# 真正决定跳不跳。允许 velocity.y 略小于 0，是为了移动平台上那一帧的边界情况
	if _buffer < jump_buffer_time and _coyote < coyote_time and velocity.y > -60.0:
		velocity.y = jump_velocity
		_buffer = 999.0     # 用掉这次意图，否则一次按键会连跳两下
		_coyote = 999.0
		_squash(0.78, 1.22)              # 起跳拉伸
		Sfx.play_jump()

	# ---------- 左右移动 ----------
	var dir := Input.get_axis("left", "right")
	# 风区会把"最大速度"临时抬高；时间到了自动降回 speed
	var max_speed := speed
	if _on_ice:
		max_speed = maxf(max_speed, ice_max_speed)   # 冰面：滑得更快
	if _wind_timer > 0.0:
		_wind_timer = maxf(_wind_timer - delta, 0.0)
		max_speed = maxf(max_speed, _wind_speed)
	var accel := speed * ground_accel_mult
	if not is_on_floor():
		accel *= air_accel_ratio      # 空中转向慢一点 = 有一点惯性
	elif _on_ice:
		accel *= 0.15                 # 冰面：只有 15% 的摩擦力，会滑

	# ---------- 侧风（逆向风场）----------
	# side_wind 是"目标速度偏移"（px/s，负 = 向左），直接加进这一次的目标速度：
	# 不按方向键会被吹到 side_wind；按住 D 只能达到 max_speed + side_wind，形成顶风。
	# 必须合并成**一次** move_toward（两次调用会在两个目标之间来回挣）。
	var target_x := dir * max_speed
	if side_wind != 0.0:
		target_x += side_wind
	velocity.x = move_toward(velocity.x, target_x, accel * delta)

	if dir != 0.0:
		_facing = signf(dir)

	# ---------- ③ 移动平台带人 ----------
	# 先把上一帧从平台拿到的位移加上去，再让引擎算碰撞
	if is_on_floor() and _platform_step != Vector2.ZERO:
		global_position += _platform_step

	# ---------- 交给引擎算碰撞和贴地 ----------
	move_and_slide()

	# move_and_slide 之后贴地信息才是最新的，所以这里读平台速度
	_platform_step = _read_platform_step(delta)
	_on_ice = _read_ice()

	# ---------- 落地检测 ----------
	var on_floor := is_on_floor()
	if on_floor and not _was_on_floor:
		var impact := clampf(absf(velocity.y) / 600.0, 0.25, 1.0)
		_squash(1.28, 0.74)              # 落地压扁
		Sfx.play_land(impact)
	_was_on_floor = on_floor

	_update_visual(delta)


## 读脚下踩着的那个碰撞体属不属于移动平台（移动平台脚本提供 get_carry_velocity）
func _read_platform_step(delta: float) -> Vector2:
	for i in get_slide_collision_count():
		var collider := get_slide_collision(i).get_collider()
		if collider != null and collider.has_method("get_carry_velocity"):
			return collider.get_carry_velocity() * delta
	return Vector2.ZERO


## 脚下是不是冰面？
## 冰桥的碰撞体是 freeze_pool 里创建的 AnimatableBody2D，
## is_slippery() 写在它的父节点（freeze_pool）上，所以两处都查一下。
func _read_ice() -> bool:
	for i in get_slide_collision_count():
		var collider := get_slide_collision(i).get_collider()
		if collider == null:
			continue
		if collider.has_method("is_slippery") and bool(collider.call("is_slippery")):
			return true
		var parent: Node = collider.get_parent() as Node
		if parent != null and parent.has_method("is_slippery") and bool(parent.call("is_slippery")):
			return true
	return false


func _update_visual(delta: float) -> void:
	# 左右朝向：用 flip_h，不动节点缩放（缩放会影响子节点和相机）
	if _facing != 0.0:
		_visual.flip_h = _facing < 0.0

	# 站地上且在移动时播 run，否则 idle
	var moving := is_on_floor() and absf(velocity.x) > 10.0
	var anim := "run" if moving else "idle"
	if _visual.sprite_frames != null and _visual.sprite_frames.has_animation(anim):
		if _visual.animation != anim:
			_visual.play(anim)

	# 跑动时轻微前倾，静止回正
	var target_tilt := 0.0
	if is_on_floor() and absf(velocity.x) > 30.0:
		target_tilt = 0.09 * _facing
	_visual.rotation = lerpf(_visual.rotation, target_tilt, delta * 10.0)


## 压扁/拉伸动画：sx = 宽度倍数，sy = 高度倍数
func _squash(sx: float, sy: float) -> void:
	var tw := create_tween()
	tw.tween_property(_visual, "scale", VISUAL_SCALE * Vector2(sx, sy), 0.05)
	tw.tween_property(_visual, "scale", VISUAL_SCALE, 0.14)\
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


## 死亡。关卡脚本接住 died 信号去做重生
func die() -> void:
	if _dead:
		return
	_dead = true
	velocity = Vector2.ZERO
	set_physics_process(false)
	# 关掉碰撞，免得"尸体"还在触发火焰和检查点
	$CollisionShape2D.set_deferred("disabled", true)
	Sfx.play_death()
	Events.player_died.emit()

	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(_visual, "rotation", _facing * TAU, 0.5)
	tw.tween_property(_visual, "scale", VISUAL_SCALE * Vector2(1.6, 0.2), 0.5)
	tw.tween_property(_visual, "modulate:a", 0.0, 0.5)
	await tw.finished
	died.emit()


## 重生。关卡脚本把检查点坐标传进来
func respawn_at(pos: Vector2) -> void:
	_dead = false
	# 死了就丢掉手里的元素和钥匙（元素球/钥匙/机关会被关卡一起复位）
	if held_element != Element.Kind.NONE:
		held_element = Element.Kind.NONE
		queue_redraw()
		Events.element_changed.emit(Element.Kind.NONE)
	has_key = false
	velocity = Vector2.ZERO
	_visual.rotation = 0.0
	_visual.scale = VISUAL_SCALE
	_visual.modulate.a = 1.0
	_coyote = 999.0
	_buffer = 999.0
	_was_on_floor = false
	_platform_step = Vector2.ZERO
	_wind_timer = 0.0
	_wind_speed = 0.0
	in_updraft = false
	_on_ice = false
	side_wind = 0.0
	$CollisionShape2D.set_deferred("disabled", false)
	set_physics_process(true)
	move_to_spawn(pos)
	_camera.reset_smoothing()      # 相机瞬移过去，别从老位置滑过来


## 把玩家放到检查点。如果那里被东西挡住了，就往上抬到空位（防止卡墙 / 卡进移动平台）
func move_to_spawn(pos: Vector2) -> void:
	global_position = pos
	# test_move 会问引擎："如果我这样移动，会撞到东西吗？"
	# 被挡住就一点一点往上抬，最多抬 20 次（每次 6 像素）
	var tries := 0
	while tries < 20 and test_move(global_transform, Vector2(0.0, -6.0)):
		global_position += Vector2(0.0, -6.0)
		tries += 1
	if tries > 0:
		print("[Player] 复活点被挡住，向上抬了 ", tries * 6, " 像素")


## 通关时冻结操作
func freeze() -> void:
	set_physics_process(false)
	velocity = Vector2.ZERO


# ===================================================================== Day 2 的外观
## 角色本体已经交给 AnimatedSprite2D（行走图来自 scripts/character/，见 _apply_character），
## 这里只画"头顶的元素球"，所以 _draw() 不会盖住行走图。
func _draw() -> void:
	# 角色本体已经用 AnimatedSprite2D 显示了；
	# 这里只画头顶的元素球，所以 _draw 不会盖住行走图。
	if held_element == Element.Kind.NONE:
		return
	var c := Element.color_of(held_element)
	draw_circle(Vector2(0, -70), 7.0, c)
	draw_arc(Vector2(0, -70), 7.0, 0.0, TAU, 16, Color(1, 1, 1, 0.85), 1.5)
