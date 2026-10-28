extends "res://scripts/level_base.gd"
## 关卡 13 ——「火雨」（环型房间：天火/地火交替 + 史莱姆 + 可选钥匙）

func _ready() -> void:
	level_number = 13
	level_title = "火雨"
	world_size = Vector2(2200, 1100)
	start_position = Vector2(120, 700)
	finish_position = Vector2(2100, 779)
	super()


func _subtitle() -> String:
	return "读火焰节奏：灭 → 预警 → 着火；等灭了再过。"


func _intro_hint() -> String:
	return "地火/天火交替；不会两个喷口同时封死唯一通路。"


func _build() -> void:
	_add_platform(Vector2(900, 800), 1600, 40)   # 100~1700
	_add_platform(Vector2(2000, 800), 400, 40)   # 1800~2200
	# 上层平台（天花板）：原来中心 660 → 底面 680，离地（780）净空 100。
	# 按要求把"高度"提到 1.3 倍：净空 100 × 1.3 = 130 → 底面抬到 650 → 中心 660 - 30 = 630。
	_add_platform(Vector2(1000, 630), 600, 40)   # 700~1300，天花板（底面 650）

	# 地火：周期从 2.9 秒拉到 4 秒（灭 2.6 + 预警 0.4 + 着火 1.0）
	_add_flame_jet(Vector2(1000, 780), true, 0.0, 110.0, false, 2.6)
	_add_flame_jet(Vector2(1300, 780), true, 0.5, 110.0, false, 2.6)
	# ---- 2026-10-28 改动一：固定节奏的天火 → 压力板触发的动态火焰 ----
	# 踩下 x=750 的压力板 → 2 秒后天花板火焰落下 → 烧 1.5 秒 → 熄灭；
	# 离开压力板 3 秒后才会重新待机（所以不能站着一直刷）。
	var plate: Area2D = _add_pressure_plate(Vector2(750, 772))
	var trap: Area2D = _add_flame_jet(Vector2(800, 650), false, 0.0, 130.0, true)
	plate.pressed.connect(Callable(trap, "press"))
	plate.released.connect(Callable(trap, "release"))
	# ★ 2026-10-25 按反馈删掉 x=1100 的天火（截图里红框圈出的那个）。
	#   它和 x=1000 的地火只隔 100 像素，两根都是全高火柱，中间只剩 74 像素的空隙；
	#   再加上史莱姆巡逻，这里没有舒服的安全等待位。
	#   剩下 3 个喷口（地火 1000 / 地火 1300 / 天火 800）已经够撑起这一关的节奏。
	#   注意：删的是天花板往下喷的天火，x=1000 的地火还在。
	# _add_flame_jet(Vector2(1100, 680), false, 0.8)

	_add_walker(Vector2(700, 760), 80, 55)
	_add_walker(Vector2(1200, 760), 80, 55)
	_add_coin(Vector2(500, 750))
	_add_coin(Vector2(1500, 750))
	_add_key(Vector2(900, 750))
	_add_key_door(Vector2(1600, 680), Vector2(40, 200))
	_add_element_orb(Vector2(600, 750), Element.Kind.FIRE)
	_add_element_receiver(Vector2(1700, 740), Element.Kind.FIRE, "gate")
	_add_door(Vector2(1900, 680), "gate", Vector2(40, 200))
	_add_checkpoint(Vector2(400, 780))
	_add_finish_flag(finish_position)
	_add_death_zone(1100, -200, 2300)
