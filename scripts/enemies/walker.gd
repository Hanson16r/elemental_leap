extends Area2D
## 【史莱姆巡逻怪】—— 在平台上左右巡逻的敌人（原雪球虫）
##
## 规则不变：
##   · 在起点 ±patrol 范围内来回走，到边界掉头；
##   · 碰到玩家 → 玩家死亡（和火焰一致，不做踩踏）；
##   · 玩家死亡重生时，敌人回到起点（reset_hazard）。

## 巡逻半径（从出生点往左右各走多少像素）
@export var patrol: float = 120.0
## 移动速度（像素/秒）
@export var speed: float = 60.0

var _dir: float = 1.0
var _origin_x: float = 0.0
var _t: float = 0.0

@onready var _sprite: AnimatedSprite2D = $Slime


func _ready() -> void:
	_origin_x = position.x
	collision_layer = 4
	collision_mask = 2
	monitoring = true

	var shape := CircleShape2D.new()
	shape.radius = 20.0
	var col := CollisionShape2D.new()
	col.shape = shape
	add_child(col)

	body_entered.connect(_on_body_entered)


func _process(delta: float) -> void:
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
	if not body.is_in_group("player"):
		return
	if body.has_method("die"):
		body.die()


func reset_hazard() -> void:
	position.x = _origin_x
	_dir = 1.0
