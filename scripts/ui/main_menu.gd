extends CanvasLayer
## 主菜单（第一层）：标题 + 副标题 + 四元素展示 + 开始冒险 / 设置 / 退出游戏。
##
## 「开始冒险」进第二层（play_menu.tscn）—— 那页才有「继续第 N 关 / 从第 1 关重开 /
## 清空进度 / 选择角色 / 关卡直跳」，第一层保持只有三个按钮，谁点都不会懵。
##
## 视觉部分：背景三层在 scenes/ui/main_menu.tscn（纯色 + falling_snow 星雪 + menu_fx 剪影/粒子），
## 四元素徽章是 scripts/ui/element_badge.gd（用 _draw() 画的图标，不依赖美术资源）。
## 元素名/说明/配色都在这张 ELEMENTS 表里，改这里就够了。

const BadgeScript := preload("res://scripts/ui/element_badge.gd")

const BTN_SIZE := Vector2(360.0, 54.0)
const KEY_HINT := "A / D 或 ← → 移动　空格跳跃　R 重开　Esc 暂停"
const TIP_COLOR := Color(0.471, 0.584, 0.710)

## 四元素展示：kind / 中文名 / 一句说明 / 目标色（规格里给的颜色）。
## 实际显示色 = 游戏内 Element.color_of(kind) 往目标色混 55% 再提亮一点 ——
## 既跟游戏里捡到的元素球是同一套色系，又比游戏内更亮、更适合当图标。
const ELEMENTS := [
	{
		"kind": Element.Kind.FIRE, "name": "火",
		"desc": "释放炽热力量，烧开冰墙",
		"target": Color(1.0, 0.604, 0.341),
	},
	{
		"kind": Element.Kind.ICE, "name": "冰",
		"desc": "冻结水面与冻池，踩冰过去",
		"target": Color(0.502, 0.875, 1.0),
	},
	{
		"kind": Element.Kind.WIND, "name": "风",
		"desc": "借助气流飞跃高空",
		"target": Color(0.569, 0.910, 0.741),
	},
	{
		"kind": Element.Kind.ROCK, "name": "岩",
		"desc": "操纵岩石，架桥铺路",
		"target": Color(0.847, 0.706, 0.490),
	},
]

@onready var _title: Label = $Root/Stack/TitleWrap/Title
@onready var _subtitle: Label = $Root/Stack/Subtitle
@onready var _badges: HBoxContainer = $Root/Stack/Badges
@onready var _start_btn: Button = $Root/Stack/Buttons/StartButton
@onready var _settings_btn: Button = $Root/Stack/Buttons/SettingsButton
@onready var _quit_btn: Button = $Root/Stack/Buttons/QuitButton
@onready var _tip: Label = $Root/Tip
@onready var _settings: Control = $Root/Settings
@onready var _volume_slider: HSlider = $Root/Settings/Center/Panel/Margin/Box/VolumeRow/VolumeSlider
@onready var _volume_value: Label = $Root/Settings/Center/Panel/Margin/Box/VolumeRow/VolumeValue
@onready var _full_btn: Button = $Root/Settings/Center/Panel/Margin/Box/FullRow/FullButton
@onready var _back_btn: Button = $Root/Settings/Center/Panel/Margin/Box/BackButton

## 每个按钮一条缩放 tween，避免悬停/按下互相打断
var _btn_tweens: Dictionary = {}


func _ready() -> void:
	_subtitle.text = "掌握元素之力，探索奇幻秘境"
	_tip.text = KEY_HINT
	_build_badges()
	_style_buttons()
	_breathe_title()

	_start_btn.pressed.connect(_start)
	_settings_btn.pressed.connect(_open_settings)
	_quit_btn.pressed.connect(_quit)

	_volume_slider.value_changed.connect(_on_volume_changed)
	_full_btn.pressed.connect(_toggle_fullscreen)
	_back_btn.pressed.connect(_close_settings)


# ---------------- 四元素徽章 ----------------

func _build_badges() -> void:
	for i in ELEMENTS.size():
		var entry: Dictionary = ELEMENTS[i]
		var kind: int = int(entry["kind"])
		var target: Color = entry["target"]
		var badge := BadgeScript.new()
		badge.kind = kind
		badge.element_name = str(entry["name"])
		badge.accent = Element.color_of(kind).lerp(target, 0.55).lightened(0.05)
		badge.float_time = 1.0 + 0.15 * float(i)   # 单程时长不同 → 四个浮动自然错开
		badge.hover_changed.connect(_on_badge_hover)
		_badges.add_child(badge)


func _on_badge_hover(badge: Control, on: bool) -> void:
	# 说明写在最底下那行提示里（不用浮层）：浮层会盖住副标题，而这里只改一行字，
	# 位置固定、不会被挡，鼠标停在哪个元素上就显示哪句。
	if not on:
		_tip.text = KEY_HINT
		_tip.add_theme_color_override("font_color", TIP_COLOR)
		return

	var desc := ""
	for entry in ELEMENTS:
		if int(entry["kind"]) == int(badge.kind):
			desc = str(entry["desc"])
	var accent: Color = badge.accent
	_tip.text = "%s · %s" % [badge.element_name, desc]
	_tip.add_theme_color_override("font_color", accent.lightened(0.20))


