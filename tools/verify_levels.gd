extends Node
## 关卡可达性自检 —— 这是整个项目里最值得保留的一个工具。
##
## 为什么需要它：平台跳跃游戏最致命的 bug 不是崩溃，而是"这一关根本跳不过去"。
## 这种 bug 编辑器**不会报任何错**，你只能靠自己一关一关手玩才能发现。
## 这个脚本把每关的落脚面提取出来，用玩家真实的跳跃物理做一次图的搜索，
## 如果终点从出生点走不到，就直接告诉你断在哪两块平台之间。
##
## 用法：双击项目根目录的「关卡检查.bat」
## 或者：Godot_v4.7.2-stable_win64.exe --headless --path <项目> res://scenes/verify_levels.tscn
##
## ★ 这个工具自己犯过一次大错，值得记下来 ★
##   第一版我用椭圆公式 (空隙/最远)² + (上升/摸高)² ≤ 1 来近似"跳不跳得过去"。
##   它把"上升 60 + 空隙 80"判成了可行，而我照它摆出来的关卡里，
##   真的有一处永远跳不过去。编辑器和"加载检查"全都不会报错，
##   最后是「冒烟测试」里那个只会一直向右跳的机器人反复摔死在同一处才暴露的。
##   现在改成按 60Hz 真实仿真抛体轨迹，和游戏里跑的是同一套物理。

const PLAYER_SCRIPT := "res://scripts/player.gd"
const LEVEL_SCENES := [
	"res://scenes/levels/level_1.tscn",
	"res://scenes/levels/level_2.tscn",
	"res://scenes/levels/level_3.tscn",
	# 第 4 关「天空之城」用竖向风场垂直起飞，不是跳跃；
	# 这个工具只算抛物线跳跃，所以它单独用真人试玩验收。
	"res://scenes/levels/level_5.tscn",
]

## 安全系数：真实极限不该拿来设计关卡，要留操作和反应的余量。
## 0.85 意味着"算出来能跨 100，就只按 85 设计"。
const SAFETY := 0.85
## 起跳前的地面助跑距离（像素）。玩家通常不是在平台正边缘踩点起跳的。
const RUNUP := 12.0
## 下层地面在"上层平台"底下时，头顶至少要留的净空（像素）。
##
## 为什么单列一条：这个工具以前只算"能不能跳到对面"，不算"跳起来会不会撞头"。
## 第 9 关就栽在这上面 —— 上层平台顶面 640、下层地面 780，中间只有 100，
## 玩家在下层一跳就顶到平台底面，根本躲不开史莱姆。
## 真实需要多少：
##   · 碰撞盒高 42 + 摸高 92 = 134，低于这个直接撞；
##   · 精灵放大 1.8 倍后视觉高度约 86，86 + 92 ≈ 178，低于这个"人能过去但头穿模"；
##   · 再留 10 余量 → 189，就按这个当红线。
## 低天花板不一定挡主线（例如第 2 关是故意压低的"火雨天井"），
## 所以这里只打 WARN，不判失败。
const HEADROOM_MIN := 189.0
## 物理帧步长，和项目设置里的 60 tick/秒一致
const STEP := 1.0 / 60.0

var _errors: int = 0

# ---- 从 player.gd 里读出来的真实参数 ----
var _jv: float = -480.0          # 起跳速度（负数向上）
var _gravity: float = 1250.0     # 上升重力
var _fall_mult: float = 1.35     # 下落重力倍率
var _speed: float = 240.0        # 水平最大速度
var _accel_ratio: float = 0.5    # 空中加速相对地面的比例
var _max_fall: float = 900.0     # 最大下落速度


func _ready() -> void:
	print("")
	print("================= 关卡可达性检查 =================")
	_read_player_params()

	print("")
	print("  能力表（本工具自己算出，关卡必须照它设计）：")
	print("    需要的上升 → 能跨的最远空隙")
	var row := "    "
	for rise in [0, 10, 20, 30, 40, 50, 60, 70, 80]:
		row += " %d→%.0f" % [rise, _max_gap_for_rise(float(rise))]
	print(row)
	print("    （已经打了 %.2f 的安全系数，实际还能再宽松一点）" % SAFETY)

	for path in LEVEL_SCENES:
		_check_level(path)

	print("")
	if _errors == 0:
		print(">>> OK 全部关卡都从出生点走得到终点。")
	else:
		print(">>> BAD 发现 ", _errors, " 个问题。")
	print("================================================")
	get_tree().quit(0 if _errors == 0 else 1)


