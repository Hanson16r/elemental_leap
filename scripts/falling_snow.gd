extends Node2D
## 飘雪粒子 —— 对应 Day 12「用 CPUParticles2D 做简单雪雾粒子，接近截图氛围」
##
## 分成两层：远处的细雪（慢、小、暗）+ 近处的雪片（快、大、亮），
## 这样有景深感，比单层粒子好看很多。
##
## 注意：粒子节点要挂在 CanvasLayer（背景层）上，不能挂在世界节点上，
## 否则相机移动时雪会跟着世界一起动，看起来就像"雪粘在空气上"。

var _far: CPUParticles2D
var _near: CPUParticles2D
var _built: bool = false


## 直接放进场景树里也能用（主菜单就是这么用的），会自动按窗口大小铺满
func _ready() -> void:
	if not _built:
		var vp := get_viewport_rect().size
		setup(Vector2(maxf(vp.x, 1152.0), maxf(vp.y, 648.0)))


func setup(area: Vector2) -> void:
	_built = true
	_far = CPUParticles2D.new()
	_far.name = "SnowFar"
	_far.amount = 90
	_far.lifetime = 14.0
	_far.preprocess = 14.0                 # 一开始就已经满屏是雪，不用等
	_far.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	_far.emission_rect_extents = Vector2(area.x * 0.6, 40)
	_far.position = Vector2(area.x * 0.5, -40)
	_far.direction = Vector2(0.15, 1)
	_far.spread = 8.0
	_far.gravity = Vector2(6, 28)
	_far.initial_velocity_min = 6.0
	_far.initial_velocity_max = 20.0
	_far.scale_amount_min = 0.8
	_far.scale_amount_max = 1.8
	_far.color = Color(0.78, 0.88, 1.0, 0.40)
	add_child(_far)

	_near = CPUParticles2D.new()
	_near.name = "SnowNear"
	_near.amount = 34
	_near.lifetime = 9.0
	_near.preprocess = 9.0
	_near.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	_near.emission_rect_extents = Vector2(area.x * 0.6, 40)
	_near.position = Vector2(area.x * 0.5, -60)
	_near.direction = Vector2(0.3, 1)
	_near.spread = 12.0
	_near.gravity = Vector2(14, 70)
	_near.initial_velocity_min = 20.0
	_near.initial_velocity_max = 50.0
	_near.scale_amount_min = 2.0
	_near.scale_amount_max = 4.0
	_near.color = Color(0.92, 0.97, 1.0, 0.65)
	add_child(_near)
