extends CanvasLayer
## 暂停菜单 —— 对应 Day 10「做开始界面、暂停、通关界面」
##
## 暂停用的是 Godot 的 get_tree().paused = true。
## 注意：暂停后**所有节点的 _process 和 _physics_process 都会停**，
## 除了那些 process_mode 设成 WHEN_PAUSED / ALWAYS 的节点。
## 所以这个菜单的根节点必须设 process_mode = 3（ALWAYS），否则按钮点不动。

@onready var _volume: HSlider = $Root/Panel/Box/VolumeRow/VolumeSlider

var _level: Node = null


func _ready() -> void:
	# 让菜单在暂停状态下依然响应输入
	process_mode = Node.PROCESS_MODE_ALWAYS
	_level = get_parent()
	$Root/Panel/Box/ResumeButton.pressed.connect(_resume)
	$Root/Panel/Box/RestartButton.pressed.connect(_restart)
	$Root/Panel/Box/MenuButton.pressed.connect(_to_menu)
	$Root/Panel/Box/QuitButton.pressed.connect(func(): get_tree().quit())

	if _volume != null:
		_volume.value = Sfx.get_volume() * 100.0
		_volume.value_changed.connect(func(v: float): Sfx.set_volume(v / 100.0))

	get_tree().paused = true


func _resume() -> void:
	get_tree().paused = false
	queue_free()


func _restart() -> void:
	get_tree().paused = false
	GameState.deaths = 0
	GameState.elapsed = 0.0
	get_tree().reload_current_scene()


func _to_menu() -> void:
	get_tree().paused = false
	get_tree().change_scene_to_file("res://scenes/ui/main_menu.tscn")