func _fail(msg: String) -> void:
	_errors += 1
	print("  FAIL  ", msg)


# ===================================================================== 参数读取

## 直接从 player.gd 里正则抠参数，这样你调手感参数时这个工具会自动跟着变
func _read_player_params() -> void:
	var text := FileAccess.get_file_as_string(PLAYER_SCRIPT)
	if text == "":
		print("  note  读不到 player.gd，用默认参数继续")
		return
	_jv = _grab(text, "jump_velocity", _jv)
	_gravity = _grab(text, "gravity", _gravity)
	_fall_mult = _grab(text, "fall_gravity_mult", _fall_mult)
	_speed = _grab(text, "speed", _speed)
	_accel_ratio = _grab(text, "air_accel_ratio", _accel_ratio)
	_max_fall = _grab(text, "max_fall_speed", _max_fall)
	print("（player.gd: 起跳 %.0f  重力 %.0f  下落倍率 %.2f  速度 %.0f  空中加速比 %.2f）"
		% [_jv, _gravity, _fall_mult, _speed, _accel_ratio])
	print("  规律：平跳能跨最远；要上升时能跨的距离会变小，但不会掉到个位数。")
	print("  旧版工具把'爬到该高度的最早时刻'当成'最晚时刻'，算出的表只有真实值的一半左右，")
	print("  所以以前的关卡被压得过密。现在按完整抛物线算：平跳约 146，升 30 约 134。")


func _grab(text: String, name: String, fallback: float) -> float:
	var re := RegEx.new()
	re.compile("var\\s+" + name + "\\s*:\\s*float\\s*=\\s*(-?[0-9.]+)")
	var m := re.search(text)
	if m == null:
		return fallback
	return float(m.get_string(1))


# ===================================================================== 跳跃物理

func _jump_h() -> float:
	## 摸高：理论上能上升到的最高点
	return _jv * _jv / (2.0 * _gravity)


func _ground_accel() -> float:
	## player.gd 里地面加速度 = speed × ground_accel_mult（那里写的是 15.0）
	return _speed * 15.0


## 从起跳到"高度 = rise"的**总时间**（包含下落段）。
##
## ★ 这是旧版最大的 bug 所在 ★
##   旧版算的是"第一次到达 rise 的时间"（还在上升），把它当成了"最晚能跨多远"。
##   实际上玩家可以在上升段或下落段任何时刻落到平台上，最晚是"下落段再次到达 rise"。
##   平跳（rise=0）旧版算到最高点就停了，所以把 170 像素算成了 82。
func _time_to_height(rise: float) -> float:
	var apex := _jump_h()
	if rise >= apex:
		return -1.0                      # 超过摸高，永远到不了
	var t_up := absf(_jv) / _gravity     # 上升到最高点的时间
	var drop := apex - rise              # 从最高点还要掉多少
	var t_down := 0.0
	if drop > 0.0:
		var g_down := maxf(_gravity * _fall_mult, 0.001)
		t_down = sqrt(2.0 * drop / g_down)
	return t_up + t_down


## 在"需要上升 rise 像素"的前提下，水平方向一次跳跃最多能跨多少像素。
## 做法：先算出总滞空时间，再按 60Hz 把水平加速积分出来，最后乘安全系数。
func _max_gap_for_rise(rise: float) -> float:
	var t_total := _time_to_height(rise)
	if t_total < 0.0:
		return 0.0

	# 起跳前只给 12 像素助跑，得到的初速度比较保守
	var vx := minf(_speed, sqrt(2.0 * _ground_accel() * RUNUP))
	var accel_air := _ground_accel() * _accel_ratio
	var dx := 0.0
	var t := 0.0
	while t < t_total:
		var dt := minf(STEP, t_total - t)
		vx = minf(_speed, vx + accel_air * dt)
		dx += vx * dt
		t += dt
	return dx * SAFETY


## 水平方向两块平台之间的空隙（边缘到边缘）
func _h_gap(a: Dictionary, b: Dictionary) -> float:
	var a0: float = a["x0"]
	var a1: float = a["x1"]
	var b0: float = b["x0"]
	var b1: float = b["x1"]
	if b0 > a1:
		return b0 - a1
	if a0 > b1:
		return a0 - b1
	return 0.0


