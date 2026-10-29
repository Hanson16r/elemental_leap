extends "res://scripts/level_base.gd"
## 关卡 11 ——「冰宫」（冰滑道 + 风场 + 火融冰墙 + 钥匙门 + 三层终点）

func _ready() -> void:
	level_number = 11
	level_title = "冰宫"
	world_size = Vector2(2600, 1800)
	start_position = Vector2(100, 1500)
	finish_position = Vector2(2450, 719)
	super()


func _subtitle() -> String:
	return "冰滑道 → 风场到二层 → 火融冰墙 → 钥匙/锁门 → 三层终点。"


func _intro_hint() -> String:
	return "滑道尽头要跳；风场把你托上二层；钥匙在支路，锁门后是金币房。"


func _build() -> void:
	# 起点平台必须盖住出生点 (100, 1500)。
	# 原来写的是 550 宽 700，只铺到 200~900，出生点 x=100 悬在平台外面，
	# 一进关卡就往下掉、直接摔进死亡区（第 11 关开局的 bug）。
	# 现在保持右端 900 不动，向左延长到原来的 1.3 倍：700 × 1.3 = 910 → -10~900。
	_add_platform(Vector2(445, 1520), 910, 40)   # -10~900，顶 1500（原 200~900，宽 700）
	_add_freeze_pool(Vector2(700, 1500), 400)    # 500~900，冰面
	_register_surface("static", Vector2(700, 1510), 400, 20, "ice_slide（需冰冻）", Vector2.ZERO)
	_add_wind_field(Vector2(1000, 1220), Vector2(170, 360))
	_add_platform(Vector2(1550, 1120), 700, 40)  # 1200~1900，顶 1100

	_add_element_orb(Vector2(250, 1450), Element.Kind.ICE)
	_add_element_orb(Vector2(1300, 1050), Element.Kind.FIRE)
	_add_ice_barrier(Vector2(1500, 1020), Vector2(40, 160))
	_add_key(Vector2(1600, 1050))
	_add_key_door(Vector2(1700, 1020), Vector2(40, 160))

	_add_coin(Vector2(800, 1450))
	_add_coin(Vector2(1100, 1000))
	_add_coin(Vector2(1800, 1050))
	_add_coin(Vector2(1850, 1050))
	_add_coin(Vector2(2100, 650))

	_add_wind_field(Vector2(1900, 900), Vector2(150, 300))
	_add_platform(Vector2(2250, 720), 500, 40)   # 2000~2500，顶 700
	_add_checkpoint(Vector2(850, 1500))
	_add_checkpoint(Vector2(1250, 1100))
	_add_finish_flag(finish_position)
	_add_death_zone(1700, -200, 2700)
