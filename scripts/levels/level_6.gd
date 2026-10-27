extends "res://scripts/level_base.gd"
## 关卡 6 ——「岩石矿洞」（岩石墙 + 岩石柱 + 钥匙门）

func _ready() -> void:
	level_number = 6
	level_title = "岩石矿洞"
	world_size = Vector2(3000, 1100)
	start_position = Vector2(100, 700)
	finish_position = Vector2(2800, 779)
	super()


func _subtitle() -> String:
	return "岩石砸墙、顶起石柱；拿钥匙开门。"


func _intro_hint() -> String:
	return "岩石能砸石墙，也能把石柱从地里顶起来当台阶。"


func _build() -> void:
	_add_platform(Vector2(250, 800), 700, 40)     # -100~600
	_add_platform(Vector2(1000, 800), 600, 40)    # 700~1300
	_add_platform(Vector2(1800, 800), 800, 40)    # 1400~2200
	_add_platform(Vector2(2550, 800), 500, 40)    # 2300~2800

	_add_element_orb(Vector2(300, 750), Element.Kind.ROCK)
	_add_rock_wall(Vector2(900, 700), Vector2(40, 160))
	_add_rock_pillar(Vector2(1500, 780), 180, 60)
	_add_key(Vector2(2000, 750))
	_add_key_door(Vector2(2400, 680), Vector2(40, 200))

	_add_coin(Vector2(500, 750))
	_add_coin(Vector2(1000, 750))
	_add_coin(Vector2(1300, 750))
	_add_coin(Vector2(1800, 750))
	_add_coin(Vector2(2500, 750))

	_add_checkpoint(Vector2(1000, 780))
	_add_walker(Vector2(800, 760), 80, 55)
	_add_walker(Vector2(1700, 760), 100, 60)
	_add_finish_flag(finish_position)

	_add_death_zone(1150, -200, 3100)
