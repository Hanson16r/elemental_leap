extends Node
## 【单例 / 游戏进度存档】—— 对应计划 Day 10「UI 与流程」+ 关键技术实现第 9 条「保存进度」
##
## 用 ConfigFile 存一个小文件，比手写 json 省事。
## 存档位置：Windows 上是 %APPDATA%\Godot\app_userdata\冰塔跳跃 Demo\progress.cfg
## （编辑器里跑的时候可能叫 Godot，导出后会变成游戏名）

const SAVE_PATH := "user://progress.cfg"
## 关卡出场顺序：第 i 个元素 = 第 i+1 关加载哪个关卡文件（level_<编号>.tscn）。
## 想调整关卡先后顺序只改这一行，把编号换个位置即可：
##   例：想先玩「天空之城」(4)、再玩「分岔」(3) → [1, 2, 4, 3, 5, ...]
## 文件名、脚本里的 level_number、存档都不用动：存档按关卡编号（身份）记，
## 编号不会因为换顺序而变；界面上显示的「第几关」按位置算。
const LEVEL_ORDER := [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11]
## 关卡总数。加/删关卡时和 LEVEL_ORDER 一起改（= LEVEL_ORDER.size()）。
const TOTAL_LEVELS := 11
## 存档格式版本。4 = 删掉「火之花」并重排 3/4 关之后的编号。
const SAVE_VERSION := 4

## 已解锁到第几关（1 起算）
var unlocked_level: int = 1
## 每关最好成绩，存的是秒数。{ "1": 32.5, "2": 41.0 }
var best_times: Dictionary = {}
## 每关最多金币数。{ "10": 3, "11": 5 }
var best_coins: Dictionary = {}
## 每关金币总数（用来判断"全收集"星级）。{ "10": 5, "11": 5 }
var coin_totals: Dictionary = {}
## 玩家在「选择角色」里选中的人物 id（角色表在 scripts/autoload/character_db.gd 的 ROSTER）。
## 空字符串 = 还没选过，那边会自动回落到默认角色。
## 它也是一个普通的存档项：跟着关卡进度存在同一个 progress.cfg 里，
## 但**不受 SAVE_VERSION 影响** —— 旧存档没有这一项时，读出来是空串，正好走默认值。
var character_id: String = ""

# ---------------- 一局内的收集品 ----------------
## 这一关当前吃到的金币数
var coins: int = 0
## 这一关一共摆了多少金币（关卡在 _add_coin 时累加）
var coin_total: int = 0

# ---------------- 一次游戏过程中的临时状态（不存档） ----------------
var current_level: int = 1
var level_title: String = "关卡 1"
var spawn_position: Vector2 = Vector2.ZERO
var elapsed: float = 0.0
var deaths: int = 0
var running: bool = false


func _ready() -> void:
	load_progress()


# ===================================================================== 存档读写

func load_progress() -> void:
	var cfg := ConfigFile.new()
	var err := cfg.load(SAVE_PATH)
	if err != OK:
		# 第一次玩，没有存档，用默认值就行，不是错误
		unlocked_level = 1
		best_times = {}
		return

	unlocked_level = int(cfg.get_value("progress", "unlocked_level", 1))
	best_times = cfg.get_value("progress", "best_times", {})
	best_coins = cfg.get_value("progress", "best_coins", {})
	coin_totals = cfg.get_value("progress", "coin_totals", {})
	character_id = str(cfg.get_value("progress", "character", ""))
	var version := int(cfg.get_value("meta", "version", 1))
	# 旧存档逐步迁移到当前编号：每一步只搬关号，不动成绩本身。
	#  v1→v2：删掉第 4 关「冰之谷」，后面的关号前移一位。
	#  v2→v3：合并第 1、2 关，终章挪到最后。
	#  v3→v4：删掉「火之花」，「分岔」「天空之城」前移，其余顺延。
	if version < 2:
		_migrate_v1_to_v2()
	if version < 3:
		_migrate_v2_to_v3()
	if version < 4:
		_migrate_v3_to_v4()
	if version < SAVE_VERSION:
		save_progress()
	unlocked_level = clampi(unlocked_level, 1, TOTAL_LEVELS)
	print("[GameState] 读到存档：已解锁到第 ", unlocked_level, " 关")


