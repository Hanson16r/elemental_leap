extends "res://scripts/level_base.gd"
## 关卡 8 ——「元素回廊」（冰、岩、火、风各来一次）

func _ready() -> void:
	level_number = 8
	level_title = "元素回廊"
	world_size = Vector2(3200, 1100)
	start_position = Vector2(100, 700)
	finish_position = Vector2(3000, 779)
	super()


func _subtitle() -> String:
	return "冰、岩、火、风各来一次；四种元素轮着用。"


func _intro_hint() -> String:
	return "冰冻桥 → 岩石砸墙 → 火融冰墙 → 借风跳坑 → 钥匙门。"


func _build() -> void:
	_add_platform(Vector2(250, 800), 700, 40)     # -100~400? 250±350 = -100~600
	_add_platform(Vector2(750, 800), 500, 40)     # 500~1000
	_add_platform(Vector2(1350, 800), 500, 40)    # 1100~1600
	_add_platform(Vector2(2050, 800), 700, 40)    # 1700~2400
	_add_platform(Vector2(2750, 800), 500, 40)    # 2500~3000

	_add_element_orb(Vector2(250, 750), Element.Kind.ICE)
	_add_freeze_pool(Vector2(600, 780), 200)      # 500~700
	_register_surface("static", Vector2(600, 790), 200, 20, "ice_slide（需冰冻）", Vector2.ZERO)
	_add_element_orb(Vector2(800, 750), Element.Kind.ROCK)
	_add_rock_wall(Vector2(1000, 700), Vector2(40, 160))
	_add_element_orb(Vector2(1200, 750), Element.Kind.FIRE)
	_add_ice_barrier(Vector2(1400, 700), Vector2(40, 160))
	_add_wind_zone(Vector2(1600, 740), Vector2(80, 160))
	_add_key(Vector2(1900, 750))
	_add_key_door(Vector2(2600, 680), Vector2(40, 200))

	_add_coin(Vector2(500, 750))
	_add_coin(Vector2(700, 750))
	_add_coin(Vector2(1000, 750))
	_add_coin(Vector2(1500, 750))
	_add_coin(Vector2(2200, 750))

	_add_checkpoint(Vector2(1200, 780))
	_add_walker(Vector2(1100, 760), 80, 55)
	_add_walker(Vector2(2000, 760), 100, 60)
	_add_finish_flag(finish_position)

	_add_death_zone(1150, -200, 3300)
