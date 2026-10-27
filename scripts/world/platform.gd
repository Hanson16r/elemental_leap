extends AnimatableBody2D
## 固定平台 —— 对应 Day 5「用 StaticBody2D 做固定平台」
##
## AnimatableBody2D 和 StaticBody2D 的区别：
##   StaticBody2D    = 永远不动。按性能和语义，固定平台用它更对。
##   AnimatableBody2D = 会动，而且动的时候会"推着/带着"上面的东西。
## 这个场景本身是被 _add_platform() 用的，用 AnimatableBody2D 是为了让
## "会动的平台"（Day 8）能直接复用它，不用维护两套。
##
## 注意：碰撞形状必须在代码里现建（make_unique），
## 否则同一个 .tscn 实例化出来的所有平台会共享同一个形状资源，
## 改一块的宽度，全都会被改掉——这是新手最容易踩的坑之一。

@export var size: Vector2 = Vector2(200.0, 24.0)


func setup(sz: Vector2) -> void:
	size = sz
	var shape := RectangleShape2D.new()
	shape.size = sz
	var col := get_node_or_null("CollisionShape2D")
	if col != null:
		col.shape = shape

	var vis := get_node_or_null("Visual") as Polygon2D
	if vis != null:
		var hw := sz.x * 0.5
		var hh := sz.y * 0.5
		vis.polygon = PackedVector2Array([
			Vector2(-hw, -hh), Vector2(hw, -hh), Vector2(hw, hh), Vector2(-hw, hh),
		])
		vis.color = Color(0.42, 0.55, 0.72)

	# 顶面那一道亮边，让"哪里能站"一眼看得出来
	var top := get_node_or_null("Top") as Line2D
	if top != null:
		var hw2 := sz.x * 0.5
		var hh2 := sz.y * 0.5
		top.points = PackedVector2Array([Vector2(-hw2, -hh2), Vector2(hw2, -hh2)])
