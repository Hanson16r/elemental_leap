extends Node2D
## 主菜单背景装饰。
##
## 分四层，各自按鼠标位置做视差（越近动得越多）：
##   1. 天空渐变 + 星云（几乎不动）
##   2. 星点（闪烁、缓慢游移）
##   3. 远山两层 PNG + 云雾
##   4. 两座浮岛 PNG（近处，动得最多）
## 再加一层压住画面下角的暗色岩壁 + 薄雾当前景。
##
## 远山和浮岛是 tools/gen_bg_art.py 预渲染出来的 PNG（scripts/ui/bg/），
## 程序里用 draw_colored_polygon 画不出自然的岩体轮廓，所以改成贴图。
## 想换风格就重跑那个脚本；想换位置就改下面 _islands / _ranges 里的坐标。

const CANVAS := Vector2(1152.0, 648.0)
const SEED := 20261030

## 视差强度：鼠标移动 1 个单位时各层的位移
const PARALLAX_FAR := Vector2(4.0, 2.0)
const PARALLAX_RANGE := Vector2(9.0, 5.0)
const PARALLAX_MID := Vector2(15.0, 9.0)
const PARALLAX_NEAR := Vector2(30.0, 16.0)

const SKY_TOP := Color(0.031, 0.051, 0.114)      # #080D1D
const SKY_MID := Color(0.063, 0.086, 0.180)      # #10162E
const SKY_LOW := Color(0.098, 0.078, 0.196)      # #191432
const SKY_BOTTOM := Color(0.129, 0.094, 0.227)   # #21183A

const NEBULA_A := Color(0.298, 0.310, 0.702)
const NEBULA_B := Color(0.243, 0.325, 0.671)
const NEBULA_C := Color(0.451, 0.302, 0.639)

const FOREGROUND_ROCK := Color(0.043, 0.059, 0.110)

const BG_DIR := "res://scripts/ui/bg/"

var _rng := RandomNumberGenerator.new()
var _time := 0.0
var _mouse_target := Vector2.ZERO
var _mouse_cur := Vector2.ZERO

var _sky_tex: GradientTexture2D
var _soft_tex: GradientTexture2D
var _range_far_tex: Texture2D
var _range_mid_tex: Texture2D
var _island_a_tex: Texture2D
var _island_b_tex: Texture2D

var _stars: Array[Dictionary] = []
var _nebulas: Array[Dictionary] = []
var _clouds: Array[Dictionary] = []

## 贴图摆放（改这里就能挪位置/换大小）
const RANGES := [
	{"key": "far", "pos": Vector2(-130.0, 296.0), "parallax": PARALLAX_FAR, "tint": Color(1, 1, 1, 0.85)},
	{"key": "mid", "pos": Vector2(-130.0, 352.0), "parallax": PARALLAX_RANGE, "tint": Color(1, 1, 1, 1.0)},
]
const ISLANDS := [
	{"key": "a", "pos": Vector2(44.0, 248.0), "size": Vector2(262.0, 237.0), "tint": Color(1, 1, 1, 0.88)},
	{"key": "b", "pos": Vector2(884.0, 340.0), "size": Vector2(236.0, 205.0), "tint": Color(1, 1, 1, 0.85)},
]


func _ready() -> void:
	_rng.seed = SEED
	_sky_tex = _make_sky_texture()
	_soft_tex = _make_soft_texture(256)
	_range_far_tex = _load_tex("range_far.png")
	_range_mid_tex = _load_tex("range_mid.png")
	_island_a_tex = _load_tex("island_a.png")
	_island_b_tex = _load_tex("island_b.png")
	_build_stars()
	_build_nebulas()
	_build_clouds()


func _process(delta: float) -> void:
	_time += delta
	var vp := get_viewport_rect().size
	if vp.x > 0.0 and vp.y > 0.0:
		var m := get_viewport().get_mouse_position() / vp
		_mouse_target = (m * 2.0 - Vector2.ONE).clamp(-Vector2.ONE, Vector2.ONE)
	_mouse_cur = _mouse_cur.lerp(_mouse_target, minf(1.0, delta * 2.5))
	queue_redraw()


func _draw() -> void:
	_draw_sky()
	_draw_nebulas()
	_draw_stars()
	_draw_ranges()
	_draw_islands()
	_draw_clouds()
	_draw_foreground()


func _parallax(amount: Vector2) -> Vector2:
	return -_mouse_cur * amount


func _load_tex(file_name: String) -> Texture2D:
	var path := BG_DIR + file_name
	if not ResourceLoader.exists(path):
		push_warning("[MenuFx] 缺少背景素材：%s（跑一下 tools/gen_bg_art.py）" % path)
		return null
	var res := load(path)
	return res as Texture2D


