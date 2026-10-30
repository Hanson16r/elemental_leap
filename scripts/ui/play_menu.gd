extends CanvasLayer
## 第二层菜单（点主菜单的「开始游戏」进来）—— 真正决定"怎么玩"的地方：
##   · 顶上一整条「当前角色」+ 右边的「选择角色」按钮
##   · 继续第 N 关 / 从第 1 关重新开始 / 清空进度
##   · 底部一排「关卡 1 2 3 …」（已解锁的可以直接跳过去）
##   · 返回（回第一层）
##
## 关卡按钮是**运行时用代码摆的**，加关卡只改 GameState.TOTAL_LEVELS，
## 这里一行都不用动。

@onready var _title: Label = $Root/Box/Title
@onready var _continue_btn: Button = $Root/Box/ContinueButton
@onready var _start_btn: Button = $Root/Box/StartButton
@onready var _reset_btn: Button = $Root/Box/ResetButton
@onready var _back_btn: Button = $Root/Box/BackButton
@onready var _tip: Label = $Root/Tip
## 标题下方那条「当前角色」：会播 idle 动画，和游戏里站着不动时一模一样
@onready var _preview: AnimatedSprite2D = $Root/Box/CharStrip/Preview
@onready var _preview_name: Label = $Root/Box/CharStrip/PreviewName
@onready var _preview_desc: Label = $Root/Box/CharStrip/PreviewDesc
@onready var _character_btn: Button = $Root/Box/CharStrip/CharacterButton

## 底部"关卡选择"按钮（按 GameState.TOTAL_LEVELS 运行时创建，不用改 .tscn）
var _level_buttons: Array[Button] = []


func _ready() -> void:
	_title.text = "开始游戏"
	_tip.text = "A / D 或 ← → 移动　空格跳跃　R 重开　Esc 暂停"
	_start_btn.pressed.connect(_start)
	_continue_btn.pressed.connect(_continue)
	_reset_btn.pressed.connect(_reset)
	_back_btn.pressed.connect(_back_to_main)
	_character_btn.pressed.connect(_open_character_select)
	_build_level_select()
	_apply_character_preview()
	_refresh()


## 底部一排"1 2 3 …"：点一下直接进那一关（没解锁的会灰掉）
func _build_level_select() -> void:
	var row := HBoxContainer.new()
	row.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	row.offset_left = -510.0
	row.offset_top = -132.0
	row.offset_right = 510.0
	row.offset_bottom = -86.0
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 10)
	$Root.add_child(row)

	var label := Label.new()
	label.text = "关卡"
	label.add_theme_font_size_override("font_size", 16)
	label.add_theme_color_override("font_color", Color(0.63, 0.75, 0.88))
	row.add_child(label)

	for i in GameState.TOTAL_LEVELS:
		var b := Button.new()
		b.text = str(i + 1)
		b.custom_minimum_size = Vector2(60, 40)
		b.add_theme_font_size_override("font_size", 18)
		b.pressed.connect(_on_level_button.bind(i + 1))
		row.add_child(b)
		_level_buttons.append(b)

	# 只在编辑器里出现的调试按钮：一键解锁全部关卡，方便试玩后面的关。
	# 导出成 release（网页/exe）后 OS.is_debug_build() 为 false，这个按钮不会出现。
	if OS.is_debug_build():
		var dbg := Button.new()
		dbg.text = "调试：解锁全部"
		dbg.add_theme_font_size_override("font_size", 14)
		dbg.set_anchors_preset(Control.PRESET_TOP_RIGHT)
		dbg.offset_left = -170.0
		dbg.offset_top = 16.0
		dbg.offset_right = -16.0
		dbg.offset_bottom = 48.0
		dbg.pressed.connect(_unlock_all)
		$Root.add_child(dbg)


## 标题下方的角色条：把玩家选中的那张行走图塞进 AnimatedSprite2D，播 idle。
## 角色表在 scripts/autoload/character_db.gd（Characters 单例）。
func _apply_character_preview() -> void:
	var entry := Characters.selected_entry()
	_preview_name.text = str(entry["name"])
	_preview_desc.text = str(entry["desc"])
	var frames := Characters.build_frames(Characters.selected_id())
	if frames == null:
		_preview.visible = false       # 图丢了就干脆不显示，别留一个空白框
		return
	_preview.sprite_frames = frames
	_preview.play("idle")


## 进「选择角色」界面（单独一个场景，回来时本场景会重新 _ready，预览自动刷新）
func _open_character_select() -> void:
	Sfx.play_click()
	get_tree().change_scene_to_file("res://scenes/ui/character_select.tscn")


func _back_to_main() -> void:
	Sfx.play_click()
	get_tree().change_scene_to_file("res://scenes/ui/main_menu.tscn")


func _refresh() -> void:
	var unlocked := GameState.unlocked_level
	if unlocked > 1:
		_continue_btn.visible = true
		_continue_btn.text = "继续第 %d 关" % unlocked
		_start_btn.text = "从第 1 关重新开始"
	else:
		_continue_btn.visible = false
		_start_btn.text = "开始游戏"

	for i in _level_buttons.size():
		_level_buttons[i].disabled = (i + 1) > unlocked
		# 金币拿满的关卡显示 ★
		_level_buttons[i].text = str(i + 1) + (" ★" if GameState.has_star(GameState.level_id_at(i + 1)) else "")


func _start() -> void:
	Sfx.play_click()
	_go(1)


func _continue() -> void:
	Sfx.play_click()
	_go(GameState.unlocked_level)


func _reset() -> void:
	Sfx.play_click()
	GameState.reset_progress()
	_refresh()


func _go(level: int) -> void:
	get_tree().change_scene_to_file(GameState.level_scene_path(level))


## 底部关卡按钮：没解锁的按钮是 disabled 的，点了也不会进来
func _on_level_button(level: int) -> void:
	if level > GameState.unlocked_level:
		return
	Sfx.play_click()
	_go(level)


## 调试按钮：把进度直接解锁到最后一关（只在编辑器/调试构建里可见）
func _unlock_all() -> void:
	Sfx.play_click()
	GameState.unlocked_level = GameState.TOTAL_LEVELS
	GameState.save_progress()
	_refresh()


## Esc = 回第一层
func _input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		_back_to_main()
		get_viewport().set_input_as_handled()
