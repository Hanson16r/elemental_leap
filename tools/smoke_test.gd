extends Node
## 冒烟测试：真的把游戏跑起来，模拟按键，看玩家能不能靠"一直向右 + 落地就跳"跑到终点旗。
##
## 这补上了前面几个自检工具的盲区：它们只验算几何和可达性，
## 不检验真实物理、碰撞体、信号连接是不是真的能用。
##
## ⚠️ 实现上的一个坑（我自己踩过）：**不要在这个脚本里调用 change_scene_to_file()**。
## 那样会把这个脚本自己所在的场景换掉，脚本节点被释放，后面的 await 永远不会返回，
## 整个进程就卡死了。正确做法是把每一关 instantiate 出来、add_child 到自己下面，
## 这样宿主节点一直活着，await 才能正常推进。
##
## 用法（注意 APPDATA 必须可写，否则 Godot 会因为 user:// 写不了而卡住）：
##   set APPDATA=<可写目录>
##   Godot_v4.7.2-stable_win64.exe --headless --path <项目> res://scenes/smoke_test.tscn

## 每关最多给 15 秒游戏时间（60 物理帧/秒 × 15）
## 故意用默认的 60 帧/秒：手感参数就是按这个调的，改帧率测出来的不是真实表现
const MAX_TICKS := 900

var _errors: int = 0
var _log: PackedStringArray = []


func _ready() -> void:
	print("")
	print("======= 冒烟测试：真的跑一遍 =======")
	Input.action_press("right")

	for n in [1, 2, 3]:
		await _play_level(n)

	Input.action_release("right")
	print("")
	if _errors == 0:
		print(">>> OK 三关都能靠模拟按键跑到终点旗。")
	else:
		print(">>> BAD 有 ", _errors, " 个问题。")
	print("==================================")
	_write_log()
	get_tree().quit.call_deferred(0 if _errors == 0 else 1)


func _play_level(n: int) -> void:
	print("")
	print("--- 第 ", n, " 关 ---")
	var packed: PackedScene = load("res://scenes/levels/level_%d.tscn" % n)
	var level: Node2D = packed.instantiate()
	add_child(level)                  # 走完整的 _ready（verify_mode 保持 false）
	await get_tree().physics_frame
	await get_tree().physics_frame

	var p: CharacterBody2D = level.get_node_or_null("GameLayer/Player")
	if p == null:
		_fail("第 %d 关没找到 GameLayer/Player" % n)
		_teardown(level)
		return

	var finish_x: float = level.finish_position.x
	var start_deaths: int = GameState.deaths
	var ticks := 0
	var max_x: float = p.global_position.x
	var reached := false
	var deaths_at: Array[float] = []      # 每次死亡的 x 坐标
	var last_deaths: int = GameState.deaths
	var jump_count := 0
	var was_on_floor := true
	var trace: Array[String] = []
	var last_x := p.global_position.x
	var stuck_ticks := 0

	while ticks < MAX_TICKS:
		ticks += 1
		# 卡墙检测：在地面上但 x 半天不动 = 被挡住了（关卡 3 的门就是这样）
		var moved: float = absf(p.global_position.x - last_x)
		if p.is_on_floor() and moved < 0.3:
			stuck_ticks += 1
		else:
			stuck_ticks = 0
		last_x = p.global_position.x

		# 策略：只在前方地面快断了 / 要上台阶 / 被挡住时才跳。
		# 不用"贴地就跳"——那样会一直在原地小跳，永远加速不起来，也就跨不过坑。
		if is_instance_valid(p) and p.is_on_floor() and not p.is_dead():
			if _should_jump(level, p, stuck_ticks > 6):
				Input.action_press("jump")
		else:
			Input.action_release("jump")
		await get_tree().physics_frame
		if not is_instance_valid(p):
			_fail("第 %d 关的玩家节点消失了" % n)
			_teardown(level)
			return
		max_x = maxf(max_x, p.global_position.x)
		if p.is_on_floor() and not was_on_floor:
			jump_count += 1
		was_on_floor = p.is_on_floor()
		# 记录每次死亡发生的位置
		if GameState.deaths != last_deaths:
			last_deaths = GameState.deaths
			deaths_at.append(snappedf(p.global_position.x, 1.0))
			trace.append("死亡于 x=%.0f y=%.0f" % [p.global_position.x, p.global_position.y])
		if p.global_position.x >= finish_x - 40.0:
			reached = true
			break

	Input.action_release("jump")
	var died: int = GameState.deaths - start_deaths

	# 到终点后给场景树几帧时间，让通关界面被创建出来（它是 await 淡出之后才 add_child 的）
	if reached:
		for i in 60:
			await get_tree().physics_frame

	if reached:
		print("  ok    走到终点（x=%.0f，目标 %.0f），%d 个物理帧，中途死亡 %d 次" % [p.global_position.x, finish_x, ticks, died])
	else:
		_fail("第 %d 关没走到终点：只到 x=%.0f（最远 %.0f），目标 %.0f，死亡 %d 次" % [n, p.global_position.x, max_x, finish_x, died])
		var where := PackedStringArray()
		for d in deaths_at:
			where.append("%.0f" % d)
		if where.size() > 0:
			print("       死亡位置 x = [", ", ".join(where), "]")
		print("       最后位置 %.0f，在地面上=%s，起跳次数=%d" % [p.global_position.x, str(p.is_on_floor()), jump_count])
		for t in trace:
			print("       ", t)

	# 确认通关界面真的弹出来了（说明 finish_flag → level_base → GameState 这条信号链是通的）
	var found_screen := false
	for child in level.get_children():
		if child is CanvasLayer and child.get_script() != null:
			if str(child.get_script().resource_path).ends_with("level_complete.gd"):
				found_screen = true
	if reached:
		if found_screen:
			print("  ok    通关界面已弹出（信号链是通的）")
		else:
			_fail("第 %d 关到了终点但通关界面没出现（检查 finish_flag 的 reached 连接）" % n)

	_teardown(level)


