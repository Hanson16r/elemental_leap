extends "res://scripts/level_base.gd"
## 关卡 10 ——「终章：元素城堡」（五种元素 + 地火 + 史莱姆 + 喷火史莱姆 + 钥匙门）

func _ready() -> void:
	level_number = 10
	level_title = "终章：元素城堡"
	world_size = Vector2(3400, 1200)
	start_position = Vector2(100, 700)
	finish_position = Vector2(3200, 779)
	super()


func _subtitle() -> String:
	return "五种元素、地火/天火、史莱姆和喷火史莱姆；最后一关。"


func _intro_hint() -> String:
	return "冰 → 岩 → 火 → 风全用上；地火/天火读节奏，钥匙开门。"


func _build() -> void:
	_add_platform(Vector2(200, 800), 600, 40)     # -100~500
	_add_platform(Vector2(900, 800), 600, 40)     # 600~1200
	_add_platform(Vector2(1650, 800), 700, 40)    # 1300~2000
	_add_platform(Vector2(2450, 800), 700, 40)    # 2100~2800
	_add_platform(Vector2(3150, 800), 500, 40)    # 2900~3400

	_add_element_orb(Vector2(250, 750), Element.Kind.ICE)
	_add_freeze_pool(Vector2(600, 780), 300)      # 450~750
	_register_surface("static", Vector2(600, 790), 300, 20, "ice_slide（需冰冻）", Vector2.ZERO)

	_add_element_orb(Vector2(900, 750), Element.Kind.ROCK)
	_add_rock_wall(Vector2(1100, 700), Vector2(40, 160))

	# ---- 2026-10-28 改动一：线性元素链 → 元素组合房间 ----
	# 火种 1400 → 冰墙 1600（横在走廊上，跳不过去）→ 融墙后走进风场 → 托到高处拿钥匙。
	# 钥匙从原来的 2400 挪到房间上方，逼玩家把"火 + 风"连着用一次。
	_add_element_orb(Vector2(1400, 750), Element.Kind.FIRE)
	_add_ice_barrier(Vector2(1600, 700), Vector2(40, 160))
	_add_wind_field(Vector2(1710, 570), Vector2(140, 420))   # x 1640~1780，y 360~780
	_add_key(Vector2(1710, 400))

	# 风区（水平加速）往右挪 30，避免和第 10 关新增的上升风场（1640~1780）叠在一起
	_add_wind_zone(Vector2(1830, 740), Vector2(80, 160))
	_add_flame_jet(Vector2(1000, 780), true, 0.0)
	_add_flame_jet(Vector2(2200, 780), true, 0.5)

	_add_key_door(Vector2(2900, 680), Vector2(40, 200))
	# 最后一块平台是 2900~3400，左边缘 2900。
	# 喷火史莱姆原来在 3000（离左边缘 100），按要求改成 1.5 倍 = 150 → 2900 + 150 = 3050。
	# 这样从 2800~2900 的缝隙跳过来、落在平台左端时，有更宽的安全落地区。
	_add_fire_shooter(Vector2(3050, 760), -1.0)

	_add_coin(Vector2(500, 750))
	_add_coin(Vector2(1000, 750))
	_add_coin(Vector2(1500, 750))
	_add_coin(Vector2(2000, 750))
	_add_coin(Vector2(3100, 750))

	_add_checkpoint(Vector2(1500, 780))
	_add_walker(Vector2(1300, 760), 80, 55)
	# 倒数第二块平台（2100~2800）上原来还有一只巡逻的史莱姆，已按需求撤掉：
	# 那块平台是通往最后一块平台和钥匙门的起跳点，落点被怪占着很容易被撞下去。
	_add_finish_flag(finish_position)

	_add_death_zone(1200, -200, 3500)
