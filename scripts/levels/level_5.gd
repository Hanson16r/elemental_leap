extends "res://scripts/level_base.gd"
## 关卡 4 ——「风之丘」（移动平台 + 风区跳远 + 火融冰墙 + 钥匙门）

func _ready() -> void:
	level_number = 5
	level_title = "风之丘"
	world_size = Vector2(3000, 1100)
	start_position = Vector2(100, 700)
	finish_position = Vector2(2800, 779)
	super()


func _subtitle() -> String:
	return "坐移动平台、借风跳过 130 的坑；火融冰墙拿钥匙。"


func _intro_hint() -> String:
	return "两个 300 的坑用移动平台；中间 130 的坑借风区加速跳。"


func _build() -> void:
	_add_platform(Vector2(200, 800), 600, 40)     # -100~500
	_add_platform(Vector2(1000, 800), 400, 40)    # 800~1200
	_add_platform(Vector2(1665, 800), 670, 40)    # 1330~2000
	_add_platform(Vector2(2550, 800), 500, 40)    # 2300~2800

	_add_moving_platform(Vector2(650, 780), Vector2(240, 0), 80.0, 160)
	_add_moving_platform(Vector2(2150, 780), Vector2(240, 0), 80.0, 160)
	_add_wind_zone(Vector2(1160, 740), Vector2(80, 160))
	_add_sign(Vector2(1080, 660), "借风跳过 130 的坑")

	_add_element_orb(Vector2(1400, 750), Element.Kind.FIRE)
	_add_ice_barrier(Vector2(1600, 700), Vector2(40, 160))
	_add_key(Vector2(2100, 750))
	_add_key_door(Vector2(2500, 680), Vector2(40, 200))

	_add_coin(Vector2(300, 750))
	_add_coin(Vector2(700, 750))
	_add_coin(Vector2(1100, 750))
	_add_coin(Vector2(1800, 750))
	_add_coin(Vector2(2400, 750))

	_add_checkpoint(Vector2(900, 780))
	# 第二平台（800~1200）不放怪，检查点复活更安全
	_add_walker(Vector2(1500, 760), 100, 60)
	_add_walker(Vector2(2400, 760), 80, 55)
	_add_finish_flag(finish_position)

	_add_death_zone(1150, -200, 3100)
