extends Node
## 把关卡的"跳跃能力表"打印出来，方便照着设计关卡。
## 数据来源和 tools/verify_levels.gd 完全一致（同样的物理模型）。

const PLAYER_SCRIPT := "res://scripts/player.gd"
const FOOT := 0.0
const SAFETY := 0.85

var _jv := -480.0
var _g := 1250.0
var _fall := 1.35
var _speed := 240.0
var _ratio := 0.5
var _max_fall := 900.0


func _ready() -> void:
	_read()
	print("")
	print("==================== 跳跃能力表 ====================")
	print("起跳 %.0f  重力 %.0f  下落倍率 %.2f  速度 %.0f  空中加速比 %.2f"
		% [_jv, _g, _fall, _speed, _ratio])
	print("摸高 = %.1f 像素（理论上能上升到的最高点）" % (_jv * _jv / (2.0 * _g)))
	print("")
	print("  需要的上升 | 还能横跨的空隙 | 说明")
	print("  ----------+----------------+----------------------------")
	for rise in [0, 5, 10, 15, 20, 25, 30, 35, 40, 45, 50, 60, 70, 80, 90]:
		var gap := _max_gap(float(rise))
		var note := ""
		if rise == 0:
			note = "最宽松：同高度横跨"
		elif gap < 12.0:
			note = "几乎要贴着脸跳"
		elif gap < 25.0:
			note = "台阶要挨很近"
		print("  %5d     |     %5.0f      | %s" % [rise, gap, note])
	print("")
	print("★ 设计关卡时的实用规则 ★（空隙 = 两块平台边缘之间的距离）")
	print("  平跳 / 往下跳 → 空隙最多 146（舒服值 ~100）")
	print("  上升 30        → 空隙最多 134（舒服值 ~90）")
	print("  上升 60        → 空隙最多 118（舒服值 ~75）")
	print("  上升 90        → 空隙最多 89（快摸顶了）")
	print("  上升 > 92      → 跳不上去，拆成两块小台阶或电梯")
	print("")
	print("  ★ 真正要注意的是'够不够得着'，不是'越近越好'。")
	print("     旧版工具把上升段的'最早时刻'当成'最晚时刻'，把 146 算成了 82、")
	print("     把升 30 的 134 算成了 14，所以以前的关卡被压得过分密。")
	print("")
	print("  想跨 100 像素以上的大坑，只有两个办法：")
	print("    1) 中间垫一块平台，把一跳拆成两跳")
	print("    2) 用移动平台（Day 8 的机关）")
	print("===================================================")
	get_tree().quit(0)


func _read() -> void:
	var text := FileAccess.get_file_as_string(PLAYER_SCRIPT)
	if text == "":
		return
	_jv = _grab(text, "jump_velocity", _jv)
	_g = _grab(text, "gravity", _g)
	_fall = _grab(text, "fall_gravity_mult", _fall)
	_speed = _grab(text, "speed", _speed)
	_ratio = _grab(text, "air_accel_ratio", _ratio)
	_max_fall = _grab(text, "max_fall_speed", _max_fall)


func _grab(text: String, name: String, fallback: float) -> float:
	var re := RegEx.new()
	re.compile("var\\s+" + name + "\\s*:\\s*float\\s*=\\s*(-?[0-9.]+)")
	var m := re.search(text)
	if m == null:
		return fallback
	return float(m.get_string(1))


## 和 verify_levels.gd 里同一套模型：从平台边缘、有 12 像素助跑距离起跳。
##
## ★ 旧版 bug 提醒 ★
##   旧版算的是"第一次到达 rise 的时间"（还在上升），把它当成了"最晚时刻"，
##   所以平跳只算到最高点、升 30 只算到刚爬升 30 的那一瞬，结果只有真实值的一半左右。
##   正确做法：总滞空时间 = 上升到最高点 + 从最高点落回目标高度。
func _max_gap(rise: float) -> float:
	var jump_h := _jv * _jv / (2.0 * _g)
	if rise >= jump_h:
		return 0.0

	var t_up := absf(_jv) / _g
	var drop := jump_h - rise
	var t_down := 0.0
	if drop > 0.0:
		t_down = sqrt(2.0 * drop / maxf(_g * _fall, 0.001))
	var t_total := t_up + t_down

	var runup := 12.0
	var accel_ground := _speed * 15.0
	var vx := minf(_speed, sqrt(2.0 * accel_ground * runup))
	var accel_air := accel_ground * _ratio
	var step := 1.0 / 60.0

	var dx := 0.0
	var t := 0.0
	while t < t_total:
		var dt := minf(step, t_total - t)
		vx = minf(_speed, vx + accel_air * dt)
		dx += vx * dt
		t += dt
	return dx * SAFETY


## 同高度、但有充分助跑距离（比如从平台中间开始跑）时的最大横跨距离
func _full_speed_gap() -> float:
	var t := 2.0 * absf(_jv) / _g          # 上升 + 落回同高度的总时间
	var step := 1.0 / 60.0
	var t2 := 0.0
	var vy := _jv
	var dx := 0.0
	while t2 < t:
		t2 += step
		dx += _speed * step
		var g := _g
		if vy > 0.0:
			g *= _fall
		vy = minf(vy + g * step, _max_fall)
	return dx * SAFETY
