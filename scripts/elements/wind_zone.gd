extends Area2D
## 【风区】—— 走进去会获得一段水平加速，用来跳过平时跳不过去的坑
##
## 为什么不做成"一直吹"的持续力？
## 因为持续力会让玩家在风里一直加速、很难停；这里做成**一次性加速**：
## 进入时给玩家一个 0.9 秒的"最大速度 430"，跑出风区后还能保持一小段，
## 正好够起跳用。规则简单，玩家也好预判。
##
## 用法：关卡里 _add_wind_zone(Vector2(x, y), Vector2(80, 160))

## 风区大小（宽, 高）
@export var size: Vector2 = Vector2(80, 160)
## 加速后的最大水平速度（普通是 240）
@export var boost_speed: float = 430.0
## 加速持续时间（秒）
@export var boost_time: float = 0.9

var _body: Polygon2D


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

	# 半透明青色风带
	_body = Polygon2D.new()
	_body.polygon = PackedVector2Array([
		Vector2(-hw, -hh), Vector2(hw, -hh), Vector2(hw, hh), Vector2(-hw, hh),
	])
	_body.color = Color(0.55, 1.0, 0.75, 0.16)
	add_child(_body)

	# 三个向右的箭头，告诉玩家"风往右吹"
	for i in 3:
		var y := -44.0 + 44.0 * float(i)
		var arrow := Polygon2D.new()
		arrow.polygon = PackedVector2Array([
			Vector2(-16, y - 10), Vector2(4, y), Vector2(-16, y + 10),
		])
		arrow.color = Color(0.65, 1.0, 0.82, 0.55)
		add_child(arrow)

	body_entered.connect(_on_body_entered)


func _on_body_entered(body: Node2D) -> void:
	if not body.is_in_group("player"):
		return
	if body.has_method("apply_wind"):
		body.apply_wind(boost_speed, boost_time)
		Sfx.play_click()
