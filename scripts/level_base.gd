extends Node2D
## 关卡基类 —— 对应 Day 5「地面与平台」、Day 6「死亡与重生」、Day 10「UI 与流程」、Day 11「做 3 个关卡」
##
## 每个关卡脚本（scripts/levels/level_*.gd）都 extends 这个脚本，只重写 _build()。
## 这样"背景、雪、HUD、玩家、检查点、重生、暂停、通关"只写一次，
## 每关只负责描述"摆什么"，这就是继承的用处。
##
## 子类要设置：level_number / level_title / world_size / start_position / finish_position
## 子类要重写：_build()
## 子类可以重写：_intro_hint() / _subtitle()

## 注意：这里必须用 preload() 而不是写成字符串路径再 load()。
## 写成字符串的话，PLATFORM_SCENE 的类型是 String，调用 .instantiate() 会直接报
## "Cannot find member instantiate in base String" —— 这是新手最容易踩的坑之一。
const HUD_SCENE: PackedScene = preload("res://scenes/ui/hud.tscn")
const COMPLETE_SCENE: PackedScene = preload("res://scenes/ui/level_complete.tscn")
const CARD_SCENE: PackedScene = preload("res://scenes/ui/level_card.tscn")
const PAUSE_SCENE: PackedScene = preload("res://scenes/ui/pause_menu.tscn")
const PLAYER_SCENE: PackedScene = preload("res://scenes/player.tscn")
const SNOW_SCENE: PackedScene = preload("res://scenes/world/snow.tscn")
## 森林背景：从参考图右侧裁出来的（左侧有参考图里的角色，要避开）
const FOREST_BG: Texture2D = preload("res://final_assets/backgrounds/forest_bg.png")

const PLATFORM_SCENE: PackedScene = preload("res://scenes/world/platform.tscn")
const BLINK_SCENE: PackedScene = preload("res://scenes/hazards/blink_platform.tscn")
const MOVING_SCENE: PackedScene = preload("res://scenes/hazards/moving_platform.tscn")
const FLAME_SCENE: PackedScene = preload("res://scenes/hazards/flame.tscn")
const DEATHZONE_SCENE: PackedScene = preload("res://scenes/world/death_zone.tscn")
const CHECKPOINT_SCENE: PackedScene = preload("res://scenes/world/checkpoint.tscn")
const FINISH_SCENE: PackedScene = preload("res://scenes/world/finish_flag.tscn")
const BUTTON_SCENE: PackedScene = preload("res://scenes/hazards/button.tscn")
const DOOR_SCENE: PackedScene = preload("res://scenes/hazards/door.tscn")

# ---- 元素系统（Day 4~7）----
const ELEMENT_ORB_SCENE: PackedScene = preload("res://scenes/elements/element_orb.tscn")
const ELEMENT_RECEIVER_SCENE: PackedScene = preload("res://scenes/elements/element_receiver.tscn")
const WATER_ZONE_SCENE: PackedScene = preload("res://scenes/elements/water_zone.tscn")
const ICE_BARRIER_SCENE: PackedScene = preload("res://scenes/elements/ice_barrier.tscn")
const FREEZE_POOL_SCENE: PackedScene = preload("res://scenes/elements/freeze_pool.tscn")
const FROST_ZONE_SCENE: PackedScene = preload("res://scenes/world/frost_zone.tscn")
const WIND_ZONE_SCENE: PackedScene = preload("res://scenes/elements/wind_zone.tscn")
const WIND_FIELD_SCENE: PackedScene = preload("res://scenes/elements/wind_field.tscn")
const ROCK_WALL_SCENE: PackedScene = preload("res://scenes/elements/rock_wall.tscn")
const ROCK_PILLAR_SCENE: PackedScene = preload("res://scenes/elements/rock_pillar.tscn")
const ROCK_BRIDGE_SCENE: PackedScene = preload("res://scenes/elements/rock_bridge.tscn")

# ---- 收集品 / 敌人 / 间歇火焰（第 12 关起）----
const COIN_SCENE: PackedScene = preload("res://scenes/collectibles/coin.tscn")
const KEY_SCENE: PackedScene = preload("res://scenes/collectibles/key.tscn")
const WALKER_SCENE: PackedScene = preload("res://scenes/enemies/walker.tscn")
const PLAIN_SLIME_SCENE: PackedScene = preload("res://scenes/enemies/slime_plain.tscn")
const WATER_SLIME_SCENE: PackedScene = preload("res://scenes/enemies/water_slime.tscn")
const FIRE_SHOOTER_SCENE: PackedScene = preload("res://scenes/enemies/fire_shooter.tscn")
const FLAME_JET_SCENE: PackedScene = preload("res://scenes/hazards/flame_jet.tscn")
const PRESSURE_PLATE_SCENE: PackedScene = preload("res://scenes/hazards/pressure_plate.tscn")
const WIND_GATE_SCENE: PackedScene = preload("res://scenes/hazards/wind_gate.tscn")
const REVERSE_WIND_SCENE: PackedScene = preload("res://scenes/hazards/reverse_wind.tscn")
const KEY_DOOR_SCENE: PackedScene = preload("res://scenes/hazards/key_door.tscn")