func save_progress() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("meta", "version", SAVE_VERSION)
	cfg.set_value("progress", "unlocked_level", unlocked_level)
	cfg.set_value("progress", "best_times", best_times)
	cfg.set_value("progress", "best_coins", best_coins)
	cfg.set_value("progress", "coin_totals", coin_totals)
	cfg.set_value("progress", "character", character_id)
	var err := cfg.save(SAVE_PATH)
	if err != OK:
		push_warning("[GameState] 存档写入失败，错误码 " + str(err))
	else:
		print("[GameState] 已存档：已解锁到第 ", unlocked_level, " 关")


## 清空进度：关卡解锁、成绩、金币全部归零。
## 选中的角色**故意保留** —— 那是外观偏好，不是进度，清进度不该把人物也换掉。
func reset_progress() -> void:
	unlocked_level = 1
	best_times = {}
	best_coins = {}
	coin_totals = {}
	save_progress()


## 旧存档（v1）→ 新编号（v2）：
## 第 4 关「冰之谷」已删除，原来第 5~14 关现在的编号是第 4~13 关。
## 已解锁进度和每关成绩都整体前移一位，删掉那关自己的记录。
func _migrate_v1_to_v2() -> void:
	const DELETED_LEVEL := 4
	if unlocked_level > DELETED_LEVEL:
		unlocked_level -= 1
	best_times = _shift_level_keys(best_times, DELETED_LEVEL)
	best_coins = _shift_level_keys(best_coins, DELETED_LEVEL)
	coin_totals = _shift_level_keys(coin_totals, DELETED_LEVEL)


## 把字典里 "5"~"14" 这样的关号键整体减 1，并丢掉被删掉那一关的键。
static func _shift_level_keys(src: Dictionary, deleted_level: int) -> Dictionary:
	var out: Dictionary = {}
	for key in src.keys():
		var level := int(str(key))
		if level == deleted_level:
			continue
		var new_key := str(level - 1) if level > deleted_level else str(level)
		out[new_key] = src[key]
	return out


## 旧存档（v2）→ 新编号（v3）：
##   · 第 1、2 关合并成新的第 1 关（旧成绩没法沿用，直接丢掉）；
##   · 「火雨」从第 12 关挪到第 2 关；
##   · 「终章：元素城堡」从第 9 关挪到最后（第 12 关）；
##   · 原第 3~8 关不动（仍是 3~8），原第 10、11 关前移成 9、10，原第 13 关前移成 11。
func _migrate_v2_to_v3() -> void:
	# 每个旧关号在 v3 里的位置。1、2 关合并后没有单独记录，不列在表里。
	const RECORD_MAP := {
		3: 3, 4: 4, 5: 5, 6: 6, 7: 7, 8: 8,
		9: 12, 10: 9, 11: 10, 12: 2, 13: 11,
	}
	best_times = _map_level_keys(best_times, RECORD_MAP)
	best_coins = _map_level_keys(best_coins, RECORD_MAP)
	coin_totals = _map_level_keys(coin_totals, RECORD_MAP)
	# 解锁进度按“已通关数量”顺移：第 1、2 关合并少了一关，其余保持原来的先后。
	# 旧档 1~2 关没完整打通 → 从新第 1 关开始；3 关以上 → 新关号比旧关号小 1。
	unlocked_level = _map_unlocked_v3(unlocked_level)


## 旧档的"下一关"换成新编号。第 1、2 关合并后总数少 1，所以从第 3 关起整体 -1。
static func _map_unlocked_v3(level: int) -> int:
	return maxi(1, mini(level - 1, 12))


## 旧存档（v3）→ 新编号（v4）：
##   · 第 3 关「火之花」已删除；
##   · 「分岔」从第 9 关挪到第 3 关，「天空之城」从第 8 关挪到第 4 关；
##   · 其余顺延：4~7 → 5~8，10~12 → 9~11。
func _migrate_v3_to_v4() -> void:
	# 每个旧关号在 v4 里的位置。被删掉的第 3 关不列，它的成绩直接丢弃。
	const RECORD_MAP := {
		1: 1, 2: 2,
		4: 5, 5: 6, 6: 7, 7: 8,
		8: 4, 9: 3,
		10: 9, 11: 10, 12: 11,
	}
	best_times = _map_level_keys(best_times, RECORD_MAP)
	best_coins = _map_level_keys(best_coins, RECORD_MAP)
	coin_totals = _map_level_keys(coin_totals, RECORD_MAP)
	# 解锁进度按“已通关数量”顺移：删掉第 3 关后，进度超过它的整体 -1。
	unlocked_level = maxi(1, mini(unlocked_level - (1 if unlocked_level > 3 else 0), TOTAL_LEVELS))


