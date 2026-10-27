extends "res://scripts/level_base.gd"
## 关卡 3 ——「火之花」（火元素：融冰墙 + 点火盆开门）

func _ready() -> void:
	level_number = 3
	level_title = "火之花"
	world_size = Vector2(2800, 1000)
	start_position = Vector2(100, 700)
	finish_position = Vector2(2600, 779)
	super()


func _subtitle() -> String:
	return "火种①融冰墙 → 火种②点火盆 → 开门；小心地火。"


func _intro_hint() -> String:
	return "第一枚火种会被冰墙吃掉；第三平台上还有第二枚火种，用来点火盆。"


func _build() -> void:
	_add_platform(Vector2(250, 800), 700, 40)     # -100~600
	_add_platform(Vector2(1050, 800), 700, 40)    # 700~1400
	_add_platform(Vector2(2050, 800), 1100, 40)   # 1500~2600
	_add_sign(Vector2(280, 700), "火种①：融冰墙")

	_add_element_orb(Vector2(300, 750), Element.Kind.FIRE)
	_add_ice_barrier(Vector2(800, 700), Vector2(40, 160))
	_add_flame_jet(Vector2(1200, 780), true, 0.0)
	# 第二枚火种：冰墙消耗掉第一枚后，火盆还需要火
	_add_element_orb(Vector2(1550, 750), Element.Kind.FIRE)
	_add_sign(Vector2(1500, 660), "火种②：点火盆")
	_add_element_receiver(Vector2(1800, 740), Element.Kind.FIRE, "gate")
	_add_door(Vector2(2000, 680), "gate", Vector2(40, 200))

	_add_coin(Vector2(500, 750))
	_add_coin(Vector2(1000, 750))
	_add_coin(Vector2(1300, 750))
	_add_coin(Vector2(1700, 750))
	_add_coin(Vector2(2200, 750))

	_add_checkpoint(Vector2(1000, 780))
	_add_walker(Vector2(900, 760), 80, 55)
	_add_walker(Vector2(1600, 760), 100, 60)
	_add_finish_flag(finish_position)

	_add_death_zone(1050, -200, 2900)
