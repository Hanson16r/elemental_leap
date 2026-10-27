extends AnimatableBody2D
## 往返移动的平台 —— 对应 Day 8「用 AnimatableBody2D + AnimationPlayer 让平台来回移动，
## 让玩家站在上面能跟着走」
##
## 原计划写的是 AnimationPlayer。这里改用代码算位置，原因：
##   1. 手感可调（速度是明确的像素/秒，改一个数字就行，动画关键帧要拖时间轴）
##   2. 不用为每块平台手动画一条动画轨道
##   3. get_carry_velocity() 能直接把速度告诉玩家脚本，带人更准
## 原理和 AnimationPlayer 完全一样，都是每帧改 position。
##
## 玩家那侧的配合在 scripts/player.gd 的 ③ 处。

@export var offset: Vector2 = Vector2(200, 0)   # 相对初始位置的往返幅度
@export var speed: float = 70.0                 # 像素/秒
@export var width: float = 160.0
@export var thickness: float = 22.0

var _origin: Vector2 = Vector2.ZERO
var _prev: Vector2 = Vector2.ZERO
var _velocity: Vector2 = Vector2.ZERO
var _initial_offset: Vector2 = Vector2(200, 0)


func setup(off: Vector2, spd: float, w: float) -> void:
	# 传进来的 off 是"总行程"：平台在 pos ± off/2 之间往返。
	# _physics_process 里已经用 half = dist * 0.5 算端点，所以这里**不能再乘 0.5**，
	# 否则实际行程会变成设计值的 1/4（第 3 关的渡船就是这样跑不到坑里的）。
	offset = off
	_initial_offset = off
	speed = spd
	width = w
	# _ready() 是在关卡设置 global_position **之前**执行的，那时 _origin 还是 (0,0)。
	# setup() 是位置设好之后才调用的，所以在这里重新记一次原点。
	# 用 position（局部坐标）而不是 global_position：
	# AnimatableBody2D 的 global_position 在 add_child 之后可能被物理服务器延迟同步，
	# 立刻读会读到 (0,0)。关卡把平台挂在一个没有位移的 GameLayer 下，
	# 所以局部坐标就是世界坐标，读 position 最稳。
	_origin = position
	_prev = _origin
	_apply_geometry()


func _ready() -> void:
	_origin = global_position
	_prev = _origin
	_apply_geometry()


func _apply_geometry() -> void:
	var shape := RectangleShape2D.new()
	shape.size = Vector2(width, thickness)
	var col := get_node_or_null("CollisionShape2D") as CollisionShape2D
	if col != null:
		col.shape = shape
	var vis := get_node_or_null("Visual") as Polygon2D
	if vis != null:
		var hw := width * 0.5
		var hh := thickness * 0.5
		vis.polygon = PackedVector2Array([
			Vector2(-hw, -hh), Vector2(hw, -hh), Vector2(hw, hh), Vector2(-hw, hh),
		])
		vis.color = Color(0.55, 0.72, 0.88)


func _physics_process(delta: float) -> void:
	# 没有用 sin()，而是"到端点就掉头"，这样速度是恒定的，玩家好预判
	var dist := offset.length()
	if dist < 1.0:
		return
	var dir := offset.normalized()
	var travel := speed * delta

	# 当前位置在 -offset/2 到 +offset/2 之间来回
	var local := global_position - _origin
	var along := local.dot(dir)
	var half := dist * 0.5

	along += travel
	if along > half:
		# 掉头：把超出的部分反射回去，避免"端点处卡一下"
		along = half - (along - half)
		offset = -offset
	if along < -half:
		along = -half + (-half - along)
		offset = -offset

	# 用垂直方向的分量保持不变（支持斜向移动）
	var perp := Vector2(-dir.y, dir.x)
	var side := local.dot(perp)
	global_position = _origin + dir * along + perp * side

	_velocity = (global_position - _prev) / maxf(delta, 0.0001)
	_prev = global_position


## 玩家脚本会调用这个来"蹭"平台的移动
func get_carry_velocity() -> Vector2:
	return _velocity


## 复活时平台回到起点，方向也复位
func reset_hazard() -> void:
	position = _origin
	_prev = _origin
	offset = _initial_offset
	_velocity = Vector2.ZERO
