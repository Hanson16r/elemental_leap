extends Area2D
## 【喷火史莱姆】—— 站在平台上，每隔一段时间朝一个方向喷火球
##
## 和巡逻史莱姆的区别：
##   · 它不移动，但会定期喷火球（fireball.tscn）；
##   · 它自己也是危险物：从上方踩到压扁、把玩家弹起，横向撞到才死；
##   · 喷火前 0.35 秒身体会变红，给玩家预警。
##
## 用法：_add_fire_shooter(Vector2(x, y), -1.0)   # 朝左喷

## 喷火方向：-1 朝左，1 朝右
@export var direction: float = -1.0
## 喷火间隔（秒）
@export var interval: float = 2.2

const FIREBALL_SCENE: PackedScene = preload("res://scenes/enemies/fireball.tscn")

## 压扁持续时间（秒）
const SQUISH_TIME := 0.8
## 压扁后的纵向比例（原比例的 22%）
const SQUISH_SCALE_Y := 0.22
## 踩踏弹起力度 = 普通跳力 × 这个系数
const BOUNCE_MULT := 0.7

var _t: float = 0.0

var _squished: bool = false
var _squish_t: float = 0.0
var _base_scale: Vector2 = Vector2.ONE
var _base_offset: Vector2 = Vector2.ZERO

@onready var _sprite: AnimatedSprite2D = $Slime


func _ready() -> void:
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

	_t += delta
	# 喷火前 0.35 秒身体变红，给玩家预警
	if _t > interval - 0.35:
		_sprite.modulate = Color(1.0, 0.55, 0.35)
	else:
		_sprite.modulate = Color.WHITE
	if _t >= interval:
		_t = 0.0
		_shoot()


func _shoot() -> void:
	if _squished:
		return
	var fb: Area2D = FIREBALL_SCENE.instantiate() as Area2D
	fb.setup(direction)
	get_parent().add_child(fb)
	fb.global_position = global_position + Vector2(direction * 28.0, -18.0)
	Sfx.play_click()


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


## 压扁：关碰撞、把精灵压成薄片（底边贴地），压扁期间不喷火
func _squish() -> void:
	if _squished:
		return
	_squished = true
	_squish_t = SQUISH_TIME
	set_deferred("monitoring", false)
	_sprite.modulate = Color.WHITE
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
	_sprite.modulate = Color.WHITE
	monitoring = true


func _player_near() -> bool:
	for p in get_tree().get_nodes_in_group("player"):
		var node := p as Node2D
		if node != null and node.global_position.distance_to(global_position) < 20.0:
			return true
	return false


## 复活时喷火计时清零、恢复原状；已经飞出去的火球由 fireball.gd 的 reset_hazard() 清掉
func reset_hazard() -> void:
	if _squished:
		_unsquish()
	_t = 0.0
	_sprite.modulate = Color.WHITE