## 需要上升多少像素（负数表示往下跳）
func _need_rise(a: Dictionary, b: Dictionary) -> float:
	var top_a: float = a["top"]
	var ymax_b: float = b["ymax"]
	var ymin_b: float = b["ymin"]
	return minf(top_a - ymax_b, top_a - ymin_b)


## 返回空字符串表示"跳得过去"，否则返回被拒绝的原因
func _jump_reject_reason(a: Dictionary, b: Dictionary) -> String:
	var gap := _h_gap(a, b)
	var rise := _need_rise(a, b)

	if rise >= _jump_h():
		return "需要上升 %.0f 像素，超过摸高 %.0f，跳不上去" % [rise, _jump_h()]

	var limit := _max_gap_for_rise(maxf(rise, 0.0))
	if gap > limit:
		if rise <= 0.0:
			return "水平空隙 %.0f > 上限 %.0f（同高度或往下跳）" % [gap, limit]
		return "需要上升 %.0f，此时水平最多只能走 %.0f，但空隙有 %.0f" % [rise, limit, gap]
	return ""


func _can_jump_between(a: Dictionary, b: Dictionary) -> bool:
	return _jump_reject_reason(a, b) == ""


## 两个面是不是同一块移动平台的两个端点（坐上去会被载过去，不用跳）
func _same_mover(a: Dictionary, b: Dictionary) -> bool:
	var ida: String = str(a.get("mover_id", ""))
	var idb: String = str(b.get("mover_id", ""))
	return ida != "" and ida == idb


# ===================================================================== 单关检查

func _check_level(path: String) -> void:
	print("")
	print("--- ", path, " ---")

	var scene: PackedScene = load(path)
	if scene == null:
		_fail("场景加载失败")
		return
	var level: Node2D = scene.instantiate()
	level.verify_mode = true      # 只建关卡内容，不建 HUD / 玩家 / 粒子
	# request_ready() + add_child() 会让 _ready() 在 add_child 里**同步**执行，不需要等下一帧。
	# 这一点很关键：Godot 在 user:// 写不了的时候（受限环境）跨帧推进可能会卡死，
	# 所以整个检查必须在第一帧里跑完。
	level.request_ready()
	add_child(level)

	var surfaces: Array = level.surfaces if "surfaces" in level else []
	if surfaces.is_empty():
		_fail("没有拿到任何落脚面（level_base.gd 的 _register_surface 是不是没生效？）")
		_cleanup_level(level)
		return

	print("  共 ", surfaces.size(), " 个落脚面")
	for i in surfaces.size():
		var s: Dictionary = surfaces[i]
		print("    #%-2d 顶面 %-4.0f x %-5.0f~%-5.0f  %s" % [i, s["top"], s["x0"], s["x1"], s["label"]])

	# 收集火焰的水平范围，用来检查"有没有落脚面正好压在火上"
	var flames: Array = []
	_collect_flames(level, flames)

	# 起点
	var start: Vector2 = level.start_position
	var finish: Vector2 = level.finish_position
	var start_idx := _surface_below(surfaces, start, 260.0)
	if start_idx < 0:
		_fail("出生点 (%.0f, %.0f) 下方 260 像素内没有落脚面，玩家会直接掉下去" % [start.x, start.y])

	# BFS：从出生点能走到哪些面
	var reached := {}
	if start_idx >= 0:
		reached[start_idx] = true
	var queue: Array[int] = []
	if start_idx >= 0:
		queue.append(start_idx)

	while not queue.is_empty():
		var i: int = queue.pop_front()
		for j in surfaces.size():
			if reached.has(j):
				continue
			if _same_mover(surfaces[i], surfaces[j]) or _can_jump_between(surfaces[i], surfaces[j]):
				reached[j] = true
				queue.append(j)

	var reach_names := PackedStringArray()
	for k in reached.keys():
		reach_names.append("#" + str(k))
	print("  从出生点可达 ", reached.size(), " / ", surfaces.size(), " 个落脚面：", ", ".join(reach_names))

	# 头顶净空：下层站在地板上起跳，会不会撞到上层的底面
	_check_headroom(surfaces, reached)

	# 掉落死亡区有没有盖住整关（第 12 关的"缝隙掉下去死不了"就是这里漏的）
	_check_death_zone(level, surfaces)

	# 打印断点诊断，只打印前若干条，避免刷屏
	var broken := 0
	for i in surfaces.size():
		if not reached.has(i):
			continue
		for j in surfaces.size():
			if reached.has(j):
				continue
			var why := _jump_reject_reason(surfaces[i], surfaces[j])
			if why != "":
				broken += 1
				if broken <= 8:
					print("    跳不过去 #%d → #%d：%s" % [i, j, why])
	if broken > 8:
		print("    ...（另有 ", broken - 8, " 条同类诊断，多半是跳到远处平台的正常失败）")

	# 调试：如果某个面在链上看起来"应该够得着"却不可达，把它的细节打出来
	if start_idx >= 0 and reached.size() < surfaces.size():
		print("    [dbg] 摸高=%.1f  平跳上限=%.1f  上升30上限=%.1f"
			% [_jump_h(), _max_gap_for_rise(0.0), _max_gap_for_rise(30.0)])
		for j in surfaces.size():
			if reached.has(j):
				continue
			# 找最近的一个可达面
			var best_i := -1
			var best_gap := 1e9
			for i in reached.keys():
				var g := _h_gap(surfaces[i], surfaces[j])
				if g < best_gap:
					best_gap = g
					best_i = i
			if best_i >= 0:
				print("    [dbg] #%d 最近可达面 #%d：空隙 %.0f 上升 %.0f → %s"
					% [j, best_i, best_gap, _need_rise(surfaces[best_i], surfaces[j]),
					   _jump_reject_reason(surfaces[best_i], surfaces[j])])

	# 终点检查
	var finish_ok := false
	for i in reached.keys():
		if _finish_on_surface(finish, surfaces[i]):
			finish_ok = true
			break
	if finish_ok:
		print("  ok    终点旗有可达的落脚面")
	else:
		_fail("终点不可达 —— 要么旗子下方没有落脚面，要么那个面走不到")

	# 火焰有没有压在可达的落脚面上
	for idx in reached.keys():
		var s: Dictionary = surfaces[idx]
		for f in flames:
			var overlap_x: bool = s["x1"] > f["x0"] + 4.0 and s["x0"] < f["x1"] - 4.0
			var overlap_y: bool = f["top"] < s["top"] and f["bottom"] > s["top"] - 4.0
			if overlap_x and overlap_y:
				_fail("可达落脚面（x %.0f~%.0f，顶面 %.0f）上有火焰，站上去必死" % [s["x0"], s["x1"], s["top"]])
				break

	# 每扇门有没有对应的按钮
	var buttons := _collect_buttons(level)
	for s in surfaces:
		if s["kind"] == "door":
			var id: String = str(s["label"]).replace("door:", "")
			if buttons.has(id):
				print("  ok    门 ", id, " 有对应的按钮")
			else:
				_fail("门 %s 没有对应的按钮，玩家会被永久挡住" % id)

	_cleanup_level(level)


