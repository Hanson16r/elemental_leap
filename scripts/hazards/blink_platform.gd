extends AnimatableBody2D
## 会消失再出现的平台 —— 对应 Day 9「加一个会消失再出现的平台，用计时器控制」
##
## 用计时器状态机，而不是真的 Timer 节点，这样时序一眼看得清：
##   出现 → (visible_time) → 警告闪烁 → (warn_time) → 消失 → (hidden_time) → 回到出现
##
## 关键点：消失的时候必须把 collision 的 disabled 设为 true，
## 否则"看不见但踩得住"，玩家会觉得游戏坏了。

@export var width: float = 160.0
@export var thickness: float = 22.0
## 出现多久（秒）
@export var visible_time: float = 2.0
## 消失前警告多久（秒）
@export var warn_time: float = 0.5
## 消失多久（秒）
@export var hidden_time: float = 1.6
## 相位偏移，让多块平台错开出现（0~1）
@export var phase: float = 0.0

var _t: float = 0.0
var _visual: Polygon2D
var _col: CollisionShape2D


func setup(w: float, ph: float = 0.0) -> void:
	width = w
	phase = ph
	_apply_geometry()
	_t = phase * (visible_time + warn_time + hidden_time)


func _ready() -> void:
	_visual = get_node_or_null("Visual") as Polygon2D
	_col = get_node_or_null("CollisionShape2D") as CollisionShape2D
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


func _process(delta: float) -> void:
	_t += delta
	var cycle := visible_time + warn_time + hidden_time
	var k := fmod(_t, cycle)

	if k < visible_time:
		_set_solid(true, 1.0)
	elif k < visible_time + warn_time:
		# 警告：快速闪烁，并且越闪越透明
		var w := (k - visible_time) / warn_time
		_set_solid(true, 1.0 - 0.55 * w)
		if _visual != null:
			_visual.modulate.a = 1.0 if fmod(k * 12.0, 1.0) < 0.5 else 0.35
	else:
		_set_solid(false, 0.0)


func _set_solid(solid: bool, alpha: float) -> void:
	if _col != null and _col.disabled == solid:
		_col.set_deferred("disabled", not solid)
	if _visual != null:
		_visual.modulate.a = alpha
		_visual.visible = alpha > 0.01


## 玩家重生时调用，让平台回到"出现"状态，避免复活就掉下去
func reset_hazard() -> void:
	_t = phase * (visible_time + warn_time + hidden_time)
	_set_solid(true, 1.0)
	_col.set_deferred("disabled", false)
