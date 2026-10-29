extends Area2D
## 【史莱姆巡逻怪】—— 在平台上左右巡逻的敌人（原雪球虫）
##
## 规则：
##   · 在起点 ±patrol 范围内来回走，到边界掉头；
##   · 从上方踩到 → 压扁成薄片、玩家被弹起，0.8 秒后弹回原状（双方都不死）；
##   · 横向撞到 → 玩家死亡；
##   · 玩家死亡重生时，敌人回到起点、恢复原状（reset_hazard）。

## 巡逻半径（从出生点往左右各走多少像素）
@export var patrol: float = 120.0
## 移动速度（像素/秒）
@export var speed: float = 60.0

## 压扁持续时间（秒）
const SQUISH_TIME := 0.8
## 压扁后的纵向比例（原比例的 22%）
const SQUISH_SCALE_Y := 0.22
## 踩踏弹起力度 = 普通跳力 × 这个系数
const BOUNCE_MULT := 0.7

var _dir: float = 1.0
var _origin_x: float = 0.0
var _t: float = 0.0

var _squished: bool = false
var _squish_t: float = 0.0
var _base_scale: Vector2 = Vector2.ONE
var _base_offset: Vector2 = Vector2.ZERO

@onready var _sprite: AnimatedSprite2D = $Slime


func _ready() -> void:
	_origin_x = position.x
	collision_layer = 4
	collision_mask = 2
	monitoring = true
	_base_scale = _sprite.scale
	_base_offset = _sprite.offset

	var shape := CircleShape2D.new()
	shape.radius = 20.0
	var col := CollisionShape2D.new()
	col.shape = shape
	add_child(col)

	body_entered.connect(_on_body_entered)


func _process(delta: float) -> void:
	if _squished:
		_squish_t -= delta
		if _squish_t <= 0.0 and not _player_near():
			_unsquish()
		return

	position.x += _dir * speed * delta
	if position.x > _origin_x + patrol:
		position.x = _origin_x + patrol
		_dir = -1.0
	elif position.x < _origin_x - patrol:
		position.x = _origin_x - patrol
		_dir = 1.0

	# 史莱姆朝移动方向翻面，走起来左右晃
	_sprite.flip_h = _dir < 0.0
	_t += delta
	_sprite.rotation = sin(_t * 6.0) * 0.08


func _on_body_entered(body: Node2D) -> void:
	if not body.is_in_group("player") or _squished:
		return
	# 从上方踩到：压扁 + 把玩家弹起，双方都不受伤
	if body.has_method("is_stomping_on") and body.is_stomping_on(self):
		_squish()
		if body.has_method("bounce"):
			body.bounce(body.jump_velocity * BOUNCE_MULT)
		return
	if body.has_method("die"):
		body.die()


## 压扁：停巡逻、关碰撞、把精灵压成薄片（底边贴地）
func _squish() -> void:
	if _squished:
		return
	_squished = true
	_squish_t = SQUISH_TIME
	set_deferred("monitoring", false)
	_sprite.rotation = 0.0
	_sprite.scale = Vector2(_base_scale.x * 1.15, _base_scale.y * SQUISH_SCALE_Y)
	# 精灵底边保持在原地：底边 = scale.y × (offset.y + 24)
	var bottom := _base_scale.y * (_base_offset.y + 24.0)
	_sprite.offset = Vector2(_base_offset.x, bottom / _sprite.scale.y - 24.0)


## 恢复原状（有玩家还站在这块扁片上时先不恢复，等它走开）
func _unsquish() -> void:
	_squished = false
	_squish_t = 0.0
	_sprite.scale = _base_scale
	_sprite.offset = _base_offset
	_sprite.rotation = 0.0
	monitoring = true


func _player_near() -> bool:
	for p in get_tree().get_nodes_in_group("player"):
		var node := p as Node2D
		if node != null and node.global_position.distance_to(global_position) < 20.0:
			return true
	return false


func reset_hazard() -> void:
	if _squished:
		_unsquish()
	position.x = _origin_x
	_dir = 1.0
	_t = 0.0