## 检查"下层这条路上方有没有压得太低的上层平台"。
##
## 只拿**固定平台/冰面**当天花板：移动平台和闪烁平台的位置本身在变，
## 拿它当静态天花板会误报；同一条下层路面的重复登记（比如水面和冰面同高）也不算。
func _check_headroom(surfaces: Array, reached: Dictionary) -> void:
	var warned := 0
	for i in reached.keys():
		var a: Dictionary = surfaces[i]
		var a_top: float = a["top"]
		for j in surfaces.size():
			if i == j:
				continue
			var b: Dictionary = surfaces[j]
			if str(b.get("kind", "")) != "static":
				continue
			# 必须是"在上方"的面（b 的顶面更高 = y 更小）
			if float(b["top"]) >= a_top - 1.0:
				continue
			# 水平方向要真的重叠（擦边 4 像素以内不算）
			if float(b["x1"]) <= float(a["x0"]) + 4.0 or float(b["x0"]) >= float(a["x1"]) - 4.0:
				continue
			if not b.has("bottom"):
				continue
			# 底面已经低于（或等于）下面的地面 → 它不是"天花板"，而是台阶/埋在地里的东西
			# （岩石柱登记的是一个 200 高的假面，底面埋在地面以下，不能当天花板算）
			if float(b["bottom"]) >= a_top:
				continue
			var clearance: float = a_top - float(b["bottom"])
			if clearance >= HEADROOM_MIN:
				continue
			warned += 1
			if warned <= 6:
				print("    WARN  #%d（%s）头顶被 #%d（%s）压住：净空只有 %.0f < %.0f，在这里起跳会撞头"
					% [i, a["label"], j, b["label"], clearance, HEADROOM_MIN])
	if warned > 0:
		print("    WARN  共 %d 处净空不足（不判失败：低天花板不一定挡主线，但玩家在这里跳会撞头）" % warned)