# ---- 子类要覆盖的 ----
var level_number: int = 1
var level_title: String = "关卡"
## 世界大小（宽, 高），用来定背景和相机边界
var world_size: Vector2 = Vector2(2400, 720)
var start_position: Vector2 = Vector2(120, 560)
var finish_position: Vector2 = Vector2(2200, 560)

var player: CharacterBody2D = null
var background_layer: CanvasLayer = null
var game_layer: Node2D = null
var hud: CanvasLayer = null

var _spawn_point: Vector2 = Vector2.ZERO
var _finishing: bool = false
var _respawning: bool = false
var _paused: bool = false
var _pause_menu: CanvasLayer = null
## 这一关一共摆了多少金币（HUD / 通关界面用）
var coin_total: int = 0
## 本关所有金币节点，下标 = coin.gd 的 coin_id
var _coins: Array[Node] = []
## 最近一次检查点存档时，已经吃掉的金币编号。
## 复活后这些金币保持消失、数量保留；检查点之后吃掉的会重新回到地图上。
var _checkpoint_coins: Dictionary = {}

## 所有"能站人的平面"的记录，供 tools/verify_levels.gd 做可达性自检。
## 每条是 { kind, top, x0, x1, ymin, ymax, label }
## kind: "static" | "blink" | "moving" | "door"
var surfaces: Array[Dictionary] = []

## 验证模式：供 tools/verify_levels.gd 使用。
## 置为 true 时只建关卡内容，不建 HUD / 玩家 / 雪粒子，也不连信号。
## 这样验证器不会因为反复创建销毁带 UI 和粒子的关卡把引擎搞崩。
var verify_mode: bool = false


func _ready() -> void:
	_spawn_point = start_position

	# 关掉编辑器的「可见碰撞形状」调试绘制。
	# 它会在角色身上画一层半透明蓝绿色胶囊、在史莱姆身上画一个大圆圈，
	# 看起来就像贴图外面套了个"蓝色小框"（玩家截图里看到的那个）。
	# 这里只在每次进关卡时清一次；真要调碰撞盒，运行中在编辑器 Debug 菜单里
	# 重新勾上「可见碰撞形状」即可，不影响。
	if get_tree() != null:
		get_tree().debug_collisions_hint = false

	if verify_mode:
		# ---- 验证模式：只建内容，别的都不建 ----
		game_layer = Node2D.new()
		game_layer.name = "GameLayer"
		add_child(game_layer)
		GameState.start_level(level_number, level_title, _spawn_point)
		_build()
		return

	_setup_layers()
	# 先把这一关的信息和计时清零，再建关卡内容，
	# 否则标题卡和 HUD 会读到上一关的关卡号
	GameState.start_level(level_number, level_title, _spawn_point)
	_build()
	_spawn_player()
	_setup_hud()
	_connect_events()

	# 标题卡延后一帧生成，这样它才能看到已经建好的场景
	var hint := _intro_hint()
	if hint != "":
		hud.show_hint(hint)
	_show_card.call_deferred()


## 子类重写这个方法来摆关卡
func _build() -> void:
	pass


## 子类可以重写，用来自定义开场提示（屏幕下方的操作提示）
func _intro_hint() -> String:
	return ""


## 子类可以重写，标题卡上的副标题
func _subtitle() -> String:
	return ""


# ===================================================================== 场景结构

## 分三层：背景（永远在最下面）→ 游戏内容 → HUD
## 雪必须挂在背景 CanvasLayer 上，否则相机一动雪就跟着世界跑，看起来很假
func _setup_layers() -> void:
	background_layer = CanvasLayer.new()
	background_layer.name = "BackgroundLayer"
	background_layer.layer = -10
	add_child(background_layer)

	game_layer = Node2D.new()
	game_layer.name = "GameLayer"
	add_child(game_layer)

	_add_background()

	var snow := SNOW_SCENE.instantiate()
	background_layer.add_child(snow)
	snow.setup(world_size)


func _add_background() -> void:
	# 用参考图里的森林当背景；裁掉左侧（那里有参考图自带的玩家/史莱姆）
	var tex := AtlasTexture.new()
	tex.atlas = FOREST_BG
	tex.region = Rect2(500, 0, 652, 648)
	var rect := TextureRect.new()
	rect.name = "Forest"
	rect.texture = tex
	rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	rect.stretch_mode = TextureRect.STRETCH_SCALE
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	background_layer.add_child(rect)
	# 必须用 set_anchors_and_offsets_preset：set_anchors_preset 只改锚点、偏移量
	# 按"保持当前尺寸"调整，而刚 new 出来的 TextureRect 是 0×0，会被压成 0 尺寸看不见。
	rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)


