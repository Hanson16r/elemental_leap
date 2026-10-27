extends Node2D
## 【岩石柱】—— 用岩石元素把一根石柱从地里升起来，当台阶/桥
##
## 对应你图里"岩石：障碍/通路、台阶、重力机关"里的"台阶/通路"。
## 和冰桥的区别：
##   · 冰桥是"把水冻住"，只在水池边有用；
##   · 石柱是"把地面抬起来"，任何平地都能用，而且是**永久的**。
##
## 结构：
##   RockPillar（Node2D，放在地面顶面）
##     ├─ 石柱（AnimatableBody2D + CollisionShape2D + Polygon2D）
##     └─ 插槽（Area2D，放在石柱左边）
##
## 玩家带着岩石元素走到插槽：
##   → 消耗岩石，石柱在 0.5 秒内升到目标高度（顶面比地面高 height 像素）
##
## 用法：关卡里 _add_rock_pillar(Vector2(x, 地面顶面), 180, 60)

## 石柱宽度
@export var width: float = 180.0
## 升起后，石柱顶面比地面高多少像素（60 比较舒服，别超过 80）
@export var height: float = 60.0
## 升起动画时长
@export var rise_time: float = 0.5

var _risen: bool = false
var _pillar: AnimatableBody2D
var _pillar_col: CollisionShape2D
var _visual: Polygon2D
var _cap: Polygon2D
var _socket: Area2D
var _socket_visual: Polygon2D
var _target_y: float = 0.0


func _ready() -> void:
	# 石柱本体：高度 = 露出地面的 height + 埋在地下的 40
	var body_height := height + 40.0
	# 目标中心：顶面在 -height，所以中心 = -height + body_height/2
	_target_y = -height + body_height * 0.5

	_pillar = AnimatableBody2D.new()
	_pillar.collision_layer = 1
	_pillar.collision_mask = 0
	_pillar.position = Vector2(0, _target_y + 240.0)   # 一开始埋在地下

	_pillar_col = CollisionShape2D.new()
	var pshape := RectangleShape2D.new()
	pshape.size = Vector2(width, body_height)
	_pillar_col.shape = pshape
	_pillar.add_child(_pillar_col)

	var hw := width * 0.5
	var hh := body_height * 0.5
	_visual = Polygon2D.new()
	_visual.polygon = PackedVector2Array([
		Vector2(-hw, -hh), Vector2(hw, -hh), Vector2(hw, hh), Vector2(-hw, hh),
	])
	_visual.color = Color(0.45, 0.41, 0.36, 0.97)
	_pillar.add_child(_visual)

	_cap = Polygon2D.new()
	_cap.polygon = PackedVector2Array([
		Vector2(-hw, -hh), Vector2(hw, -hh), Vector2(hw, -hh + 8), Vector2(-hw, -hh + 8),
	])
	_cap.color = Color(0.65, 0.58, 0.5, 0.97)
	_pillar.add_child(_cap)

	add_child(_pillar)

	# 插槽：放在石柱左边 50 像素，玩家带着岩石走过来就触发
	_socket = Area2D.new()
	_socket.collision_layer = 0
	_socket.collision_mask = 2
	_socket.monitoring = true
	_socket.position = Vector2(-hw - 50.0, -40.0)
	var sshape := RectangleShape2D.new()
	sshape.size = Vector2(80.0, 90.0)
	var scol := CollisionShape2D.new()
	scol.shape = sshape
	_socket.add_child(scol)

	_socket_visual = Polygon2D.new()
	_socket_visual.polygon = PackedVector2Array([
		Vector2(-30, 10), Vector2(30, 10), Vector2(22, 24), Vector2(-22, 24),
	])
	_socket_visual.color = Color(0.5, 0.46, 0.4, 0.9)
	_socket.add_child(_socket_visual)

	_socket.body_entered.connect(_on_body_entered)
	add_child(_socket)


func _on_body_entered(body: Node2D) -> void:
	if _risen or not body.is_in_group("player"):
		return
	if not body.has_element(Element.Kind.ROCK):
		return

	body.consume()
	_risen = true
	Sfx.play_element_use()
	Events.element_used.emit(Element.Kind.ROCK)

	_socket.set_deferred("monitoring", false)
	_socket_visual.color = Color(0.75, 0.7, 0.6, 0.95)

	var tw := create_tween()
	tw.tween_property(_pillar, "position:y", _target_y, rise_time)\
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


## 复活时把石柱缩回地下：玩家要重新拿岩石来升
func reset_hazard() -> void:
	_risen = false
	_socket.set_deferred("monitoring", true)
	_socket_visual.color = Color(0.5, 0.46, 0.4, 0.9)
	_pillar.position = Vector2(0, _target_y + 240.0)
