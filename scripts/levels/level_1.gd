extends "res://scripts/level_base.gd"
## 关卡 1 ——「绿色平原」（马里奥 1-1 风格：跳坑、金币、史莱姆）

func _ready() -> void:
	level_number = 1
	level_title = "绿色平原"
	world_size = Vector2(2800, 1000)
	start_position = Vector2(100, 700)
	finish_position = Vector2(2500, 779)
	super()


func _subtitle() -> String:
	return "跳坑、吃金币、躲史莱姆；先熟悉手感。"


func _intro_hint() -> String:
	return "A/D 移动，空格跳；金币 5 枚，终点在右边。卡住了按 R 重开。"


func _build() -> void:
	_add_platform(Vector2(150, 800), 500, 40)     # -100~400
	_add_platform(Vector2(700, 800), 400, 40)     # 500~900
	_add_platform(Vector2(1400, 800), 800, 40)    # 1000~1800
	_add_platform(Vector2(2300, 800), 800, 40)    # 1900~2700
	_add_sign(Vector2(280, 700), "空格跳；掉进坑里按 R 重开")

	_add_coin(Vector2(250, 750))
	_add_coin(Vector2(500, 750))
	_add_coin(Vector2(1200, 750))
	_add_coin(Vector2(1650, 750))
	_add_coin(Vector2(2200, 750))

	_add_checkpoint(Vector2(1100, 780))
	_add_walker(Vector2(700, 760), 80, 55)
	_add_walker(Vector2(1500, 760), 100, 60)
	_add_walker(Vector2(2100, 760), 80, 55)
	_add_finish_flag(finish_position)

	_add_death_zone(1050, -200, 2900)