func _spawn_player() -> void:
	player = PLAYER_SCENE.instantiate()
	player.add_to_group("player")          # Day 6：用分组判断"这是不是玩家"
	game_layer.add_child(player)
	player.global_position = _spawn_point
	player.set_spawn(_spawn_point)
	player.died.connect(_on_player_died)

	# 相机边界：不让相机拍到世界外面
	var cam: Camera2D = player.get_node("Camera2D")
	cam.limit_left = int(-120)
	cam.limit_top = int(-260)
	cam.limit_right = int(world_size.x + 120)
	cam.limit_bottom = int(world_size.y + 200)


func _setup_hud() -> void:
	hud = HUD_SCENE.instantiate()
	add_child(hud)
	hud.pause_requested.connect(_on_pause_requested)


func _connect_events() -> void:
	Events.checkpoint_reached.connect(_on_checkpoint_reached)


func _show_card() -> void:
	var card: CanvasLayer = CARD_SCENE.instantiate()
	add_child(card)
	card.show_card(GameState.level_position(level_number), level_title, _subtitle())


# ===================================================================== 搭建辅助函数
## 下面这些是给子类 _build() 用的。都会把节点加进 game_layer，并返回出去方便继续设置。

## 加一块固定平台（Day 5）。pos 是平台中心
## 返回 AnimatableBody2D 而不是 StaticBody2D，是为了和 platform.gd 的类型一致
func _add_platform(pos: Vector2, w: float = 200.0, h: float = 24.0) -> AnimatableBody2D:
	var body: AnimatableBody2D = PLATFORM_SCENE.instantiate()
	game_layer.add_child(body)
	body.global_position = pos
	body.setup(Vector2(w, h))
	_register_surface("static", pos, w, h, "platform", Vector2.ZERO)
	return body


## 加一块"冰面"平台：顶面和普通平台一样平，但站上去只有 15% 摩擦力，会滑。
## 第 9 关的冰桥用它；以后需要"滑一段"的整块平台也能直接用。
func _add_ice_platform(pos: Vector2, w: float = 200.0, h: float = 24.0) -> AnimatableBody2D:
	var body: AnimatableBody2D = PLATFORM_SCENE.instantiate()
	game_layer.add_child(body)
	body.global_position = pos
	# 先打上冰面标记，再 setup()：setup() 会按 slippery 换成冰色和亮白边
	body.set("slippery", true)
	body.setup(Vector2(w, h))
	_register_surface("static", pos, w, h, "ice_bridge（冰面）", Vector2.ZERO)
	return body


## 加一块"岩石地面"：和普通平台同高、同碰撞，只是换成岩石的深灰棕色。
## 第 12 关断层口那处"特殊岩石地面"用它 —— 玩家一眼能看出这里和别的平台不一样。
func _add_rock_floor(pos: Vector2, w: float = 90.0, h: float = 40.0) -> AnimatableBody2D:
	var body := _add_platform(pos, w, h)
	# 美术接入后平台是瓦片贴图：颜色会和纹理相乘，所以砖体和草皮一起染成岩石色，
	# 既保留瓦片纹理，又和普通草地平台区分得开。
	var tint := Color(0.42, 0.38, 0.34)
	for node_name in ["Visual", "Cap"]:
		var poly := body.get_node_or_null(node_name) as Polygon2D
		if poly != null:
			poly.color = tint
	return body


## 加一块会消失再出现的平台（Day 9）
func _add_blink_platform(pos: Vector2, w: float = 160.0, phase: float = 0.0) -> AnimatableBody2D:
	var node: AnimatableBody2D = BLINK_SCENE.instantiate()
	game_layer.add_child(node)
	node.global_position = pos
	node.setup(w, phase)
	_register_surface("blink", pos, w, 22.0, "blink", Vector2.ZERO)
	return node


## 加一块往返移动的平台（Day 8）。offset 是相对 pos 的往返幅度
func _add_moving_platform(pos: Vector2, offset: Vector2, speed: float = 70.0, w: float = 160.0) -> AnimatableBody2D:
	var node: AnimatableBody2D = MOVING_SCENE.instantiate()
	# 先摆好局部位置，再 add_child：这样 _ready() 里读到的就是正确位置。
	# （AnimatableBody2D 的 global_position 在刚 add_child 后可能还没同步，读到 0）
	node.position = pos
	game_layer.add_child(node)
	node.setup(offset, speed, w)
	_register_moving_surface(pos, w, offset)
	return node


