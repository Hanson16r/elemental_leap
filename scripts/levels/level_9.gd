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
	# 风场加高到顶面 850；高台往左接到 950，风场顶到高台只差 100，能落上去
	_add_wind_field(Vector2(700, 1150), Vector2(300, 600))
	# 风场之后先落一块空平台：没有怪、没有火，先站稳
	_add_platform(Vector2(1125, 900), 350, 40)    # 950~1300，顶面 880
	# 空平台和下一个平台之间：地火
	_add_flame_jet(Vector2(1350, 880), true, 0.0, 90.0)
	# 下一个平台：放一只巡逻怪
	_add_platform(Vector2(1600, 900), 400, 40)    # 1400~1800，顶面 880
	_add_walker(Vector2(1500, 860), 80, 55)
	_add_key(Vector2(1600, 830))
	_add_key_door(Vector2(1680, 800), Vector2(40, 200))
	_add_sign(Vector2(600, 1380), "站进风场，等它把你托上去")

	_add_coin(Vector2(300, 1470))
	_add_coin(Vector2(700, 1100))
	_add_coin(Vector2(900, 900))
	_add_coin(Vector2(1150, 840))
	_add_coin(Vector2(1450, 830))

	_add_finish_flag(finish_position)
	_add_death_zone(1700, -200, 1900)
