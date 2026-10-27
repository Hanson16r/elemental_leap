extends Area2D
## 【喷火史莱姆】—— 站在平台上，每隔一段时间朝一个方向喷火球
##
## 和巡逻史莱姆的区别：
##   · 它不移动，但会定期喷火球（fireball.tscn）；
##   · 它自己也是危险物（碰到就死）；
##   · 喷火前 0.35 秒身体会变红，给玩家预警。
##
## 用法：_add_fire_shooter(Vector2(x, y), -1.0)   # 朝左喷

## 喷火方向：-1 朝左，1 朝右
@export var direction: float = -1.0
## 喷火间隔（秒）
@export var interval: float = 2.2

const FIREBALL_SCENE: PackedScene = preload("res://scenes/enemies/fireball.tscn")

var _t: float = 0.0

@onready var _sprite: AnimatedSprite2D = $Slime


func _ready() -> void:
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
	var fb: Area2D = FIREBALL_SCENE.instantiate() as Area2D
	fb.setup(direction)
	get_parent().add_child(fb)
	fb.global_position = global_position + Vector2(direction * 28.0, -18.0)
	Sfx.play_click()


func _on_body_entered(body: Node2D) -> void:
	if not body.is_in_group("player"):
		return
	if body.has_method("die"):
		body.die()


## 复活时喷火计时清零；已经飞出去的火球由 fireball.gd 的 reset_hazard() 清掉
func reset_hazard() -> void:
	_t = 0.0
	_sprite.modulate = Color.WHITE
