extends Area2D
## 【金币】—— 收集品，不影响通关，只加分数
##
## 每关 5 枚：3 枚在主路，2 枚在支路/危险处。
## HUD 显示“金币 3/5”，通关界面显示本关金币数。
##
## ★ 复活规则（2026-10-27 改）★
##   以前复活时所有金币都回到地图上，HUD 也清零 —— 玩家过了检查点再死，
##   之前吃到的金币就白吃了。现在分两种：
##     · 检查点**之前**吃掉的：复活后保持消失，HUD 数量保留（算作已存档的成绩）；
##     · 检查点**之后**吃掉的：复活后重新出现在地图上（这段还没存档）。
##   关卡脚本（level_base.gd）会在检查点时把"已吃金币编号"存档，
##   复活时先 _reset_hazards() 让金币全部出现，再对这些编号调用 set_taken_state(true)。
##
## ★ 外观（2026-10-30 美术接入）★
##   原来是用两个 Polygon2D 画一个 16 边形圆 + 内层亮圆，现在换成 8 帧动画：
##     spin  = 第 0~3 帧，10 fps，循环 —— 待机旋转
##     burst = 第 4~7 帧，16 fps，不循环 —— 拾取爆闪，播完再隐藏
##   碰撞半径、图层、coin_id / is_taken() / set_taken_state() / reset_hazard()
##   的签名和行为一个字没改，所以检查点存档那套逻辑完全不感知这次改动。

## 128×16 的横条图：8 帧 × 16×16
const COIN_TEX: Texture2D = preload("res://final_assets/anim/coin_anim.png")
const FRAME: int = 16
const COIN_SCALE: float = 2.0   # 显示成 32×32，和平台瓦片同一密度（2 屏幕像素 = 1 素材像素）
const SPIN_FRAMES: int = 4
const BURST_START: int = 4
const SPIN_FPS: float = 10.0
const BURST_FPS: float = 16.0

## 关卡脚本在 _add_coin() 里分配的编号，用来做上面那套存档
@export var coin_id: int = -1

var _taken: bool = false
var _sprite: AnimatedSprite2D
var _t: float = 0.0


func _ready() -> void:
	collision_layer = 8
	collision_mask = 2
	monitoring = true

	var shape := CircleShape2D.new()
	shape.radius = 18.0
	var col := CollisionShape2D.new()
	col.shape = shape
	add_child(col)

	_sprite = AnimatedSprite2D.new()
	_sprite.sprite_frames = _build_frames()
	_sprite.scale = Vector2(COIN_SCALE, COIN_SCALE)
	_sprite.play("spin")
	add_child(_sprite)
	_sprite.animation_finished.connect(_on_animation_finished)

	body_entered.connect(_on_body_entered)


## 把横条图切成 spin / burst 两段动画
func _build_frames() -> SpriteFrames:
	var frames := SpriteFrames.new()
	if frames.has_animation("default"):
		frames.remove_animation("default")
	_add_anim(frames, "spin", 0, SPIN_FRAMES, true, SPIN_FPS)
	_add_anim(frames, "burst", BURST_START, SPIN_FRAMES, false, BURST_FPS)
	return frames


func _add_anim(frames: SpriteFrames, anim_name: String, start: int, count: int,
		loop: bool, fps: float) -> void:
	frames.add_animation(anim_name)
	frames.set_animation_loop(anim_name, loop)
	frames.set_animation_speed(anim_name, fps)
	for i in count:
		var atlas := AtlasTexture.new()
		atlas.atlas = COIN_TEX
		atlas.region = Rect2((start + i) * FRAME, 0, FRAME, FRAME)
		frames.add_frame(anim_name, atlas)


func _process(delta: float) -> void:
	# 上下浮动，让金币显眼（爆闪期间不浮，免得位置跳）
	if _taken or _sprite == null:
		return
	_t += delta
	_sprite.position.y = sin(_t * 3.0) * 4.0


func _on_body_entered(body: Node2D) -> void:
	if _taken or not body.is_in_group("player"):
		return
	_taken = true
	GameState.add_coin()
	Sfx.play_pickup()
	# 立刻关检测，防止同一帧被重复拾取；隐藏要等爆闪播完
	set_deferred("monitoring", false)
	_sprite.play("burst")


## 爆闪播完才真正隐藏 —— 不然玩家看不到"吃到了"的反馈
func _on_animation_finished() -> void:
	if _sprite != null and _sprite.animation == &"burst":
		hide()


## 这枚金币现在是不是已经被吃掉了？（关卡脚本存检查点时用）
func is_taken() -> bool:
	return _taken


## 直接设定"已吃 / 未吃"，不加分、不播音效。
## 复活时关卡脚本用它把"检查点之前吃掉的"金币重新藏起来。
func set_taken_state(taken: bool) -> void:
	_taken = taken
	if _sprite != null:
		_sprite.stop()
		_sprite.position = Vector2.ZERO
	if taken:
		hide()
		set_deferred("monitoring", false)
	else:
		show()
		if _sprite != null:
			_sprite.play("spin")
		set_deferred("monitoring", true)


## 玩家死亡重生时，金币回到"地图上有"的状态。
## 注意：检查点之前已经吃掉的那些，关卡脚本随后会再调 set_taken_state(true) 藏掉。
func reset_hazard() -> void:
	set_taken_state(false)
