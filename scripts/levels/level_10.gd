extends "res://scripts/level_base.gd"
## 关卡 10 ——「风车」（上下双层 + 风场竖井升降台 + 可选钥匙 + 金币房）

func _ready() -> void:
	level_number = 10
	level_title = "风车"
	world_size = Vector2(2600, 1200)
	start_position = Vector2(100, 700)
	finish_position = Vector2(2400, 779)
	super()


func _subtitle() -> String:
	return "下层地火/史莱姆，坐风场升降台到上层拿钥匙；火盆门在终点前。"


func _intro_hint() -> String:
	return "竖井里的升降台会上下走；上层的钥匙是可选，金币房在门后。"


func _build() -> void:
	_add_platform(Vector2(600, 800), 1200, 40)   # 0~1200，底 780
	# 移动平台的 pos 是行程中点：701 ± 90 → 端点 611/791（顶 600/780）
	_add_moving_platform(Vector2(1200, 701), Vector2(0, -180), 55.0, 120)
	_add_wind_field(Vector2(1200, 500), Vector2(120, 400))
	_add_platform(Vector2(1500, 580), 400, 40)   # 1300~1700，顶 560
	_add_platform(Vector2(1750, 580), 300, 40)   # 1600~1900，顶 560（金币房）
	_add_platform(Vector2(2150, 800), 500, 40)   # 1900~2400，底 780

	_add_flame_jet(Vector2(800, 780), true, 0.0)
	_add_walker(Vector2(600, 760), 80, 55)
	_add_element_orb(Vector2(1000, 750), Element.Kind.FIRE)
	_add_key(Vector2(1400, 520))
	_add_key_door(Vector2(1600, 480), Vector2(40, 160))

	_add_coin(Vector2(500, 750))
	_add_coin(Vector2(1350, 520))
	_add_coin(Vector2(1500, 520))
	_add_coin(Vector2(1800, 520))
	_add_coin(Vector2(1850, 520))

	_add_checkpoint(Vector2(1100, 780))
	_add_element_receiver(Vector2(2200, 740), Element.Kind.FIRE, "gate")
	_add_door(Vector2(2300, 680), "gate", Vector2(40, 200))
	_add_finish_flag(finish_position)
	_add_death_zone(1200, -200, 2700)
