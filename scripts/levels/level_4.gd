extends "res://scripts/level_base.gd"
## 关卡 4 ——「冰之谷」（冰元素：冻桥、滑冰、短火焰、火融冰墙、钥匙门）

func _ready() -> void:
	level_number = 4
	level_title = "冰之谷"
	world_size = Vector2(2800, 1000)
	start_position = Vector2(100, 700)
	finish_position = Vector2(2600, 779)
	super()


func _subtitle() -> String:
	return "冰种冻桥 → 滑过去 → 跳过短火焰和坑 → 火融冰墙 → 钥匙门。"


func _intro_hint() -> String:
	return "冰面会把你加速到 348；短火焰只有 60 高，跳得过去。"


func _build() -> void:
	_add_platform(Vector2(150, 800), 500, 40)     # -100~400
	_add_freeze_pool(Vector2(700, 780), 600)      # 400~1000
	_register_surface("static", Vector2(700, 790), 600, 20, "ice_slide（需冰冻）", Vector2.ZERO)
	_add_platform(Vector2(1250, 800), 500, 40)    # 1000~1500
	_add_platform(Vector2(2100, 800), 1000, 40)   # 1600~2600
	_add_sign(Vector2(280, 700), "冰种冻桥；冰面很滑")

	_add_element_orb(Vector2(250, 750), Element.Kind.ICE)
	_add_flame_jet(Vector2(850, 780), true, 0.0, 60.0)
	_add_element_orb(Vector2(1200, 750), Element.Kind.FIRE)
	_add_ice_barrier(Vector2(1300, 700), Vector2(40, 160))
	_add_key(Vector2(1700, 750))
	_add_key_door(Vector2(2200, 680), Vector2(40, 200))

	_add_coin(Vector2(500, 750))
	_add_coin(Vector2(800, 750))
	_add_coin(Vector2(1150, 750))
	_add_coin(Vector2(1700, 750))
	_add_coin(Vector2(2400, 750))

	_add_checkpoint(Vector2(1000, 780))
	_add_walker(Vector2(1100, 760), 80, 55)
	_add_walker(Vector2(1900, 760), 100, 60)
	_add_finish_flag(finish_position)

	_add_death_zone(1050, -200, 2900)