## 移动平台要按**两个端点（最左/最右、最高/最低）**分别登记，不能登记成"整个行程的大平面"。
##
## 为什么：如果把行程 x=1000~1470 登记成一个宽平台，可达性检查就会以为玩家
## 随时能站在行程中任意一点 —— 那是瞬移，不是移动平台。
## 按端点登记，检查器才会正确地要求"平台到这一头的时候才跳得上去"。
##
## 注意平台创建时 offset 的含义：moving_platform.gd 里 offset 表示"从当前位置出发的移动方向"，
## 而且在掉头时会取反。但它始终围绕"初始位置"来回，幅度是 offset.length()/2，
## 所以两个端点就是 pos ± offset/2。这里必须用 /2，写成 ±offset 会算错一倍。
func _register_moving_surface(pos: Vector2, w: float, travel: Vector2) -> void:
	var half := travel * 0.5
	var id := "mover#%d" % surfaces.size()
	_register_surface("moving", pos - half, w, 22.0, id + "@A(最左/最低)", Vector2.ZERO, id)
	if travel.length() > 1.0:
		_register_surface("moving", pos + half, w, 22.0, id + "@B(最右/最高)", Vector2.ZERO, id)


## 加一团蓝色火焰（Day 9）。碰到就死。pos 是火焰底部
func _add_flame(pos: Vector2, size: Vector2 = Vector2(32, 44)) -> Area2D:
	var node: Area2D = FLAME_SCENE.instantiate()
	game_layer.add_child(node)
	node.global_position = pos
	node.setup(size)
	return node


## 铺一整排火焰（关卡里很好用）
func _add_flame_row(from_x: float, to_x: float, y: float, step: float = 34.0) -> void:
	var x := from_x
	while x <= to_x:
		_add_flame(Vector2(x, y))
		x += step


## 加检查点（Day 6）；reach > 0 时触发区拉成竖向长条，上下两条路线经过都能碰到
func _add_checkpoint(pos: Vector2, reach: float = 0.0) -> Area2D:
	var node: Area2D = CHECKPOINT_SCENE.instantiate()
	if reach > 0.0:
		node.set("reach", reach)
	game_layer.add_child(node)
	node.global_position = pos
	node.setup(pos)
	return node


## 踩下去开门的按钮（Day 9）
func _add_button(pos: Vector2, door_id: String) -> Area2D:
	var node: Area2D = BUTTON_SCENE.instantiate()
	game_layer.add_child(node)
	node.global_position = pos
	node.setup(door_id)
	return node


## 被按钮打开的门（Day 9）
func _add_door(pos: Vector2, door_id: String, size: Vector2 = Vector2(40, 200)) -> StaticBody2D:
	var node: StaticBody2D = DOOR_SCENE.instantiate() as StaticBody2D
	# 先摆位置再进树：门的碰撞体在 _ready() 里创建，进树后再移动可能让碰撞体留在原点
	node.position = pos
	game_layer.add_child(node)
	node.setup(door_id, size)
	# 门是竖着的墙，不是"能站人的平面"，所以**不要**登记进 surfaces。
	# 以前登记了，可达性检查会把它当成一块顶面 635 的平台，
	# 然后刷出一堆"门跳不上去"的假报警。
	return node


## 元素球（地上捡的火/冰/风）。注意：先 set(kind) + 摆好位置，再 add_child，
## 因为元素的 _ready() 会按 kind 来建颜色和文字；物理体也要在进树前就位。
func _add_element_orb(pos: Vector2, kind: int) -> Area2D:
	var node: Area2D = ELEMENT_ORB_SCENE.instantiate() as Area2D
	node.set("kind", kind)
	node.position = pos
	game_layer.add_child(node)
	return node


## 元素接收器（火盆）：手里元素对上就消耗，并复用"按钮→门"的信号开门
func _add_element_receiver(pos: Vector2, required: int, door_id: String) -> Area2D:
	var node: Area2D = ELEMENT_RECEIVER_SCENE.instantiate() as Area2D
	node.set("required", required)
	node.set("door_id", door_id)
	node.position = pos
	game_layer.add_child(node)
	return node


## 水幕：走进去会浇灭手里的火
func _add_water_zone(pos: Vector2, size: Vector2) -> Area2D:
	var node: Area2D = WATER_ZONE_SCENE.instantiate() as Area2D
	node.set("size", size)
	node.position = pos
	game_layer.add_child(node)
	return node


## 冰墙：只有火能融掉
func _add_ice_barrier(pos: Vector2, size: Vector2) -> StaticBody2D:
	var node: StaticBody2D = ICE_BARRIER_SCENE.instantiate() as StaticBody2D
	node.set("size", size)
	node.position = pos
	game_layer.add_child(node)
	return node


