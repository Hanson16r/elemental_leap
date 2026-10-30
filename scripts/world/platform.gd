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
##
## 外观（2026-10-30 美术接入）：Visual 铺 16px 砖块瓦片 + 顶部 Cap 铺草皮瓦片。
## 冰面平台（slippery）顶面换成冰瓦片、砖体压一层冷蓝，让"会打滑"一眼能认出来。
## 纹理尺寸、平铺倍率、草皮高度都在下面这组常量里，换主题只改这里。

## 草皮顶面（横向无缝）、砖块体（四向无缝）、冰面顶（横向无缝，必须同为 16px 瓦片）
const CAP_TEX: Texture2D = preload("res://final_assets/tiles/grass_cap.png")
const BODY_TEX: Texture2D = preload("res://final_assets/tiles/stone_body.png")
const ICE_CAP_TEX: Texture2D = preload("res://final_assets/tiles/ice.png")
const TILE: int = 16            # 素材原始瓦片尺寸（像素）
const TILE_SCALE: int = 2       # 1=16px/格，2=32px/格（和 1.8 倍角色更搭）
const CAP_H: int = TILE * TILE_SCALE   # 草皮顶的屏幕高度：32px
## 冰面染色（都会和瓦片颜色相乘）：顶面只轻微提亮，砖体压成冷蓝
const ICE_CAP_TINT: Color = Color(0.86, 0.95, 1.0)
const ICE_BODY_TINT: Color = Color(0.55, 0.74, 0.98)

@export var size: Vector2 = Vector2(200.0, 24.0)
## 冰面材质：站上去摩擦力只有 15%，会带着惯性滑出去。
## player.gd 每帧用 is_slippery() 问它，所以这里只要暴露这个开关就行。
@export var slippery: bool = false


func is_slippery() -> bool:
	return slippery


func setup(sz: Vector2) -> void:
	size = sz
	var shape := RectangleShape2D.new()
	shape.size = sz
	var col := get_node_or_null("CollisionShape2D")
	if col != null:
		col.shape = shape

	_apply_look()


## 只改外观，不碰碰撞。_ready() 和 setup() 都会调它：
## _ready() 是编辑器里直接拖进场景时能看见样子，setup() 是关卡脚本改了尺寸之后重铺一次。
func _apply_look() -> void:
	var hw := size.x * 0.5
	var hh := size.y * 0.5
	# 纹理颜色和瓦片颜色相乘：普通平台用白色（原样），冰面压冷色
	var body_tint: Color = ICE_BODY_TINT if slippery else Color.WHITE
	var cap_tint: Color = ICE_CAP_TINT if slippery else Color.WHITE
	# 冰面顶换冰瓦片：光靠染色乘在绿草皮上还是绿的，分不出打滑平台
	var cap_tex: Texture2D = ICE_CAP_TEX if slippery else CAP_TEX

	# ① 砖块体
	var vis := get_node_or_null("Visual") as Polygon2D
	if vis != null:
		vis.polygon = PackedVector2Array([
			Vector2(-hw, -hh), Vector2(hw, -hh), Vector2(hw, hh), Vector2(-hw, hh),
		])
		vis.texture = BODY_TEX
		vis.texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
		# 不设 uv 数组时，UV 直接等于顶点坐标（单位：纹理像素），
		# 所以想让一格显示成 32px，texture_scale 要取 1/TILE_SCALE，不是 TILE_SCALE。
		vis.texture_scale = Vector2(1.0 / TILE_SCALE, 1.0 / TILE_SCALE)
		vis.color = body_tint

	# ② 顶面：草皮 / 冰瓦片，只能占一格高
	var cap := get_node_or_null("Cap") as Polygon2D
	if cap != null:
		# 薄平台（22px）顶面收窄到整块高度，厚平台固定 32px
		var cap_h: float = minf(size.y, float(CAP_H))
		cap.polygon = PackedVector2Array([
			Vector2(-hw, -hh), Vector2(hw, -hh),
			Vector2(hw, -hh + cap_h), Vector2(-hw, -hh + cap_h),
		])
		cap.texture = cap_tex
		cap.texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
		# CanvasItem.texture_repeat 是两个轴一起开的，光靠它顶面会在竖直方向也重复。
		# 这里手写 uv 把纵向锁死在 0 ~ cap_h/TILE_SCALE（整格时就是 0 ~ 16）个纹理像素。
		var u_w: float = size.x / float(TILE_SCALE)
		var v_h: float = cap_h / float(TILE_SCALE)
		cap.uv = PackedVector2Array([
			Vector2(0, 0), Vector2(u_w, 0),
			Vector2(u_w, v_h), Vector2(0, v_h),
		])
		cap.color = cap_tint

	# 旧的顶面亮线（美术接入前用 Line2D 画的）：万一有人把旧场景 revert 回来也别露出来
	var top := get_node_or_null("Top")
	if top != null:
		top.visible = false


func _ready() -> void:
	_apply_look()
