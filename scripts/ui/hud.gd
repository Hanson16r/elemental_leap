extends CanvasLayer
## HUD —— 对应 Day 10「显示当前关卡、死亡次数」「用 reload_current_scene() 实现快速重开」
##
## 这是 CanvasLayer 的子类，所以它永远画在世界上面，不跟着相机跑。
## HUD 自己不计算任何数据，全部从 GameState 这个单例里读——这就是单例的价值：
## 不管在哪一关，GameState.deaths 永远是对的。

## 请求暂停（关卡脚本接住它弹暂停菜单）
signal pause_requested

@onready var _level_label: Label = $Root/TopLeft/LevelLabel
@onready var _death_label: Label = $Root/TopLeft/DeathLabel
@onready var _time_label: Label = $Root/TopRight/TimeLabel
@onready var _best_label: Label = $Root/TopRight/BestLabel
@onready var _hint_label: Label = $Root/Hint
@onready var _fade: ColorRect = $Fade

var _hint_timer: float = 0.0
## 左下角的"手中：火/冰/风"提示（运行时创建，不用改 .tscn）
var _element_label: Label
## 左下角的金币 / 钥匙提示
var _coin_label: Label
var _key_label: Label


func _ready() -> void:
	_fade.color = Color(0.02, 0.03, 0.06, 0.0)
	_fade.visible = false
	_build_element_label()
	_build_collect_labels()
	Events.element_changed.connect(_on_element_changed)
	Events.key_collected.connect(_on_key_collected)
	_on_element_changed(Element.Kind.NONE)
	refresh()


func _build_collect_labels() -> void:
	_coin_label = Label.new()
	_coin_label.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	_coin_label.offset_left = 24.0
	_coin_label.offset_top = -80.0
	_coin_label.offset_right = 260.0
	_coin_label.offset_bottom = -50.0
	_coin_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_coin_label.add_theme_font_size_override("font_size", 18)
	_coin_label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.35))
	$Root.add_child(_coin_label)

	_key_label = Label.new()
	_key_label.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	_key_label.offset_left = 220.0
	_key_label.offset_top = -80.0
	_key_label.offset_right = 400.0
	_key_label.offset_bottom = -50.0
	_key_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_key_label.add_theme_font_size_override("font_size", 18)
	_key_label.add_theme_color_override("font_color", Color(0.98, 0.82, 0.25))
	_key_label.visible = false
	$Root.add_child(_key_label)


func _on_key_collected() -> void:
	if _key_label != null:
		_key_label.text = "钥匙 ✓"
		_key_label.visible = true


## 在左下角建一个文字标签，显示玩家手里拿的元素
func _build_element_label() -> void:
	_element_label = Label.new()
	_element_label.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	_element_label.offset_left = 24.0
	_element_label.offset_top = -46.0
	_element_label.offset_right = 360.0
	_element_label.offset_bottom = -14.0
	_element_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_element_label.add_theme_font_size_override("font_size", 20)
	$Root.add_child(_element_label)


func _on_element_changed(kind: int) -> void:
	if _element_label == null:
		return
	if kind == Element.Kind.NONE:
		_element_label.text = ""
		return
	_element_label.text = "手中：%s" % Element.name_of(kind)
	_element_label.add_theme_color_override("font_color", Element.color_of(kind))


func refresh() -> void:
	_level_label.text = "第 %d 关 · %s" % [GameState.level_position(GameState.current_level), GameState.level_title]
	_death_label.text = "死亡 %d 次" % GameState.deaths
	_time_label.text = "用时 %s" % GameState.format_time(GameState.elapsed)
	var best := GameState.best_time(GameState.current_level)
	if best > 0.0:
		_best_label.text = "最好成绩 %s" % GameState.format_time(best)
	else:
		_best_label.text = ""


func _process(delta: float) -> void:
	_death_label.text = "死亡 %d 次" % GameState.deaths
	_time_label.text = "用时 %s" % GameState.format_time(GameState.elapsed)
	if _coin_label != null:
		_coin_label.text = "金币 %d/%d" % [GameState.coins, GameState.coin_total]

	# 钥匙标记跟着玩家实际状态走：复活清空 has_key 后自动消失
	if _key_label != null:
		var p := get_tree().get_first_node_in_group("player")
		var has_key := p != null and bool(p.get("has_key"))
		_key_label.visible = has_key
		if has_key:
			_key_label.text = "钥匙 ✓"

	if _hint_timer > 0.0:
		_hint_timer -= delta
		if _hint_timer <= 0.0:
			var tw := create_tween()
			tw.tween_property(_hint_label, "modulate:a", 0.0, 0.6)


## 关卡脚本在玩家死亡时立刻调一次，不用等下一帧
func update_deaths() -> void:
	_death_label.text = "死亡 %d 次" % GameState.deaths


func _unhandled_input(event: InputEvent) -> void:
	# ui_cancel 就是 Esc，Godot 默认就绑好了，不用自己加输入映射
	if event.is_action_pressed("ui_cancel"):
		pause_requested.emit()
		get_viewport().set_input_as_handled()


## 在屏幕中央显示一段提示，几秒后自己淡出
func show_hint(text: String, seconds: float = 2.6) -> void:
	_hint_label.text = text
	_hint_label.modulate.a = 1.0
	_hint_timer = seconds


## 黑屏（重生、切关卡时用）
func fade_out(dur: float = 0.25) -> void:
	_fade.visible = true
	var tw := create_tween()
	tw.tween_property(_fade, "color:a", 1.0, dur)
	await tw.finished


func fade_in(dur: float = 0.25) -> void:
	_fade.visible = true
	var tw := create_tween()
	tw.tween_property(_fade, "color:a", 0.0, dur)
	await tw.finished
	_fade.visible = false