## 水池：冰把水面冻成桥，火把冰融回水
## water_drop > 0 时是"下沉水池"：水面比两侧地面低 water_drop，冻住后冰桥才抬到地面高度
## drowns = true 时没冻住掉进水里直接死（而不是继续往下掉）
## water_depth 是水体深度（水面往下多深 = 坑有多高），水底 = 水面 + water_depth
func _add_freeze_pool(
	pos: Vector2,
	width: float = 300.0,
	water_drop: float = 0.0,
	drowns: bool = false,
	water_depth: float = 90.0,
	trigger_reach: float = 0.0,
) -> Node2D:
	var node: Node2D = FREEZE_POOL_SCENE.instantiate() as Node2D
	node.set("width", width)
	node.set("water_drop", water_drop)
	node.set("drowns", drowns)
	node.set("water_depth", water_depth)
	node.set("trigger_reach", trigger_reach)
	# ★ 必须先把位置摆好，再 add_child ★
	# 因为池子 _ready() 里会建一块 AnimatableBody2D 冰桥；如果池子进树后才移动，
	# 冰桥的物理体可能还留在 (0,0)，玩家就会直接掉进水里（第 4 关踩过的坑）。
	node.position = pos
	game_layer.add_child(node)
	return node


## 风区：走进给一段水平加速，用来跳远
## boost_speed / boost_time 一般不用改（风区场景里默认 430 / 0.9 秒）。
## 只在"风区后面紧接着就是地火"这种地方才需要调小，免得玩家被一路推着火里。
func _add_wind_zone(pos: Vector2, size: Vector2,
		boost_speed: float = 430.0, boost_time: float = 0.9) -> Area2D:
	var node: Area2D = WIND_ZONE_SCENE.instantiate() as Area2D
	node.set("size", size)
	node.set("boost_speed", boost_speed)
	node.set("boost_time", boost_time)
	node.position = pos
	game_layer.add_child(node)
	return node


## 风场：站进去会被持续往上托，用来"飞"上高台
## lift_speed 默认 260（正常升力）；第 8 关高台边缘的"微弱风场"传 104（40%）
func _add_wind_field(pos: Vector2, size: Vector2, lift_speed: float = 260.0) -> Area2D:
	var node: Area2D = WIND_FIELD_SCENE.instantiate() as Area2D
	node.set("size", size)
	node.set("lift_speed", lift_speed)
	node.position = pos
	game_layer.add_child(node)
	return node


## 岩石墙：只有岩石元素能砸开
func _add_rock_wall(pos: Vector2, size: Vector2) -> StaticBody2D:
	var node: StaticBody2D = ROCK_WALL_SCENE.instantiate() as StaticBody2D
	node.set("size", size)
	node.position = pos
	game_layer.add_child(node)
	return node


## 岩石柱：用岩石元素把石柱升起来当台阶/桥。
## pos 是"地面顶面"的位置；height 是石柱顶面比地面高多少。
## 同时给检查工具登记一条"石柱升起后可以站"的表面。
func _add_rock_pillar(pos: Vector2, width: float = 180.0, height: float = 60.0) -> Node2D:
	var node: Node2D = ROCK_PILLAR_SCENE.instantiate() as Node2D
	node.set("width", width)
	node.set("height", height)
	node.position = pos
	game_layer.add_child(node)
	_register_surface("static", Vector2(pos.x, pos.y - height + 100.0), width, 200.0,
		"rock_pillar（需岩石）", Vector2.ZERO)
	return node


## 岩石机关·石柱桥：一枚岩石，一次升起一排石柱，用来跨过断层。
## pos 是"断层左缘那一点的地面顶面"；offsets 是每根柱心相对 pos 的 x 偏移；
## 柱顶统一比地面高 pillar_height；shaft_depth 是柱身往坑底延伸的深度（要盖住整个坑的落差）。
## 和 _add_rock_pillar 一样，给检查工具登记"升起后可以站"的表面：
## 检查器不模拟机关，只按最终形态算可达性，所以没升起来的断层看起来仍然能过。
func _add_rock_bridge(pos: Vector2, offsets: Array, column_width: float = 70.0,
		pillar_height: float = 60.0, shaft_depth: float = 330.0) -> Node2D:
	var node: Node2D = ROCK_BRIDGE_SCENE.instantiate() as Node2D
	node.set("column_offsets", offsets)
	node.set("width", column_width)
	node.set("height", pillar_height)
	node.set("depth", shaft_depth)
	node.position = pos
	game_layer.add_child(node)
	for ox in offsets:
		_register_surface("static", Vector2(pos.x + float(ox), pos.y - pillar_height + 20.0),
			column_width, 40.0, "rock_bridge（需岩石）", Vector2.ZERO)
	return node


