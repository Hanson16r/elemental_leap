extends "res://scripts/level_base.gd"
## 关卡 1 ——「绿色平原」（新手关：跳坑、金币、史莱姆 → 移动平台 → 钥匙门）
##
## 2026-10-28：原来的第 1 关「绿色平原」和第 2 关「水管与平台」合并成这一关。
## 结构（总长 3200，检查点在中段偏后）：
##   A 0~400       出生安全区，1 枚金币
##   B 400~1020    两个 120 的坑，坑上方各 1 枚金币
##   C 1020~1700   3 只史莱姆 + 1 枚金币，检查点在 1520
##   D 1700~2100   400 的大坑，一块慢慢横移的平台
##   E 2100~3200   钥匙 2300 → 门 2600 → 门后金币 2700 → 终点 2800

func _ready() -> void:
	level_number = 1
	level_title = "绿色平原"
	world_size = Vector2(3200, 1000)
	start_position = Vector2(100, 700)
	finish_position = Vector2(2800, 779)
	super()

func _build() -> void:
	# ---- A 出生安全区 ----
	_add_platform(Vector2(150, 800), 500, 40)     # -100~400

	# ---- B 两个 120 的坑（金币放在坑上方，跳过去顺手吃）----
	_add_platform(Vector2(710, 800), 380, 40)     # 520~900
	_add_platform(Vector2(1360, 800), 680, 40)    # 1020~1700

	# ---- C 史莱姆教学区：只留一只在中间巡逻 ----
	_add_walker(Vector2(1280, 760), 60, 60)

	# ---- D 检查点 + 移动平台大坑 ----
	_add_checkpoint(Vector2(1560, 780))
	_add_moving_platform(Vector2(1900, 780), Vector2(240, 0), 70.0, 130)

	# ---- E 钥匙门 + 终点 ----
	_add_platform(Vector2(2650, 800), 1100, 40)   # 2100~3200
	_add_key(Vector2(2300, 750))
	_add_key_door(Vector2(2600, 680), Vector2(40, 200))
	_add_finish_flag(finish_position)

	# 金币 5 枚：出生区 1、两个坑上方各 1、史莱姆区 1、门后 1
	_add_coin(Vector2(200, 750))
	_add_coin(Vector2(460, 710))
	_add_coin(Vector2(960, 710))
	_add_coin(Vector2(1250, 750))
	_add_coin(Vector2(2700, 750))

	_add_death_zone(1050, -200, 3300)
