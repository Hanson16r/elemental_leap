extends Control
## 主菜单上的一个元素徽章：半透明圆角底板 + 元素图标 + 元素名。
##
## 为什么图标是代码画的而不是图片：项目里没有元素图标素材，四张 PNG 也不值得
## 为菜单单独做；而且用代码画能跟着元素配色一起变，以后调颜色只改
## main_menu.gd 里的一张表。
##
## 坑：图标**不能**用外层 Control 连 CanvasItem 的 draw 信号来画（信号会触发，
## 但画出来的东西不进渲染，实测 4 张卡片全空）。图标必须放在自己实现了
## _draw() 的节点上，所以有了 scripts/ui/element_icon.gd。
##
## 动画分工：底板/名字不动，只有里面的图标上下浮，避免整块卡片在
## HBoxContainer 里抖（容器会覆盖子节点的 position，所以浮动的必须是内层节点）。

signal hover_changed(badge: Control, on: bool)

const CARD := Vector2(104.0, 116.0)
const ICON := Vector2(72.0, 72.0)
const ICON_TOP := 8.0
const FLOAT_PX := 4.0
const IconScript := preload("res://scripts/ui/element_icon.gd")

var kind: int = Element.Kind.FIRE
var element_name: String = "火"
var accent: Color = Color(1.0, 0.6, 0.34)
## 浮动周期（秒 / 单程）：四个徽章取不同值，自然错开
var float_time: float = 1.4

var _panel: Panel
var _icon: Control
var _name_label: Label
var _style_normal: StyleBoxFlat
var _style_hover: StyleBoxFlat
var _hover_tween: Tween


func _ready() -> void:
	custom_minimum_size = CARD
	size = CARD
	pivot_offset = CARD * 0.5
	mouse_filter = Control.MOUSE_FILTER_STOP
	_build()
	mouse_entered.connect(_set_hover.bind(true))
	mouse_exited.connect(_set_hover.bind(false))
	_start_float()


func _build() -> void:
	_style_normal = _make_style(false)
	_style_hover = _make_style(true)

	_panel = Panel.new()
	_panel.name = "Card"
	_panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_panel.add_theme_stylebox_override("panel", _style_normal)
	add_child(_panel)

	# 图标是独立脚本的节点：这一层可以自由改 position（浮动的就是它）
	_icon = IconScript.new()
	_icon.name = "Icon"
	_icon.kind = kind
	_icon.accent = accent
	_icon.size = ICON
	_icon.position = Vector2((CARD.x - ICON.x) * 0.5, ICON_TOP)
	add_child(_icon)

	_name_label = Label.new()
	_name_label.name = "Name"
	_name_label.text = element_name
	_name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_name_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_name_label.add_theme_font_size_override("font_size", 18)
	_name_label.add_theme_color_override("font_color", accent.lightened(0.18))
	_name_label.position = Vector2(0.0, ICON_TOP + ICON.y + 2.0)
	_name_label.size = Vector2(CARD.x, 24.0)
	add_child(_name_label)


func _make_style(hover: bool) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.set_corner_radius_all(10)
	sb.set_border_width_all(1)
	sb.content_margin_left = 0.0
	sb.content_margin_right = 0.0
	if hover:
		sb.bg_color = Color(0.13, 0.19, 0.29, 0.88)
		sb.border_color = Color(accent.r, accent.g, accent.b, 1.0)
		sb.shadow_color = Color(accent.r, accent.g, accent.b, 0.32)
		sb.shadow_size = 10
	else:
		sb.bg_color = Color(0.08, 0.12, 0.19, 0.74)
		sb.border_color = Color(accent.r, accent.g, accent.b, 0.42)
	return sb


func _set_hover(on: bool) -> void:
	hover_changed.emit(self, on)
	_panel.add_theme_stylebox_override("panel", _style_hover if on else _style_normal)
	if _hover_tween != null and _hover_tween.is_valid():
		_hover_tween.kill()
	_hover_tween = create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	_hover_tween.tween_property(self, "scale", Vector2.ONE * (1.07 if on else 1.0), 0.15)


func _start_float() -> void:
	var t := create_tween().set_loops()
	t.tween_property(_icon, "position:y", ICON_TOP - FLOAT_PX, float_time) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	t.tween_property(_icon, "position:y", ICON_TOP, float_time) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