## 冻住的小水洼：纯装饰，不挡路、不结冰、不淹人。
## 用在"冰封水源 / 冰墙"这种地方，给被冻住的源头一个能看见的实体。
## pos 是地面顶面，w 是水洼宽度。
func _add_frozen_pool(pos: Vector2, w: float = 60.0) -> Node2D:
	var node := Node2D.new()
	node.position = pos
	game_layer.add_child(node)
	var hw := w * 0.5

	# 冰下的水：贴着地面露出来的一条缝
	var water := Polygon2D.new()
	water.polygon = PackedVector2Array([
		Vector2(-hw, 3.0), Vector2(hw, 3.0), Vector2(hw - 2.0, 9.0), Vector2(-hw + 2.0, 9.0),
	])
	water.color = Color(0.28, 0.50, 0.72, 0.85)
	node.add_child(water)

	# 冰面：盖在水上，中间略鼓
	var ice := Polygon2D.new()
	ice.polygon = PackedVector2Array([
		Vector2(-hw - 1.0, -4.0), Vector2(hw + 1.0, -4.0),
		Vector2(hw, 3.5), Vector2(-hw, 3.5),
	])
	ice.color = Color(0.82, 0.93, 1.0, 0.96)
	node.add_child(ice)

	# 高光 + 两道裂纹：不通风化，一看就是冻住的
	var shine := Polygon2D.new()
	shine.polygon = PackedVector2Array([
		Vector2(-hw + 5.0, -4.0), Vector2(-hw + 18.0, -4.0),
		Vector2(-hw + 15.0, 1.0), Vector2(-hw + 3.0, 1.0),
	])
	shine.color = Color(1.0, 1.0, 1.0, 0.45)
	node.add_child(shine)

	for cx in [-hw * 0.35, hw * 0.25]:
		var crack := Polygon2D.new()
		crack.polygon = PackedVector2Array([
			Vector2(cx, -4.0), Vector2(cx + 2.0, -4.0),
			Vector2(cx + 5.0, 3.0), Vector2(cx + 3.0, 3.0),
		])
		crack.color = Color(0.62, 0.80, 0.95, 0.75)
		node.add_child(crack)

	return node


## 金币：收集品，不影响通关
func _add_coin(pos: Vector2) -> Area2D:
	var node: Area2D = COIN_SCENE.instantiate() as Area2D
	# 编号在进树之前写好，coin.gd 里存的就是这个
	node.set("coin_id", coin_total)
	node.position = pos
	game_layer.add_child(node)
	_coins.append(node)
	coin_total += 1
	GameState.coin_total = coin_total
	return node


## 钥匙：一次性拾取，开门用
func _add_key(pos: Vector2) -> Area2D:
	var node: Area2D = KEY_SCENE.instantiate() as Area2D
	node.position = pos
	game_layer.add_child(node)
	return node


## 雪球虫：在 pos 左右 ±patrol 巡逻，碰到就死
func _add_walker(pos: Vector2, patrol: float = 120.0, speed: float = 60.0) -> Area2D:
	var node: Area2D = WALKER_SCENE.instantiate() as Area2D
	node.set("patrol", patrol)
	node.set("speed", speed)
	node.position = pos
	game_layer.add_child(node)
	return node


## 普通史莱姆：淡绿这一套贴图，和蓝色水史莱姆区分开（行为与 _add_walker 完全一样）
func _add_plain_slime(pos: Vector2, patrol: float = 60.0, speed: float = 60.0) -> Area2D:
	var node: Area2D = PLAIN_SLIME_SCENE.instantiate() as Area2D
	node.set("patrol", patrol)
	node.set("speed", speed)
	node.position = pos
	game_layer.add_child(node)
	return node


## 水史莱姆：和普通史莱姆一样巡逻，但会在"有效中的冰霜地带"里被冻住 2.5 秒
func _add_water_slime(pos: Vector2, patrol: float = 90.0, speed: float = 60.0) -> Area2D:
	var node: Area2D = WATER_SLIME_SCENE.instantiate() as Area2D
	node.set("patrol", patrol)
	node.set("speed", speed)
	node.position = pos
	game_layer.add_child(node)
	return node


## 冰霜地带：玩家经过时激活 4 秒，水史莱姆在有效期内进入会被冻住
func _add_frost_zone(pos: Vector2, width: float = 140.0) -> Node2D:
	var node: Node2D = FROST_ZONE_SCENE.instantiate() as Node2D
	node.set("width", width)
	node.position = pos
	game_layer.add_child(node)
	return node


## 喷火怪：站在平台上定期朝 direction 喷火球（-1 左，1 右）
func _add_fire_shooter(pos: Vector2, direction: float = -1.0) -> Area2D:
	var node: Area2D = FIRE_SHOOTER_SCENE.instantiate() as Area2D
	node.set("direction", direction)
	node.position = pos
	game_layer.add_child(node)
	return node


