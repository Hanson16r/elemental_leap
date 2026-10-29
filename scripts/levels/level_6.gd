extends "res://scripts/level_base.gd"
## 关卡 6 ——「水之洞」（水会浇灭火种：跳过水幕，保住火去融冰墙）

func _ready() -> void:
	level_number = 6
	level_title = "水之洞"
	world_size = Vector2(3000, 1100)
	start_position = Vector2(100, 700)
	finish_position = Vector2(2800, 779)
	super()


func _subtitle() -> String:
	return "捡火种融冰墙，拿钥匙开门；小心史莱姆。"


func _intro_hint() -> String:
	return "火种能融冰墙；冰墙在钥匙前面。"


func _build() -> void:
	_add_platform(Vector2(300, 800), 800, 40)     # -100~700
	_add_platform(Vector2(1100, 800), 600, 40)    # 800~1400
	_add_platform(Vector2(1850, 800), 700, 40)    # 1500~2200
	_add_platform(Vector2(2550, 800), 500, 40)    # 2300~2800

	_add_element_orb(Vector2(400, 750), Element.Kind.FIRE)
	_add_ice_barrier(Vector2(1100, 700), Vector2(40, 160))
	_add_key(Vector2(1600, 750))
	_add_key_door(Vector2(2000, 680), Vector2(40, 200))

	_add_coin(Vector2(300, 750))
	_add_coin(Vector2(700, 750))
	_add_coin(Vector2(1000, 750))
	_add_coin(Vector2(1500, 750))
	_add_coin(Vector2(2400, 750))

	_add_checkpoint(Vector2(1000, 780))
	_add_walker(Vector2(1200, 760), 80, 55)
	_add_walker(Vector2(1900, 760), 100, 60)
	_add_finish_flag(finish_position)

	_add_death_zone(1150, -200, 3100)
