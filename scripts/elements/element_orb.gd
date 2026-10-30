extends Area2D
## 【元素球】—— 地上捡的"火种 / 冰种 / 石种"
##
## 规则（对应你图里的想法）：玩家一次只能拿一个元素。
## 所以碰到的第一下会问玩家"你手空吗？"（player.pick_up 返回 true/false），
## 手空才拿走；手上有东西就站在原地，等玩家先用掉。
##
## ★ 外观（2026-10-30 美术接入）★
##   火 / 冰 / 石三种用 4 帧呼吸动画的 AnimatedSprite2D（128×32 单图，运行时用
##   AtlasTexture 切回 4 帧）；水 / 风两种目前没有切好的图，仍走原来的
##   "菱形色块 + 汉字" 兜底视觉 —— 11 关里实际只用到火/冰/石，所以场上不会出现兜底样子。
##   可调参数都在下面这组常量里。

const ORB_TEX_FIRE: Texture2D = preload("res://final_assets/elements/orb_fire.png")
const ORB_TEX_ICE: Texture2D = preload("res://final_assets/elements/orb_ice.png")
const ORB_TEX_ROCK: Texture2D = preload("res://final_assets/elements/orb_rock.png")
const FRAME: int = 32       # 单帧尺寸
const FRAMES: int = 4       # 帧数（128 / 32）
const FPS: float = 8.0
const ORB_SCALE: float = 2.0   # 显示成 64×64，和平台瓦片同一密度

@export var kind: int = Element.Kind.FIRE

var _taken: bool = false
var _sprite: AnimatedSprite2D
var _fallback: Polygon2D
var _label: Label


func _ready() -> void:
	# 图层 4 = pickup，掩码 = player（2），这样只检测玩家
	collision_layer = 8
	collision_mask = 2
	monitoring = true

	# 碰撞：一个半径 24 的圆，玩家走近就能捡
	var shape := CircleShape2D.new()
	shape.radius = 24.0
	var col := CollisionShape2D.new()
	col.shape = shape
	add_child(col)

	_build_visual()
	body_entered.connect(_on_body_entered)


## 按 kind 决定用精灵动画还是兜底色块。关卡如果中途改 kind，调 _refresh() 重建即可。
func _build_visual() -> void:
	for node in [_sprite, _fallback, _label]:
		if node != null and is_instance_valid(node):
			remove_child(node)
			node.queue_free()
	_sprite = null
	_fallback = null
	_label = null

	var tex := _texture_for(kind)
	if tex != null:
		_sprite = AnimatedSprite2D.new()
		_sprite.name = "OrbSprite"
		_sprite.sprite_frames = _build_frames(tex)
		_sprite.scale = Vector2(ORB_SCALE, ORB_SCALE)
		_sprite.play("breathe")
		add_child(_sprite)
		return

	# ---- 兜底：还没有美术图的元素（风 / 水）----
	var c := Element.color_of(kind)
	_fallback = Polygon2D.new()
	_fallback.polygon = PackedVector2Array([
		Vector2(0, -16), Vector2(14, 0), Vector2(0, 16), Vector2(-14, 0),
	])
	_fallback.color = c
	add_child(_fallback)

	_label = Label.new()
	_label.add_theme_font_size_override("font_size", 15)
	_label.position = Vector2(-8, -34)
	_label.text = Element.name_of(kind)
	_label.add_theme_color_override("font_color", c)
	add_child(_label)


## 哪种元素有现成美术图；没有就返回 null（走兜底）
func _texture_for(k: int) -> Texture2D:
	match k:
		Element.Kind.FIRE:
			return ORB_TEX_FIRE
		Element.Kind.ICE:
			return ORB_TEX_ICE
		Element.Kind.ROCK:
			return ORB_TEX_ROCK
	return null


## 把 128×32 的横条图切成 4 帧的单动画
func _build_frames(tex: Texture2D) -> SpriteFrames:
	var frames := SpriteFrames.new()
	if frames.has_animation("default"):
		frames.remove_animation("default")
	frames.add_animation("breathe")
	frames.set_animation_loop("breathe", true)
	frames.set_animation_speed("breathe", FPS)
	for i in FRAMES:
		var atlas := AtlasTexture.new()
		atlas.atlas = tex
		atlas.region = Rect2(i * FRAME, 0, FRAME, FRAME)
		frames.add_frame("breathe", atlas)
	return frames


## 根据 kind 刷新外观（关卡如果中途改 kind，调这里重来一遍）
func _refresh() -> void:
	_build_visual()


func _on_body_entered(body: Node2D) -> void:
	_try_pick(body)


## 每帧也检查一次"玩家是不是正站在元素球上"。
## 为什么需要：玩家死亡重生时，如果复活点正好压在元素球上，
## Area2D 不会重新发 body_entered，玩家就会"捡不起来"。
## 第 4 关之后的关卡反馈过这个问题，这里用 get_overlapping_bodies 兜底。
func _process(_delta: float) -> void:
	if _taken:
		return
	for b in get_overlapping_bodies():
		if _try_pick(b):
			break


func _try_pick(body: Node2D) -> bool:
	if _taken or not body.is_in_group("player"):
		return false
	if not body.has_method("pick_up"):
		return false
	if not body.pick_up(kind):
		return false
	_taken = true
	Sfx.play_pickup()
	Events.element_picked.emit(kind)
	hide()          # 不 queue_free：死亡重生时还要能刷出来
	return true


## 玩家死亡重生时，关卡会调用所有 reset_hazard()，把元素球放回去，
## 避免"捡了火种后摔死，火种没了，关卡卡死"。
func reset_hazard() -> void:
	_taken = false
	show()
	# 复活时把检测重新打开：即使玩家站在球上，_process 也会把它捡起来
	set_deferred("monitoring", true)