## 间歇火焰喷口：up=true 地火，false 天火；phase 用来错开节奏
## triggered=true 时不走固定周期，改由压力板之类的信号调用 press()/release() 驱动（第 2 关的天火）
## off_time 是"灭"的时长，配合固定周期用（默认 1.5 → 一个周期 2.9 秒）
func _add_flame_jet(pos: Vector2, up: bool = true, phase: float = 0.0, length: float = 110.0,
		triggered: bool = false, off_time: float = 1.5) -> Area2D:
	var node: Area2D = FLAME_JET_SCENE.instantiate() as Area2D
	node.set("up", up)
	node.set("phase", phase)
	node.set("length", length)
	node.set("triggered", triggered)
	node.set("off_time", off_time)
	node.position = pos
	game_layer.add_child(node)
	return node


## 压力板：踩上去发 pressed，松开发 released（第 2 关用来点天花板火焰）
func _add_pressure_plate(pos: Vector2, width: float = 72.0) -> Area2D:
	var node: Area2D = PRESSURE_PLATE_SCENE.instantiate() as Area2D
	node.set("width", width)
	node.position = pos
	game_layer.add_child(node)
	return node


## 周期风门（方向二）：风带每 period 秒吹 blow_time 秒，只在吹的时候开门。
## pos 是**门的中心**；风带自动贴在门左边（宽度 belt_size.x）。第 8 关高台右端用。
func _add_wind_gate(pos: Vector2, door_size: Vector2 = Vector2(40, 100),
		belt_size: Vector2 = Vector2(100, 100)) -> StaticBody2D:
	var node: StaticBody2D = WIND_GATE_SCENE.instantiate() as StaticBody2D
	node.set("door_size", door_size)
	node.set("belt_size", belt_size)
	node.position = pos
	game_layer.add_child(node)
	return node


## 逆向风场：水平向左吹的气流（push 为负 = 目标速度往左偏），玩家要按住 D 顶过去。
func _add_reverse_wind(pos: Vector2, size: Vector2, push: float = -80.0) -> Area2D:
	var node: Area2D = REVERSE_WIND_SCENE.instantiate() as Area2D
	node.set("size", size)
	node.set("push", push)
	node.position = pos
	game_layer.add_child(node)
	return node


## 钥匙门：玩家带钥匙走近就开
func _add_key_door(pos: Vector2, size: Vector2 = Vector2(40, 200)) -> StaticBody2D:
	var node: StaticBody2D = KEY_DOOR_SCENE.instantiate() as StaticBody2D
	node.set("size", size)
	node.position = pos
	game_layer.add_child(node)
	return node


## 记录一个"能站人的平面"，给可达性自检用（不影响游戏运行）
func _register_surface(kind: String, center: Vector2, w: float, h: float, label: String, travel: Vector2, mover_id: String = "") -> void:
	surfaces.append({
		"kind": kind,
		"top": center.y - h * 0.5,
		## 底面也记下来：可达性检查要算"站在这块面上起跳，头顶还剩多少净空"
		"bottom": center.y + h * 0.5,
		"x0": center.x - w * 0.5,
		"x1": center.x + w * 0.5,
		"ymin": minf(center.y, center.y + travel.y) - h * 0.5,
		"ymax": maxf(center.y, center.y + travel.y) - h * 0.5,
		"label": label,
		"mover_id": mover_id,
	})


## 关卡底部的掉落死亡区（Day 6）
##
## ★ 顺序很重要：先摆位置、先写 zone_size，再 add_child ★
##   death_zone.gd 的 _ready() 会按 zone_size 建碰撞形状，而 add_child() 是同步触发
##   _ready() 的。以前写成"先 add_child 再 setup"，形状就被建成了默认的 2400 宽，
##   关卡两端掉下去死不了（第 12 关最后两块平台之间就是这么漏的）。
##   现在 death_zone.setup() 自己也会重建形状，但这里的顺序仍然按"进树前配好"写，
##   免得以后有人把 setup() 的实现改回去又踩同一个坑。
func _add_death_zone(y: float, from_x: float, to_x: float) -> Area2D:
	var node: Area2D = DEATHZONE_SCENE.instantiate() as Area2D
	node.set("zone_size", Vector2(absf(to_x - from_x), 200.0))
	node.position = Vector2((from_x + to_x) * 0.5, y)
	game_layer.add_child(node)
	return node


## 终点旗（Day 6 / Day 11）
func _add_finish_flag(pos: Vector2) -> Area2D:
	var node: Area2D = FINISH_SCENE.instantiate()
	game_layer.add_child(node)
	node.global_position = pos
	node.setup(pos)
	node.reached.connect(_on_finish_reached)
	return node


## 关卡里的文字牌，用来提示玩法
func _add_sign(pos: Vector2, text: String) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", 19)
	label.add_theme_color_override("font_color", Color(0.72, 0.86, 1.0, 0.8))
	game_layer.add_child(label)
	label.global_position = pos
	return label


