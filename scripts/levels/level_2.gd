extends "res://scripts/level_base.gd"
## 关卡 2 ——「水管与平台」（马里奥水管/移动平台）
## 两个 400 像素的大坑，各用一块移动平台送过去；最后拿钥匙开门。

func _ready() -> void:
	level_number = 2
	level_title = "水管与平台"
	world_size = Vector2(3000, 1000)
	start_position = Vector2(100, 700)
	finish_position = Vector2(2800, 779)
	super()


func _subtitle() -> String:
	return "等移动平台、跳过 400 的坑；拿钥匙开门。"


func _intro_hint() -> String:
	return "坑很宽，站上移动平台等它带你过去；钥匙在右边，门在终点前。"


func _build() -> void:
	_add_platform(Vector2(150, 800), 500, 40)     # -100~400
	_add_platform(Vector2(1150, 800), 500, 40)    # 900~1400
	_add_platform(Vector2(2300, 800), 1000, 40)   # 1800~2800
	_add_sign(Vector2(300, 700), "等移动平台到左边再站上去")

	_add_moving_platform(Vector2(650, 780), Vector2(240, 0), 80.0, 160)
	_add_moving_platform(Vector2(1600, 780), Vector2(240, 0), 80.0, 160)

	_add_coin(Vector2(300, 750))
	_add_coin(Vector2(700, 750))
	_add_coin(Vector2(1200, 750))
	_add_coin(Vector2(2000, 750))
	_add_coin(Vector2(2500, 750))

	_add_checkpoint(Vector2(1000, 780))
	_add_walker(Vector2(1000, 760), 100, 60)
	_add_walker(Vector2(2200, 760), 100, 60)

	_add_key(Vector2(2300, 750))
	_add_key_door(Vector2(2600, 680), Vector2(40, 200))
	_add_finish_flag(finish_position)

	_add_death_zone(1050, -200, 3100)