func _teardown(level: Node) -> void:
	# 用 free() 而不是 queue_free()：立刻释放，避免多关连跑时攒到退出报 ObjectDB leaked
	remove_child(level)
	level.free()


## 机器人决策：站在地上的时候，前方需不需要跳？
## 用关卡自己登记的落脚面数据来判断 —— 比射线检测简单，而且和关卡设计用同一份数据。
func _should_jump(level: Node2D, p: CharacterBody2D, stuck: bool) -> bool:
	var px: float = p.global_position.x
	var feet: float = p.global_position.y + 21.0        # 脚底（胶囊半高 21）
	const LOOK := 64.0

	var ground_ahead := false          # 前方还有没有地可以走
	var step_above := 0.0              # 前方要上的台阶，高出来多少

	for s in level.surfaces:
		if s["x1"] < px - 4.0 or s["x0"] > px + LOOK:
			continue
		var top: float = s["top"]
		var dy := feet - top           # >0 表示这个面比我脚下低
		# 紧贴脚下的地 → 前方有地
		if s["x0"] <= px + 26.0 and dy >= -8.0 and dy <= 34.0:
			ground_ahead = true
		# 更靠前、且明显更高的面 → 需要跳上去
		if s["x0"] > px + 12.0 and top < feet - 12.0 and top > feet - 76.0:
			step_above = maxf(step_above, feet - top)

	if step_above > 0.0:
		return true                    # 要上台阶
	if stuck:
		return true                    # 被墙挡住了，起跳试试（关卡 3 的门就是靠这个过的）
	return not ground_ahead            # 前方地面断了就跳


func _fail(msg: String) -> void:
	_errors += 1
	print("  FAIL  ", msg)
	_log.append(msg)


## 把结论写进项目里的一个文件，方便外部脚本读取（不用啃 Godot 的 stdout）
func _write_log() -> void:
	var f := FileAccess.open("res://smoke_test_result.txt", FileAccess.WRITE)
	if f == null:
		return
	f.store_line("errors=%d" % _errors)
	for line in _log:
		f.store_line(line)
	f.close()
