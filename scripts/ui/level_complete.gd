extends CanvasLayer
## 通关界面 —— 对应 Day 10「通关界面」+ Day 11「每关控制在 30–60 秒通关」
##
## setup() 由关卡脚本在玩家碰到终点旗之后调用，把这一局的成绩传进来。
## 它自己会去 GameState 里读"最好成绩"来对比，告诉玩家有没有破纪录。

var _level_number: int = 1


func setup(level_number: int, title: String, elapsed: float, deaths: int) -> void:
	_level_number = level_number
	process_mode = Node.PROCESS_MODE_ALWAYS

	var box := $Root/Panel/Box
	box.get_node("Title").text = "第 %d 关 · %s —— 通关！" % [level_number, title]
	box.get_node("Time").text = "用时  %s" % GameState.format_time(elapsed)
	var star := GameState.coin_total > 0 and GameState.coins >= GameState.coin_total
	box.get_node("Deaths").text = "死亡  %d 次　金币  %d/%d%s" % [
		deaths, GameState.coins, GameState.coin_total,
		"　★ 全收集" if star else "",
	]

	var best := GameState.best_time(level_number)
	if is_equal_approx(best, elapsed):
		box.get_node("Best").text = "🏆 新纪录！"
		box.get_node("Best").modulate = Color(1.0, 0.86, 0.35)
	else:
		box.get_node("Best").text = "最好成绩  %s" % GameState.format_time(best)
		box.get_node("Best").modulate = Color(0.75, 0.85, 1.0)

	# 没有下一关就把"下一关"按钮藏起来
	var next_btn: Button = box.get_node("NextButton")
	if not GameState.has_next_level():
		next_btn.visible = false
		box.get_node("AllDone").visible = true

	box.get_node("RetryButton").pressed.connect(_retry)
	next_btn.pressed.connect(_next)
	box.get_node("MenuButton").pressed.connect(_to_menu)


func _retry() -> void:
	GameState.deaths = 0
	GameState.elapsed = 0.0
	get_tree().reload_current_scene()


func _next() -> void:
	var next := _level_number + 1
	get_tree().change_scene_to_file("res://scenes/levels/level_%d.tscn" % next)


func _to_menu() -> void:
	get_tree().change_scene_to_file("res://scenes/ui/main_menu.tscn")
