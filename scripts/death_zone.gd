extends Area2D
## 掉落死亡区 —— 对应 Day 6「在关卡底部放一个 Area2D 作为掉落死亡区，碰到就回到检查点位置」
##
## 铺在关卡最底下，玩家掉下去碰到它就算死。
## 这是平台跳跃游戏最基础的"兜底"设计：
## 不然玩家掉出地图外会一直往下掉，游戏看起来就卡住了。
##
## ★ 这个文件曾经有一个很隐蔽的 bug（第 10 关"最后两块平台之间掉下去死不了"）★
##   CollisionShape2D 里本来没有 shape，形状是 _ready() 里按 zone_size 建的。
##   而关卡基类以前是 add_child() 之后才 setup(size)：
##   add_child() 会**同步**触发 _ready()，那时 zone_size 还是默认的 2400，
##   形状就永远定在 2400×200，后面再改 zone_size 也没人重建 shape。
##   于是关卡两端（以及第 10 关最右边整块平台）都落在死亡区外面 —— 掉下去永远不死。
##
##   现在两头都堵上：
##     · setup() 在已经进树的情况下会立刻重建 shape（不管谁先调用）；
##     · 关卡基类改成先 set zone_size + 摆好位置，再 add_child()。

@export var zone_size: Vector2 = Vector2(2400, 200)


## 设置大小。进树之后再调用也安全：会立刻把碰撞形状改成新尺寸。
func setup(sz: Vector2) -> void:
	zone_size = sz
	if is_inside_tree():
		_apply_size()


func _ready() -> void:
	body_entered.connect(_on_body_entered)
	_apply_size()


## 把 zone_size 真正应用到 CollisionShape2D 上。
## 立刻赋值（不用 set_deferred），这样同一帧里就能读到正确的形状，
## 自检工具 _ready() 同步跑完也能验到真实尺寸。
func _apply_size() -> void:
	var col := get_node_or_null("CollisionShape2D") as CollisionShape2D
	if col == null:
		# 场景里没摆 CollisionShape2D 就自己建一个，别让死亡区变成没有形状的摆设
		col = CollisionShape2D.new()
		col.name = "CollisionShape2D"
		add_child(col)
	var shape := RectangleShape2D.new()
	shape.size = Vector2(maxf(zone_size.x, 1.0), maxf(zone_size.y, 1.0))
	col.shape = shape


func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group("player") and body.has_method("die"):
		body.die()
