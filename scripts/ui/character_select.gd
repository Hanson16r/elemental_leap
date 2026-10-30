extends CanvasLayer
## 选择角色界面 —— 主菜单点「选择角色」进来，点一张卡片再点确定。
##
## 为什么做成单独一个场景（而不是主菜单里的一个弹窗）：
## 主菜单的按钮区已经很挤，塞 4 张卡片会把「开始游戏」挤没；
## 单独一个场景用 change_scene_to_file 进出，代码最简单，也最好看。
##
## 卡片是**运行时用代码摆的**（和主菜单底部的关卡按钮一样），
## 好处是以后加角色只改 scripts/autoload/character_db.gd 的 ROSTER，
## 这里一行都不用动。
##
## 卡片里的小人用 AnimatedSprite2D 播 idle 动画 —— 和游戏里玩家停下来时的样子一致，
## 选之前就能看见实际效果，不用靠猜。

## 一张卡片的尺寸（像素）。4 张卡 = 4×180 + 3×20（间隔）= 780，居中放在 1152 宽的窗口里
const CARD_SIZE := Vector2(180.0, 240.0)
## 卡片里小人的缩放。行走图单帧 48×48，×3 ≈ 144 像素高（站着时 1.8 倍，这里放大给玩家看清楚）
const PREVIEW_SCALE := Vector2(3.0, 3.0)
## 小人中心在卡片里的纵向位置（卡片高 240，下面 70 像素留给两行字）
const PREVIEW_Y := 92.0

@onready var _grid: GridContainer = $Root/Grid
@onready var _hint: Label = $Root/Hint
@onready var _confirm_btn: Button = $Root/Buttons/ConfirmButton
@onready var _back_btn: Button = $Root/Buttons/BackButton

## 4 张卡片（按钮本体），顺序和 Characters.ROSTER 一一对应
var _cards: Array[Button] = []
## 这次界面上**暂时**选中的角色。点「确定」才真正写进存档，
## 直接点「返回」就当没选过 —— 免得手滑点一下就把角色换了。
var _picked: String = ""


func _ready() -> void:
	_picked = Characters.selected_id()
	_fit_grid()
	_build_cards()
	_confirm_btn.pressed.connect(_on_confirm)
	_back_btn.pressed.connect(_on_back)
	_apply_card_styles()
	_refresh_hint()


## 卡片行宽跟着 ROSTER 的张数算：加/删角色只改 character_db.gd，这里不用动。
## （要是角色回到 5 张以上，一行会超出 1152 宽，把 CARD_SIZE 调小就行。）
func _fit_grid() -> void:
	var count := Characters.ROSTER.size()
	_grid.columns = count
	var sep := float(_grid.get_theme_constant("h_separation"))
	var half := (count * CARD_SIZE.x + (count - 1) * sep) * 0.5
	_grid.offset_left = -half
	_grid.offset_right = half


# ===================================================================== 摆卡片

## 按 ROSTER 的顺序一张一张摆卡片：卡片背景（Button）+ 小人（AnimatedSprite2D）+ 两行字
func _build_cards() -> void:
	for entry in Characters.ROSTER:
		var id := str(entry["id"])

		var card := Button.new()
		card.custom_minimum_size = CARD_SIZE
		card.focus_mode = Control.FOCUS_NONE      # 别抢键盘焦点，键盘操作留给下面的两个按钮
		card.pressed.connect(_on_card_pressed.bind(id))
		_grid.add_child(card)
		_cards.append(card)

		# --- 小人预览（播 idle 动画，和游戏里站着时一模一样）---
		var sprite := AnimatedSprite2D.new()
		var frames := Characters.build_frames(id)
		if frames != null:
			sprite.sprite_frames = frames
			sprite.play("idle")
		sprite.scale = PREVIEW_SCALE
		# Node2D 不吃 Control 的锚点，直接给「卡片中心偏上」的坐标
		sprite.position = Vector2(CARD_SIZE.x * 0.5, PREVIEW_Y)
		card.add_child(sprite)

		# --- 名字 ---
		card.add_child(_make_label(str(entry["name"]), 20,
				Color(0.86, 0.94, 1.0), -66.0, -38.0))
		# --- 一行小字介绍 ---
		card.add_child(_make_label(str(entry["desc"]), 13,
				Color(0.55, 0.68, 0.82), -36.0, -10.0))


## 造一行贴着卡片底部的文字。
## top / bottom 是「距卡片底边多少像素」的负数（-58 ~ -32 就是底部往上那条带）。
func _make_label(text: String, font_size: int, color: Color,
		top: float, bottom: float) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	# 锚点全部拉到底边，再往里收 4 像素，这样文字永远贴着卡片底部
	label.anchor_left = 0.0
	label.anchor_right = 1.0
	label.anchor_top = 1.0
	label.anchor_bottom = 1.0
	label.offset_left = 4.0
	label.offset_right = -4.0
	label.offset_top = top
	label.offset_bottom = bottom
	return label


# ===================================================================== 选中样式

## 把每张卡片的「选中 / 没选中」外观刷一遍
func _apply_card_styles() -> void:
	for i in _cards.size():
		var id := str(Characters.ROSTER[i]["id"])
		_style_card(_cards[i], id == _picked)


## 选中 = 亮蓝粗边框 + 发光；没选中 = 暗色细边框。
## brighten 是鼠标悬停 / 按下时让底色亮一点，给一点"按得动"的反馈。
func _style_card(card: Button, selected: bool) -> void:
	card.add_theme_stylebox_override("normal", _card_box(selected, 0.0))
	card.add_theme_stylebox_override("hover", _card_box(selected, 0.06))
	card.add_theme_stylebox_override("pressed", _card_box(true, 0.12))
	card.add_theme_stylebox_override("focus", StyleBoxEmpty.new())


func _card_box(selected: bool, brighten: float) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	if selected:
		sb.bg_color = Color(0.15, 0.28, 0.42).lightened(brighten)
		sb.border_color = Color(0.55, 0.85, 1.0)
		sb.set_border_width_all(3)
		sb.shadow_color = Color(0.4, 0.7, 1.0, 0.35)   # 外发光 = "这个被选中了"
		sb.shadow_size = 10
	else:
		sb.bg_color = Color(0.10, 0.15, 0.24).lightened(brighten)
		sb.border_color = Color(0.22, 0.32, 0.45)
		sb.set_border_width_all(1)
	sb.set_corner_radius_all(10)
	return sb


# ===================================================================== 交互

func _on_card_pressed(id: String) -> void:
	Sfx.play_click()
	if _picked == id:
		return
	_picked = id
	_apply_card_styles()
	_refresh_hint()


## 顶部那行字 + 确定按钮上的名字，跟着当前选中的角色变
func _refresh_hint() -> void:
	var entry := Characters.get_entry_or_default(_picked)
	_hint.text = "当前选择：%s —— %s" % [str(entry["name"]), str(entry["desc"])]
	_confirm_btn.text = "就选「%s」" % str(entry["name"])


func _on_confirm() -> void:
	Sfx.play_click()
	Characters.select(_picked)      # 写进 GameState 并存档
	_back_to_menu()


func _on_back() -> void:
	Sfx.play_click()
	_back_to_menu()


## 回第二层菜单重新加载整个场景：那边的 _ready 会重新读一次角色，预览自然就更新了
## （选择角色是从「开始游戏 → 选择角色」进来的，所以回第二层，不是回标题画面）
func _back_to_menu() -> void:
	get_tree().change_scene_to_file("res://scenes/ui/play_menu.tscn")


## Esc = 返回（不保存这次的选择）
func _input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		_on_back()
		get_viewport().set_input_as_handled()