# ---------------------------------------------------------------- 天空 / 星云

func _make_sky_texture() -> GradientTexture2D:
	var grad := Gradient.new()
	grad.set_color(0, SKY_TOP)
	grad.set_color(1, SKY_BOTTOM)
	grad.add_point(0.34, SKY_MID)
	grad.add_point(0.68, SKY_LOW)
	var tex := GradientTexture2D.new()
	tex.gradient = grad
	tex.width = 4
	tex.height = 256
	tex.fill_from = Vector2(0.0, 0.0)
	tex.fill_to = Vector2(0.0, 1.0)
	return tex


func _make_soft_texture(size: int) -> GradientTexture2D:
	var grad := Gradient.new()
	grad.set_color(0, Color(1, 1, 1, 1))
	grad.set_color(1, Color(1, 1, 1, 0))
	grad.add_point(0.35, Color(1, 1, 1, 0.42))
	var tex := GradientTexture2D.new()
	tex.gradient = grad
	tex.width = size
	tex.height = size
	tex.fill = GradientTexture2D.FILL_RADIAL
	tex.fill_from = Vector2(0.5, 0.5)
	tex.fill_to = Vector2(0.5, 0.0)
	return tex


func _draw_sky() -> void:
	if _sky_tex != null:
		draw_texture_rect(_sky_tex, Rect2(Vector2(-40.0, -40.0), CANVAS + Vector2(80.0, 80.0)), false)


func _build_nebulas() -> void:
	_nebulas.clear()
	_nebulas.append({"pos": Vector2(268.0, 210.0), "size": Vector2(560.0, 300.0), "color": NEBULA_A, "alpha": 0.085})
	_nebulas.append({"pos": Vector2(880.0, 150.0), "size": Vector2(500.0, 260.0), "color": NEBULA_B, "alpha": 0.070})
	_nebulas.append({"pos": Vector2(650.0, 560.0), "size": Vector2(700.0, 240.0), "color": NEBULA_C, "alpha": 0.060})
	_nebulas.append({"pos": Vector2(120.0, 520.0), "size": Vector2(420.0, 240.0), "color": NEBULA_B, "alpha": 0.055})


func _draw_nebulas() -> void:
	for n in _nebulas:
		var pos: Vector2 = n["pos"]
		var size: Vector2 = n["size"]
		var col: Color = n["color"]
		var a: float = n["alpha"]
		var drift := Vector2(sin(_time * 0.05 + pos.x) * 8.0, cos(_time * 0.04 + pos.y) * 6.0)
		draw_texture_rect(_soft_tex, Rect2(pos - size * 0.5 + drift, size), false, Color(col, a))


# ---------------------------------------------------------------- 星点

func _build_stars() -> void:
	_stars.clear()
	# 中央菜单区不要抢镜：那里的星点更小更暗
	var clear := Rect2(300.0, 110.0, 552.0, 360.0)
	for i in 128:
		var pos := Vector2(_rng.randf_range(0.0, CANVAS.x), _rng.randf_range(0.0, CANVAS.y))
		var in_clear := clear.has_point(pos)
		var r := _rng.randf_range(0.5, 1.35) if not in_clear else _rng.randf_range(0.4, 0.9)
		if not in_clear and _rng.randf() < 0.10:
			r = _rng.randf_range(1.6, 2.4)
		_stars.append({
			"pos": pos,
			"r": r,
			"base": _rng.randf_range(0.22, 0.55) if not in_clear else _rng.randf_range(0.10, 0.26),
			"speed": _rng.randf_range(0.35, 1.6),
			"phase": _rng.randf_range(0.0, TAU),
			"glint": r > 1.5,
		})


func _draw_stars() -> void:
	var off := _parallax(PARALLAX_FAR)
	for s in _stars:
		var tw: float = 0.55 + 0.45 * sin(_time * float(s["speed"]) + float(s["phase"]))
		var a: float = float(s["base"]) * tw
		var p: Vector2 = s["pos"] + off
		var r: float = s["r"]
		var c := Color(0.85, 0.91, 1.0, a)
		draw_circle(p, r, c)
		if bool(s["glint"]):
			# 亮星加一点十字光，别全都一样圆
			draw_line(p - Vector2(r * 2.4, 0.0), p + Vector2(r * 2.4, 0.0), Color(0.8, 0.88, 1.0, a * 0.45), 0.8, true)
			draw_line(p - Vector2(0.0, r * 2.4), p + Vector2(0.0, r * 2.4), Color(0.8, 0.88, 1.0, a * 0.45), 0.8, true)
			draw_circle(p, r * 2.6, Color(0.6, 0.75, 1.0, a * 0.12))


