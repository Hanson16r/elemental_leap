extends Node2D
## 【岩石机关·石柱桥】—— 一枚岩石，一次从断层里升起一排石柱
##
## 和 rock_pillar.gd 的区别：
##   · rock_pillar 只升一根，摆在平地上当台阶；
##   · 这里一次升一排，专门架在断层上：柱子从坑底冒出来，玩家踩着柱顶跳到对岸。
##
## 对应参考图（元素终章）里的岩石段：
##   玩家破坏石墙 → 发现前方断层 → 断层口有一处特殊岩石地面
##   → 使用岩石能力，石柱升起 → 玩家利用石柱跳到对岸。
##
## 结构：
##   RockBridge（Node2D，位置 = 断层左缘那一点的地面顶面，例如 (1290, 780)）
##     ├─ 石柱 × N（AnimatableBody2D，柱顶比地面高 height，初始埋在坑底）
##     └─ 插槽（Area2D，地面上画一块菱形标记，玩家带着岩石走进来就触发）
##
## 用法（关卡脚本里）：
##   _add_rock_bridge(Vector2(1290, 780), [45.0, 145.0, 245.0], 70.0, 60.0)
##   → 三根柱心在 1335 / 1435 / 1535，柱顶 720
##
## 为什么不直接摆三根 rock_pillar？
##   一根 rock_pillar 就要消耗一枚岩石，三根要三枚；这里一枚岩石升一排，
##   玩家不用为了过断层来回捡三次。

## 每根石柱的柱心 x（相对本节点）
@export var column_offsets: Array = [45.0, 145.0, 245.0]
## 石柱宽度
@export var width: float = 70.0
## 升起后，柱顶比地面高多少像素（和 rock_pillar 一致，60 比较舒服）
@export var height: float = 60.0
## 柱身往坑底延伸多深：柱子要真的立到断层底部，不能浮在半空
@export var depth: float = 330.0
## 单根石柱升起时长
@export var rise_time: float = 1
## 相邻两根的升起间隔：做出一根接一根从坑里冒出来的观感
@export var stagger: float = 0.12
## 插槽中心（相对本节点），默认在柱阵左边一点的地面上
@export var socket_offset: Vector2 = Vector2(-35.0, -40.0)
## 插槽触发区大小
@export var socket_size: Vector2 = Vector2(50.0, 90.0)

var _risen: bool = false
var _pillars: Array[AnimatableBody2D] = []
var _target_ys: Array[float] = []
var _socket: Area2D
var _marker: Polygon2D
var _tw: Tween
var _pulse: float = 0.0


func _ready() -> void:
	_build_pillars()
	_build_socket()