# ===================================================================== 死亡与重生

func _on_player_died() -> void:
	if _respawning:
		return
	_respawning = true
	GameState.register_death()
	if hud != null:
		hud.update_deaths()
	# 等死亡动画播完（player.die() 里约 0.5 秒）
	await get_tree().create_timer(0.55).timeout
	await _respawn()


func _respawn() -> void:
	if hud != null:
		await hud.fade_out(0.22)
	player.respawn_at(GameState.spawn_position)
	# 先让物理世界"看到"玩家已经站在复活点，再把金币/机关放回来。
	# 否则会出这个 bug：金币恢复监测的那一帧，物理服务器里玩家还停在死亡位置，
	# 死亡点那枚金币会被立刻再"捡"一次 —— 复活后金币数量莫名其妙 +1。
	# 等两个物理帧足够让玩家本体的 transform 和碰撞形状都同步完。
	await get_tree().physics_frame
	await get_tree().physics_frame
	_reset_hazards()
	# 金币不再一律清零：检查点之前吃掉的算已存档，保留数量、地图上保持消失；
	# 检查点之后吃掉的重新出现（这段还没存档）。
	_restore_coins_after_respawn()
	if hud != null:
		await get_tree().create_timer(0.1).timeout
		await hud.fade_in(0.22)
	_respawning = false


## 复活时把整个关卡复位到初始状态：
## 元素球/钥匙/金币重新出现，冰桥变回水，冰墙/石墙恢复，
## 石柱缩回地下，火盆/按钮/门复位，移动平台回起点，火焰/敌人复位，空中的火球清掉。
## 检查点（复活点）本身保留。
func _reset_hazards() -> void:
	for node in game_layer.get_children():
		if node.has_method("reset_hazard"):
			node.reset_hazard()


func _on_checkpoint_reached(pos: Vector2) -> void:
	GameState.register_checkpoint(pos)
	_spawn_point = pos
	if player != null:
		player.set_spawn(pos)
	# 检查点 = 存档点：把"此刻已经吃掉哪几枚金币"记下来
	_snapshot_coins()


## 存档当前的金币进度。必须在玩家碰到检查点的那一刻调用，
## 因为复活后要还原成"刚到这里时的样子"。
func _snapshot_coins() -> void:
	_checkpoint_coins.clear()
	for coin in _coins:
		if is_instance_valid(coin) and coin.has_method("is_taken") and coin.call("is_taken"):
			_checkpoint_coins[int(coin.get("coin_id"))] = true


## 复活时处理金币：
##   · _reset_hazards() 已经把地图上所有金币都放回来了；
##   · 这里把"检查点之前已经吃掉"的那几枚重新藏起来；
##   · HUD 的数量也回到存档时的数量（GameState.coins）。
## 于是：检查点前吃了 3 枚 → 复活还是 3 枚且那 3 枚不会再出现；
##       检查点后又吃了 2 枚 → 复活只剩 3 枚，那 2 枚回到地图上。
func _restore_coins_after_respawn() -> void:
	for coin in _coins:
		if not is_instance_valid(coin):
			continue
		if _checkpoint_coins.has(int(coin.get("coin_id"))):
			coin.call("set_taken_state", true)
	GameState.coins = _checkpoint_coins.size()


# ===================================================================== 通关

func _on_finish_reached(_pos: Vector2) -> void:
	if _finishing:
		return
	_finishing = true
	if player != null:
		player.freeze()
	GameState.complete_level()
	Sfx.play_finish()
	if hud != null:
		await hud.fade_out(0.35)
	var screen: CanvasLayer = COMPLETE_SCENE.instantiate()
	add_child(screen)
	screen.setup(GameState.level_position(GameState.current_level), GameState.level_title, GameState.elapsed, GameState.deaths)


# ===================================================================== 暂停

func _on_pause_requested() -> void:
	if _finishing:
		return
	if _paused:
		if _pause_menu != null and is_instance_valid(_pause_menu):
			_pause_menu.queue_free()
		_pause_menu = null
		_paused = false
		get_tree().paused = false
		return
	_paused = true
	_pause_menu = PAUSE_SCENE.instantiate()
	add_child(_pause_menu)
	# 暂停菜单自己退出时要通知关卡一声，所以监听它的 tree_exited
	_pause_menu.tree_exited.connect(_on_pause_menu_closed)


func _on_pause_menu_closed() -> void:
	_paused = false
	_pause_menu = null
	# 从暂停菜单点「主菜单」时，场景先切换、本节点已经离开场景树，
	# 这时再调 get_tree() 会报 "Parameter data.tree is null"，所以先判断。
	if is_inside_tree():
		get_tree().paused = false