# ---------------- 按钮外观与反馈 ----------------

func _style_buttons() -> void:
	for b: Button in [_start_btn, _settings_btn, _quit_btn]:
		b.custom_minimum_size = BTN_SIZE
		_button_skin(b)
		b.pivot_offset = b.size * 0.5
		b.resized.connect(func() -> void: b.pivot_offset = b.size * 0.5)
		b.mouse_entered.connect(_scale_button.bind(b, 1.02))
		b.mouse_exited.connect(_scale_button.bind(b, 1.0))
		b.button_down.connect(_scale_button.bind(b, 0.97))
		b.button_up.connect(func() -> void: _scale_button(b, 1.02 if b.is_hovered() else 1.0))

	_button_skin(_full_btn)
	_button_skin(_back_btn)


func _button_skin(b: Button) -> void:
	b.add_theme_font_size_override("font_size", 22 if b.custom_minimum_size.y >= 54.0 else 18)
	b.add_theme_color_override("font_color", Color(0.753, 0.827, 0.910))
	b.add_theme_color_override("font_hover_color", Color(1.0, 1.0, 1.0))
	b.add_theme_color_override("font_pressed_color", Color(0.88, 0.96, 1.0))
	b.add_theme_color_override("font_focus_color", Color(1.0, 1.0, 1.0))
	b.add_theme_stylebox_override("normal", _button_box(Color(0.09, 0.141, 0.227), Color(0.251, 0.325, 0.431), false))
	b.add_theme_stylebox_override("hover", _button_box(Color(0.141, 0.278, 0.404), Color(0.42, 0.737, 0.922), true))
	b.add_theme_stylebox_override("pressed", _button_box(Color(0.11, 0.216, 0.318), Color(0.549, 0.851, 1.0), true))
	b.add_theme_stylebox_override("focus", _button_box(Color(0.141, 0.278, 0.404), Color(0.42, 0.737, 0.922), true))
	b.add_theme_stylebox_override("disabled", _button_box(Color(0.08, 0.12, 0.19), Color(0.2, 0.25, 0.32), false))


func _button_box(bg: Color, border: Color, glow: bool) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.set_corner_radius_all(8)
	sb.set_border_width_all(1)
	sb.border_color = border
	sb.content_margin_left = 12.0
	sb.content_margin_right = 12.0
	if glow:
		sb.shadow_color = Color(0.42, 0.737, 0.922, 0.30)
		sb.shadow_size = 10
	return sb


func _scale_button(b: Button, target: float) -> void:
	var old: Tween = _btn_tweens.get(b)
	if old != null and old.is_valid():
		old.kill()
	var t := create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	t.tween_property(b, "scale", Vector2.ONE * target, 0.15)
	_btn_tweens[b] = t


# ---------------- 标题呼吸 ----------------

func _breathe_title() -> void:
	var base_y := _title.position.y
	var t := create_tween().set_loops()
	t.tween_property(_title, "position:y", base_y - 3.0, 1.5) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	t.tween_property(_title, "position:y", base_y, 1.5) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)


# ---------------- 按钮功能 ----------------

func _start() -> void:
	Sfx.play_click()
	get_tree().change_scene_to_file("res://scenes/ui/play_menu.tscn")


func _quit() -> void:
	Sfx.play_click()
	get_tree().quit()


func _open_settings() -> void:
	Sfx.play_click()
	_settings.visible = true
	_volume_slider.value = Sfx.get_volume()
	_refresh_volume_label()
	_refresh_full_label()


func _close_settings() -> void:
	Sfx.play_click()
	_settings.visible = false


func _on_volume_changed(v: float) -> void:
	Sfx.set_volume(v)
	_refresh_volume_label()


func _refresh_volume_label() -> void:
	_volume_value.text = "%d%%" % roundi(Sfx.get_volume() * 100.0)


func _is_fullscreen() -> bool:
	var mode := DisplayServer.window_get_mode()
	return mode == DisplayServer.WINDOW_MODE_FULLSCREEN \
		or mode == DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN


func _refresh_full_label() -> void:
	_full_btn.text = "切换到窗口模式" if _is_fullscreen() else "切换到全屏"


func _toggle_fullscreen() -> void:
	Sfx.play_click()
	var target := DisplayServer.WINDOW_MODE_WINDOWED if _is_fullscreen() else DisplayServer.WINDOW_MODE_FULLSCREEN
	DisplayServer.window_set_mode(target)
	_refresh_full_label()


func _input(event: InputEvent) -> void:
	if _settings.visible and event.is_action_pressed("ui_cancel"):
		_close_settings()
		get_viewport().set_input_as_handled()
