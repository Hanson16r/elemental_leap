extends CanvasLayer
## 主菜单（第一层）—— 只有「开始游戏」和「退出」。
##
## 继续进度 / 从第 1 关重开 / 清空进度 / 选择角色 / 关卡直跳 都收进了第二层
## （scripts/ui/play_menu.gd + scenes/ui/play_menu.tscn），
## 这样第一屏只有两个按钮，谁点都不会懵。
##
## 用按钮而不是键盘，是因为要发给朋友玩——鼠标点一下最不挑人。

@onready var _title: Label = $Root/Box/Title
@onready var _subtitle: Label = $Root/Box/Subtitle
@onready var _start_btn: Button = $Root/Box/StartButton
@onready var _quit_btn: Button = $Root/Box/QuitButton
@onready var _tip: Label = $Root/Tip


func _ready() -> void:
	_title.text = "原始人跳跃闯关"
	_subtitle.text = "利用火/水/冰/风/岩石等元素，破解谜题，到达终点吧。"
	_tip.text = "A / D 或 ← → 移动　空格跳跃　R 重开　Esc 暂停"
	_start_btn.pressed.connect(_start)
	_quit_btn.pressed.connect(_quit)


## 「开始游戏」不直接进第 1 关：先进第二层，让玩家自己挑「继续」还是「重开」，
## 顺便在那里选角色。
func _start() -> void:
	Sfx.play_click()
	get_tree().change_scene_to_file("res://scenes/ui/play_menu.tscn")


func _quit() -> void:
	Sfx.play_click()
	get_tree().quit()
