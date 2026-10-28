extends "res://scripts/level_base.gd"
## 关卡 9 ——「天空之城」（风场垂直起飞 + 高台 + 喷火史莱姆 + 钥匙门）
## 注意：这一关是竖向风场，几何检查工具不适用，靠真人试玩验收。

func _ready() -> void:
	level_number = 9
	level_title = "天空之城"
	world_size = Vector2(1800, 1800)
	start_position = Vector2(100, 1500)
	finish_position = Vector2(1750, 879)
	super()


func _subtitle() -> String:
	return "风场托你上天；空平台 → 地火 → 带怪的平台 → 钥匙门。"


func _intro_hint() -> String:
	return "风场后先落空平台；跳过地火；下一个平台有怪。"


func _build() -> void:
	_add_platform(Vector2(300, 1520), 600, 40)    # -100~500，顶面 1500

	# ---- 2026-10-28 改动一：单一风场拆成两段，中间留 100 像素横向缺口 ----
	# 第一段 150 宽（x 550~680）：把人从地面托到 y≈1000
	_add_wind_field(Vector2(615, 1225), Vector2(130, 450))     # x 550~680, y 1000~1450
	# 第二段 200 宽（x 780~940）：接住横跳过来的人，再托到高台顶面（880）上方
	_add_wind_field(Vector2(860, 935), Vector2(160, 230))      # x 780~940, y 820~1050

	# ---- 2026-10-28 改动二：高台边缘内缩 50，缩进处放 40% 的微弱风场 + 金币 ----
	_add_platform(Vector2(1150, 900), 300, 40)    # 1000~1300，顶面 880
	_add_platform(Vector2(975, 920), 50, 40)      # 950~1000，缩进台阶，顶面 900
	# 微弱风场放在台阶偏左（x 940~990），这样站在主平台左边缘（x≥1003）不会被误托起来
	_add_wind_field(Vector2(965, 780), Vector2(50, 220), 104.0)  # 670~890，升力 40%

	# 风场之后先落一块空平台：没有怪、没有火，先站稳
	_add_flame_jet(Vector2(1350, 880), true, 0.0, 90.0)
	# 下一个平台：放一只巡逻怪
	_add_platform(Vector2(1600, 900), 400, 40)    # 1400~1800，顶面 880
	_add_walker(Vector2(1500, 860), 80, 55)
	_add_key(Vector2(1600, 830))
	_add_key_door(Vector2(1680, 800), Vector2(40, 200))
	_add_sign(Vector2(600, 1380), "两段风场：升起来→横跳→再升")
	_add_sign(Vector2(910, 1000), "台阶边有股弱风，金币在上面")

	_add_coin(Vector2(300, 1470))
	_add_coin(Vector2(615, 1100))
	_add_coin(Vector2(900, 900))
	_add_coin(Vector2(965, 700))     # 微弱风场里的金币
	_add_coin(Vector2(1150, 840))
	_add_coin(Vector2(1450, 830))

	_add_finish_flag(finish_position)
	_add_death_zone(1700, -200, 1900)
