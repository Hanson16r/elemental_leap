extends "res://scripts/level_base.gd"
## 关卡 11 ——「分岔」（Y 型：上层冰滑道 3 金币 / 下层史莱姆 2 金币）
##
## ★ 2026-10-25 修正：上层平台原来顶面 640、下层地面 780，中间只剩 100 净空。
##   玩家一跳就撞头（最多只能升 58），下层根本没法跳过史莱姆。
##   按玩家真实尺寸算：碰撞盒高 42、摸高 92，再加上 1.8 倍精灵的视觉高度 86，
##   下层要能"完整跳一次"，上层底面至少要离地 86 + 92 ≈ 178（这里给到 220）。
##
##   改法：把「起点高台 + 上层」整体抬到顶面 520，下层地面保持 780。
##   · 上层底面 560、下层地面 780 → 净空 220（冰面下 240），下层可以放心起跳；
##   · 上层和起点同高，分岔变成「跳过 100 的缺口走上层 / 直接掉下去走下层」，
##     不再需要在低矮空间里往上叠台阶 —— 台阶本身也会变成新的低天花板。
##   · 这样两条路仍然是 Y 型：上层快（冰滑道 + 3 金币），下层稳（史莱姆 + 2 金币），
##     汇合后一起走火盆门。

func _ready() -> void:
	level_number = 11
	level_title = "分岔"
	world_size = Vector2(2400, 1100)
	start_position = Vector2(100, 480)
	finish_position = Vector2(2250, 779)
	super()


func _subtitle() -> String:
	return "第一次选路：上层冰滑道快而险，下层史莱姆稳而慢。"


func _intro_hint() -> String:
	return "两条路都到汇合点；上层 3 金币，下层 2 金币；汇合后火种开门。"


func _build() -> void:
	# ---- 起点高台（顶面 520）----
	_add_platform(Vector2(150, 540), 500, 40)    # -100~400，顶 520
	# ---- 上层：跳过 100 的缺口上冰滑道，3 金币 ----
	_add_platform(Vector2(725, 540), 450, 40)    # 500~950，顶 520
	# 河流（水池/冰桥）原来宽 300（950~1250），按需求延长到 1.5 倍 = 450（950~1400）。
	# 左端不动，右端从 1250 伸到 1400，正好接上下层 1300~1800 的平台上方。
	_add_freeze_pool(Vector2(1175, 520), 450)    # 950~1400，冰面
	_register_surface("static", Vector2(1175, 530), 450, 20, "ice_slide（需冰冻）", Vector2.ZERO)
	# 1 倍处 = 旧河道右端 x=1250：加一个地火（向上喷，间歇，要读节奏）
	_add_flame_jet(Vector2(1250, 520), true, 0.0)
	# ---- 下层：从高台掉下去就是史莱姆走廊，2 金币 ----
	# 顶面 780，和上层底面 560 之间净空 220，起跳不会被挡
	_add_platform(Vector2(900, 800), 1000, 40)   # 400~1400，顶 780
	# ---- 汇合 ----
	_add_platform(Vector2(1550, 800), 500, 40)   # 1300~1800，顶 780
	_add_platform(Vector2(2100, 800), 400, 40)   # 1900~2300，顶 780
	_add_sign(Vector2(330, 440), "上层：冰滑道 / 下层：史莱姆")

	_add_element_orb(Vector2(250, 490), Element.Kind.ICE)
	_add_element_orb(Vector2(1500, 750), Element.Kind.FIRE)
	_add_element_receiver(Vector2(1700, 740), Element.Kind.FIRE, "gate")
	_add_door(Vector2(1900, 680), "gate", Vector2(40, 200))

	_add_coin(Vector2(600, 480))
	_add_coin(Vector2(800, 480))
	_add_coin(Vector2(1100, 480))
	_add_coin(Vector2(500, 750))
	_add_coin(Vector2(1200, 750))

	_add_checkpoint(Vector2(1350, 780))
	_add_walker(Vector2(700, 760), 80, 55)
	_add_walker(Vector2(1000, 760), 100, 60)
	_add_finish_flag(finish_position)
	_add_death_zone(1050, -200, 2500)