# ---------------------------------------------------------------- 远山 / 浮岛

func _draw_ranges() -> void:
	for r in RANGES:
		var key: String = r["key"]
		var tex: Texture2D = _range_far_tex if key == "far" else _range_mid_tex
		if tex == null:
			continue
		var off := _parallax(r["parallax"])
		var pos: Vector2 = r["pos"] + off
		draw_texture_rect(tex, Rect2(pos, tex.get_size()), false, r["tint"])


func _draw_islands() -> void:
	for isl in ISLANDS:
		var key: String = isl["key"]
		var tex: Texture2D = _island_a_tex if key == "a" else _island_b_tex
		if tex == null:
			continue
		var off := _parallax(PARALLAX_MID)
		var pos: Vector2 = isl["pos"] + off
		var size: Vector2 = isl["size"]
		# 岛底一团空气光：让它"浮"起来，还能把贴图的硬边化掉
		draw_texture_rect(_soft_tex, Rect2(
			pos + Vector2(size.x * 0.5, size.y * 0.56) - size * Vector2(0.72, 0.42),
			size * 1.44
		), false, Color(0.35, 0.46, 0.86, 0.055))
		draw_texture_rect(tex, Rect2(pos, size), false, isl["tint"])


# ---------------------------------------------------------------- 云雾

func _build_clouds() -> void:
	_clouds.clear()
	# 云分两层：远处的慢、近处的快，方向相反
	for i in 4:
		_clouds.append({
			"pos": Vector2(_rng.randf_range(-200.0, CANVAS.x + 200.0), _rng.randf_range(150.0, 470.0)),
			"size": Vector2(_rng.randf_range(360.0, 620.0), _rng.randf_range(90.0, 160.0)),
			"alpha": _rng.randf_range(0.045, 0.075),
			"speed": _rng.randf_range(3.0, 7.0),
			"near": false,
		})
	for i in 3:
		_clouds.append({
			"pos": Vector2(_rng.randf_range(-200.0, CANVAS.x + 200.0), _rng.randf_range(380.0, 600.0)),
			"size": Vector2(_rng.randf_range(460.0, 780.0), _rng.randf_range(90.0, 150.0)),
			"alpha": _rng.randf_range(0.05, 0.08),
			"speed": _rng.randf_range(-9.0, -4.0),
			"near": true,
		})


func _draw_clouds() -> void:
	for c in _clouds:
		var near: bool = c["near"]
		var off := _parallax(PARALLAX_NEAR if near else PARALLAX_MID)
		var drift_x: float = fmod(float(c["speed"]) * _time, CANVAS.x + 900.0)
		var pos: Vector2 = c["pos"] + off + Vector2(drift_x, 0.0)
		var size: Vector2 = c["size"]
		# 云朵出画面就从另一边绕回来
		if pos.x > CANVAS.x + 340.0:
			pos.x -= CANVAS.x + 900.0
		if pos.x < -340.0:
			pos.x += CANVAS.x + 900.0
		draw_texture_rect(_soft_tex, Rect2(pos - size * 0.5, size), false,
			Color(0.55, 0.66, 0.92, float(c["alpha"])))


# ---------------------------------------------------------------- 前景

func _draw_foreground() -> void:
	var off := _parallax(PARALLAX_NEAR)
	# 左右下角的暗色岩壁：压住画面边角、增加前景景深；中央留空，绝不挡按钮
	draw_colored_polygon(PackedVector2Array([
		Vector2(-40.0, 690.0) + off, Vector2(-40.0, 566.0) + off, Vector2(34.0, 592.0) + off,
		Vector2(118.0, 612.0) + off, Vector2(188.0, 648.0) + off, Vector2(222.0, 690.0) + off,
	]), Color(FOREGROUND_ROCK, 0.85))
	draw_colored_polygon(PackedVector2Array([
		Vector2(1192.0, 690.0) + off, Vector2(1192.0, 572.0) + off, Vector2(1124.0, 596.0) + off,
		Vector2(1054.0, 620.0) + off, Vector2(998.0, 654.0) + off, Vector2(968.0, 690.0) + off,
	]), Color(FOREGROUND_ROCK, 0.85))
	# 前景一层薄雾：把近景和菜单之间"隔"开
	draw_texture_rect(_soft_tex, Rect2(Vector2(-80.0, 496.0) + off * 0.6, Vector2(760.0, 210.0)),
		false, Color(0.42, 0.52, 0.80, 0.06))
	draw_texture_rect(_soft_tex, Rect2(Vector2(600.0, 512.0) + off * 0.6, Vector2(700.0, 200.0)),
		false, Color(0.42, 0.52, 0.80, 0.05))
