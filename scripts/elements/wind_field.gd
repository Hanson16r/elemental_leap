extends Area2D
## 【风场 / 上升气流】—— 站进去会被持续往上托，用来"飞"上高台
##
## 和 wind_zone.gd（水平加速）的区别：
##   · wind_zone：把最大水平速度临时提高，用来跳远；
##   · wind_field：持续给向上的速度，用来垂直起飞。
## 第 5 关「风之塔」就是靠它和前面几关区分开的。
##
## 用法：关卡里 _add_wind_field(Vector2(x, y), Vector2(300, 500))

## 风场大小（宽, 高）
@export var size: Vector2 = Vector2(300, 500)
## 上升速度（玩家在风场里的垂直速度会被钳到这个值）
@export var lift_speed: float = 260.0


func _ready() -> void:
	collision_layer = 4
	collision_mask = 2
	monitoring = true

	var shape := RectangleShape2D.new()
	shape.size = size
	var col := CollisionShape2D.new()
	col.shape = shape
	add_child(col)

	var hw := size.x * 0.5
	var hh := size.y * 0.5

	# 半透明青色风柱
	var body := Polygon2D.new()
	body.polygon = PackedVector2Array([
		Vector2(-hw, -hh), Vector2(hw, -hh), Vector2(hw, hh), Vector2(-hw, hh),
	])
	body.color = Color(0.55, 1.0, 0.78, 0.12)
	add_child(body)

	# 向上的箭头
	for i in 3:
		var x := -hw * 0.45 + hw * 0.45 * float(i)
		var arrow := Polygon2D.new()
		arrow.polygon = PackedVector2Array([
			Vector2(x - 12, 10), Vector2(x + 12, 10), Vector2(x, -10),
		])
		arrow.color = Color(0.65, 1.0, 0.82, 0.55)
		add_child(arrow)

	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)


func _on_body_entered(body: Node2D) -> void:
	if not body.is_in_group("player"):
		return
	if body.has_method("set_updraft"):
		body.set_updraft(true, lift_speed)
		Sfx.play_click()


func _on_body_exited(body: Node2D) -> void:
	if not body.is_in_group("player"):
		return
	if body.has_method("set_updraft"):
		body.set_updraft(false)