func _build_pillars() -> void:
	# 柱身 = 露出地面的 height + 一直伸到坑底的 depth：柱子要立在断层底部，不能浮空
	var body_height := height + depth
	# 目标中心：柱顶在 -height，所以中心 = -height + body_height/2
	var target_y := -height + body_height * 0.5
	var hw := width * 0.5
	var hh := body_height * 0.5

	for i in column_offsets.size():
		var ox := float(column_offsets[i])
		var pillar := AnimatableBody2D.new()
		# ★ 没升起来之前碰撞层是 0：柱子沉在坑里，柱顶刚好和死亡区上沿齐平，
		#   如果留着 layer 1，玩家掉进断层会"站"在埋着的柱顶上，一格一格蹦过去 ——
		#   实机测试里就是这么不用岩石也过了断层。升起来的时候再打开碰撞。
		pillar.collision_layer = 0
		pillar.collision_mask = 0
		# 一开始整根沉在断层底部那块石头下面，看不见
		pillar.position = Vector2(ox, target_y + body_height)
		add_child(pillar)

		var shape := RectangleShape2D.new()
		shape.size = Vector2(width, body_height)
		var col := CollisionShape2D.new()
		col.shape = shape
		pillar.add_child(col)

		var body := Polygon2D.new()
		body.polygon = PackedVector2Array([
			Vector2(-hw, -hh), Vector2(hw, -hh), Vector2(hw, hh), Vector2(-hw, hh),
		])
		body.color = Color(0.58, 0.54, 0.48, 0.98)
		pillar.add_child(body)

		# 左边一条受光面，让一排柱子有圆柱感
		var face := Polygon2D.new()
		face.polygon = PackedVector2Array([
			Vector2(-hw, -hh), Vector2(-hw + 7.0, -hh),
			Vector2(-hw + 7.0, hh), Vector2(-hw, hh),
		])
		face.color = Color(0.70, 0.66, 0.59, 0.95)
		pillar.add_child(face)

		# 三道横向石缝：远看像由石块垒起来的柱子，不是一根灰色长条
		for k in [0.22, 0.46, 0.7]:
			var gy := -hh + body_height * float(k)
			var groove := Polygon2D.new()
			groove.polygon = PackedVector2Array([
				Vector2(-hw + 7.0, gy), Vector2(hw - 3.0, gy),
				Vector2(hw - 3.0, gy + 3.0), Vector2(-hw + 7.0, gy + 3.0),
			])
			groove.color = Color(0.47, 0.43, 0.38, 0.9)
			pillar.add_child(groove)

		# 柱顶盖板，比柱身宽一点，踩上去一眼能看出落脚点
		var cap := Polygon2D.new()
		cap.polygon = PackedVector2Array([
			Vector2(-hw - 4.0, -hh), Vector2(hw + 4.0, -hh),
			Vector2(hw + 4.0, -hh + 9.0), Vector2(-hw - 4.0, -hh + 9.0),
		])
		cap.color = Color(0.75, 0.71, 0.64, 0.98)
		pillar.add_child(cap)

		# 柱脚：立在坑底的那块方座
		var base := Polygon2D.new()
		base.polygon = PackedVector2Array([
			Vector2(-hw - 7.0, hh - 22.0), Vector2(hw + 7.0, hh - 22.0),
			Vector2(hw + 7.0, hh), Vector2(-hw - 7.0, hh),
		])
		base.color = Color(0.65, 0.61, 0.54, 0.98)
		pillar.add_child(base)

		_pillars.append(pillar)
		_target_ys.append(target_y)


func _build_socket() -> void:
	_socket = Area2D.new()
	_socket.collision_layer = 0
	_socket.collision_mask = 2
	_socket.monitoring = true
	_socket.position = socket_offset

	var sshape := RectangleShape2D.new()
	sshape.size = socket_size
	var scol := CollisionShape2D.new()
	scol.shape = sshape
	_socket.add_child(scol)

	# 地面上的石台：就是把"特殊岩石地面"画在地上
	var plate := Polygon2D.new()
	plate.polygon = PackedVector2Array([
		Vector2(-30, 30), Vector2(30, 30), Vector2(26, 44), Vector2(-26, 44),
	])
	plate.color = Color(0.5, 0.46, 0.4, 0.9)
	_socket.add_child(plate)

	# 菱形标记：表示"这里可以放岩石"，不触发时缓慢呼吸
	_marker = Polygon2D.new()
	_marker.polygon = PackedVector2Array([
		Vector2(0, 7), Vector2(11, 18), Vector2(0, 29), Vector2(-11, 18),
	])
	_marker.color = Element.color_of(Element.Kind.ROCK)
	_socket.add_child(_marker)

	_socket.body_entered.connect(_on_body_entered)
	add_child(_socket)


func _process(delta: float) -> void:
	if _risen:
		return
	_pulse += delta
	_marker.modulate.a = 0.55 + 0.3 * sin(_pulse * 3.0)


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
	_marker.modulate.a = 0.35
	_raise_columns()


func _raise_columns() -> void:
	# 每根柱子各自延迟一点点升起：从坑底一根接一根冒出来
	_tw = create_tween()
	_tw.set_parallel(true)
	for i in _pillars.size():
		_pillars[i].set_deferred("collision_layer", 1)
		_tw.tween_property(_pillars[i], "position:y", _target_ys[i], rise_time)\
			.set_delay(stagger * float(i))\
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


## 复活时把整排石柱收回坑底：玩家要重新拿岩石来升
func reset_hazard() -> void:
	if _tw != null and _tw.is_valid():
		_tw.kill()
	_risen = false
	_pulse = 0.0
	_socket.set_deferred("monitoring", true)
	_marker.modulate.a = 1.0
	for i in _pillars.size():
		_pillars[i].set_deferred("collision_layer", 0)
		_pillars[i].position = Vector2(_pillars[i].position.x, _target_ys[i] + height + depth)