## 按映射表搬运字典里的关号键；没有映射的键（例如被合并掉的第 1、2 关）就丢弃。
static func _map_level_keys(src: Dictionary, mapping: Dictionary) -> Dictionary:
	var out: Dictionary = {}
	for key in src.keys():
		var level := int(str(key))
		if not mapping.has(level):
			continue
		out[str(mapping[level])] = src[key]
	return out


func best_time(level: int) -> float:
	return float(best_times.get(str(level), 0.0))


# ===================================================================== 关卡顺序
# 「position」= 玩家眼里的第几关（1 起算，受 LEVEL_ORDER 影响）；
# 「level_id」= 关卡文件的编号（level_<编号>.tscn，也是存档里的键，换顺序不变）。

## 第 position 关实际加载哪个关卡文件编号
static func level_id_at(position: int) -> int:
	if position < 1 or position > LEVEL_ORDER.size():
		return position
	return int(LEVEL_ORDER[position - 1])


## 关卡文件编号现在是第几关；不在顺序表里（比如调试时单独加载）就按编号原样算
static func level_position(level_id: int) -> int:
	var index := LEVEL_ORDER.find(level_id)
	return index + 1 if index >= 0 else level_id


## 第 position 关的场景路径
static func level_scene_path(position: int) -> String:
	return "res://scenes/levels/level_%d.tscn" % level_id_at(position)


func best_coin(level: int) -> int:
	return int(best_coins.get(str(level), 0))


## 这一关是否全收集（金币拿满）→ 关卡选择显示 ★
func has_star(level: int) -> bool:
	var total := int(coin_totals.get(str(level), 0))
	return total > 0 and best_coin(level) >= total


## 吃到一枚金币。HUD / 通关界面读 coins。
func add_coin() -> void:
	coins += 1
	Events.coin_collected.emit(coins)


# ===================================================================== 关卡流程

## 进入某一关时调用，把这一局的临时状态清零
func start_level(level: int, title: String, spawn: Vector2) -> void:
	current_level = level
	level_title = title
	spawn_position = spawn
	elapsed = 0.0
	deaths = 0
	coins = 0
	coin_total = 0
	running = true
	Events.level_started.emit(level, title)


## 死亡：次数 +1，回检查点。时间**不清零**（这样用时才有意义，也是"别让死亡惩罚太重"的折中）
func register_death() -> void:
	deaths += 1


func register_checkpoint(pos: Vector2) -> void:
	spawn_position = pos


## 通关：记录用时、更新最好成绩、解锁下一关
func complete_level() -> void:
	running = false
	var key := str(current_level)
	var old := float(best_times.get(key, 0.0))
	if old <= 0.0 or elapsed < old:
		best_times[key] = elapsed
	var old_coins := int(best_coins.get(key, 0))
	if coins > old_coins:
		best_coins[key] = coins
	coin_totals[key] = coin_total
	# 解锁按「位置」算：打完第 position 关就解锁 position + 1
	var position := level_position(current_level)
	if position + 1 > unlocked_level:
		unlocked_level = mini(position + 1, TOTAL_LEVELS)
	save_progress()
	Events.level_finished.emit(current_level)


func has_next_level() -> bool:
	return level_position(current_level) < TOTAL_LEVELS


func all_levels_done() -> bool:
	return unlocked_level >= TOTAL_LEVELS and best_time(level_id_at(TOTAL_LEVELS)) > 0.0


## 把秒数格式化成 12.34 秒 / 1 分 05.20 秒
static func format_time(t: float) -> String:
	var m := int(t) / 60
	var s := t - float(m * 60)
	if m > 0:
		return "%d 分 %05.2f 秒" % [m, s]
	return "%.2f 秒" % t


# ===================================================================== _process

func _process(delta: float) -> void:
	if running and not get_tree().paused:
		elapsed += delta
