extends Node
## 【单例 / 游戏进度存档】—— 对应计划 Day 10「UI 与流程」+ 关键技术实现第 9 条「保存进度」
##
## 用 ConfigFile 存一个小文件，比手写 json 省事。
## 存档位置：Windows 上是 %APPDATA%\Godot\app_userdata\冰塔跳跃 Demo\progress.cfg
## （编辑器里跑的时候可能叫 Godot，导出后会变成游戏名）

const SAVE_PATH := "user://progress.cfg"
const TOTAL_LEVELS := 14

## 已解锁到第几关（1 起算）
var unlocked_level: int = 1
## 每关最好成绩，存的是秒数。{ "1": 32.5, "2": 41.0 }
var best_times: Dictionary = {}
## 每关最多金币数。{ "10": 3, "11": 5 }
var best_coins: Dictionary = {}
## 每关金币总数（用来判断"全收集"星级）。{ "10": 5, "11": 5 }
var coin_totals: Dictionary = {}

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
	unlocked_level = clampi(unlocked_level, 1, TOTAL_LEVELS)
	print("[GameState] 读到存档：已解锁到第 ", unlocked_level, " 关")


func save_progress() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("progress", "unlocked_level", unlocked_level)
	cfg.set_value("progress", "best_times", best_times)
	cfg.set_value("progress", "best_coins", best_coins)
	cfg.set_value("progress", "coin_totals", coin_totals)
	var err := cfg.save(SAVE_PATH)
	if err != OK:
		push_warning("[GameState] 存档写入失败，错误码 " + str(err))
	else:
		print("[GameState] 已存档：已解锁到第 ", unlocked_level, " 关")


func reset_progress() -> void:
	unlocked_level = 1
	best_times = {}
	best_coins = {}
	coin_totals = {}
	save_progress()


func best_time(level: int) -> float:
	return float(best_times.get(str(level), 0.0))


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
	if current_level + 1 > unlocked_level:
		unlocked_level = mini(current_level + 1, TOTAL_LEVELS)
	save_progress()
	Events.level_finished.emit(current_level)


func has_next_level() -> bool:
	return current_level < TOTAL_LEVELS


func all_levels_done() -> bool:
	return unlocked_level >= TOTAL_LEVELS and best_time(TOTAL_LEVELS) > 0.0


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