## 掉落死亡区必须把**整关所有落脚面**的水平范围都盖住。
##
## ★ 这条检查是补上一个真实事故的 ★
##   第 12 关"最后一块平台和倒数第二块平台之间掉下去不会死"：
##   death_zone.tscn 的 CollisionShape2D 里没有 shape，形状是 _ready() 里按 zone_size 建的，
##   而关卡基类当时先 add_child() 再 setup(size) —— add_child() 同步触发 _ready()，
##   形状就永远定在了默认的 2400 宽。第 12 关宽 3400，最右边 550 像素全是无底洞。
##   现在形状的建法修了，这条检查负责防止它再退回去。
func _check_death_zone(level: Node, surfaces: Array) -> void:
	var zone: Node2D = null
	for child in level.game_layer.get_children():
		if child.get_script() != null and str(child.get_script().resource_path).ends_with("death_zone.gd"):
			zone = child
			break
	if zone == null:
		_fail("没有掉落死亡区：掉出地图会一直往下掉，游戏看起来像卡死")
		return

	var size := Vector2.ZERO
	var col := zone.get_node_or_null("CollisionShape2D") as CollisionShape2D
	if col != null and col.shape is RectangleShape2D:
		size = (col.shape as RectangleShape2D).size
	if size.x < 1.0 or size.y < 1.0:
		_fail("掉落死亡区的碰撞形状是 %s —— shape 没建出来，掉下去不会死" % str(size))
		return

	var left: float = zone.global_position.x - size.x * 0.5
	var right: float = zone.global_position.x + size.x * 0.5
	var min_x := INF
	var max_x := -INF
	for s in surfaces:
		min_x = minf(min_x, float(s["x0"]))
		max_x = maxf(max_x, float(s["x1"]))

	if left > min_x + 1.0 or right < max_x - 1.0:
		_fail("掉落死亡区只盖住 x %.0f~%.0f，落脚面却铺到 x %.0f~%.0f —— 没有死亡区的那一段掉下去不会死"
			% [left, right, min_x, max_x])
	else:
		print("  ok    掉落死亡区盖住 x %.0f~%.0f（落脚面 x %.0f~%.0f）" % [left, right, min_x, max_x])


## 终点旗是不是落在这个面上（x 在范围内，且面顶和旗底差不多高）
func _finish_on_surface(finish: Vector2, s: Dictionary) -> bool:
	var x0: float = s["x0"]
	var x1: float = s["x1"]
	var top: float = s["top"]
	if finish.x < x0 - 10.0 or finish.x > x1 + 10.0:
		return false
	return absf(top - finish.y) < 90.0


## 出生点下方最近的一个面
func _surface_below(surfaces: Array, p: Vector2, max_dy: float) -> int:
	var best := -1
	var best_dy := max_dy
	for i in surfaces.size():
		var s: Dictionary = surfaces[i]
		if p.x < s["x0"] - 10.0 or p.x > s["x1"] + 10.0:
			continue
		var dy: float = s["top"] - p.y
		if dy >= -20.0 and dy < best_dy:
			best_dy = dy
			best = i
	return best


## 验证用的关卡要立刻释放，不能用 queue_free()。
## 用 queue_free() 会攒到帧末才释放，多关连跑容易在引擎退出时报
## "ObjectDB instances were leaked" 甚至直接崩掉。
func _cleanup_level(level: Node) -> void:
	if is_instance_valid(level):
		level.free()


func _collect_flames(level: Node, out: Array) -> void:
	for child in level.game_layer.get_children():
		if child.get_script() != null and str(child.get_script().resource_path).ends_with("flame.gd"):
			var h: float = child.flame_size.y
			var w: float = child.flame_size.x
			out.append({
				"top": child.global_position.y - h,
				"bottom": child.global_position.y,
				"x0": child.global_position.x - w * 0.5,
				"x1": child.global_position.x + w * 0.5,
			})


func _collect_buttons(level: Node) -> Dictionary:
	var ids := {}
	for child in level.game_layer.get_children():
		if child.get_script() != null and str(child.get_script().resource_path).ends_with("button.gd"):
			ids[child.door_id] = true
	return ids
