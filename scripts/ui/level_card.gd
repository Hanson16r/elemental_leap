extends CanvasLayer
## 开场标题卡 —— 对应 Day 10「开始界面」的补充：每关开头的标题
##
## 关卡开始时盖住屏幕显示"第 N 关 / 标题"，约 1.9 秒后自动淡出。
## 这样玩家一进关就知道自己在哪、这关要干什么。
##
## 注意：这个脚本挂在 CanvasLayer 上，而 modulate 是 CanvasItem 的属性，
## CanvasLayer 没有 modulate。所以淡入淡出要作用在它下面的 Control 根节点上。

@onready var _root: Control = $Root


func show_card(level_number: int, title: String, subtitle: String) -> void:
	$Root/LevelLabel.text = "第 %d 关" % level_number
	$Root/SubLabel.text = title if subtitle == "" else "%s\n%s" % [title, subtitle]
	_root.modulate.a = 0.0
	var tw := create_tween()
	tw.tween_property(_root, "modulate:a", 1.0, 0.4)
	tw.tween_interval(1.4)
	tw.tween_property(_root, "modulate:a", 0.0, 0.5)
	await tw.finished
	queue_free()
