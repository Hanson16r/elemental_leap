extends Control
## 单个元素图标（72×72），全部用 _draw() 画，不依赖任何图片资源。
##
## 第二轮美术：每个图标都拆成「外发光 → 地面投影 → 主体（多层渐变）→ 高光 → 细节」，
## 靠同一色相的明暗层叠出材质感，而不是一块纯色。四个图标共用一套画法：
##   - 光晕：几圈很淡的同色圆（不用真发光，避免霓虹感）
##   - 投影：底部一枚压扁的椭圆，让图标"站"在卡片上
##   - 主体：由大到小叠 3~4 层，每层提亮一点 → 大概率的渐变感
##   - 高光：一条短亮线 / 一个小亮点，方向统一从左上来
##
## 为什么绘制必须放在这个脚本的 _draw() 里：外层 Control 连 CanvasItem 的 draw 信号
## 也能"触发"，但画出来的东西不进渲染（实测四张卡片全空）。别改回去。
##
## 只认两个字段：kind（形状）和 accent（主色），换配色只改这两个外部传进来的值。

const ICON := Vector2(72.0, 72.0)

var kind: int = Element.Kind.FIRE
var accent: Color = Color(1.0, 0.6, 0.34)


func _ready() -> void:
	size = ICON
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _draw() -> void:
	var c := ICON * 0.5
	match kind:
		Element.Kind.FIRE:
			_glow(c, 26.0)
			_shadow(c, 13.0, 4.0)
			_draw_fire(c)
		Element.Kind.ICE:
			_glow(c, 27.0)
			_shadow(c, 12.0, 3.6)
			_draw_ice(c)
		Element.Kind.WIND:
			_glow(c, 26.0)
			_shadow(c, 11.0, 3.2)
			_draw_wind(c)
		_:
			_glow(c, 25.0)
			_shadow(c, 13.0, 4.2)
			_draw_rock(c)


# ---------------------------------------------------------------- 通用：光晕 / 投影

## 三圈极淡的同色圆，代替真发光（避免"霓虹"）
func _glow(c: Vector2, radius: float) -> void:
	for i in 3:
		var k := 1.0 - float(i) * 0.28
		draw_circle(c, radius * k, Color(accent.r, accent.g, accent.b, 0.035 + float(i) * 0.02))


## 底部压扁椭圆投影（右上更浅，做出左上方来光的感觉）
func _shadow(c: Vector2, rx: float, ry: float) -> void:
	draw_colored_polygon(_ellipse(c + Vector2(0.0, 24.0), rx, ry), Color(0.02, 0.03, 0.06, 0.30))
	draw_colored_polygon(_ellipse(c + Vector2(0.0, 23.2), rx * 0.78, ry * 0.72), Color(0.02, 0.03, 0.06, 0.22))


# ---------------------------------------------------------------- 火

func _draw_fire(c: Vector2) -> void:
	var outer := PackedVector2Array([
		c + Vector2(1, -27), c + Vector2(10, -11), c + Vector2(15, 1),
		c + Vector2(12, 13), c + Vector2(4, 21), c + Vector2(-5, 22),
		c + Vector2(-13, 15), c + Vector2(-15, 4), c + Vector2(-10, -7),
		c + Vector2(-5, -15),
	])
	# 外焰：偏暗、压饱和度，当"体积"
	draw_colored_polygon(outer, Color(accent.darkened(0.38), 1.0))
	# 中焰
	var mid := _scale_pts(outer, c + Vector2(0.0, 3.0), 0.80)
	draw_colored_polygon(mid, Color(accent.darkened(0.06), 1.0))
	# 内焰
	var inner := _scale_pts(outer, c + Vector2(0.0, 6.0), 0.58)
	draw_colored_polygon(inner, Color(accent.lightened(0.22), 1.0))
	# 焰心
	var core := _scale_pts(outer, c + Vector2(-0.6, 9.0), 0.34)
	draw_colored_polygon(core, Color(1.0, 0.95, 0.82, 0.95))
	# 高光：左侧一小块亮斑
	draw_colored_polygon(_ellipse(c + Vector2(-5.0, 8.0), 3.6, 6.2), Color(1.0, 0.98, 0.90, 0.45))
	# 火星：上方两点
	draw_circle(c + Vector2(7.5, -21.0), 1.6, Color(accent.lightened(0.35), 0.85))
	draw_circle(c + Vector2(-6.5, -18.0), 1.1, Color(accent.lightened(0.25), 0.65))


# ---------------------------------------------------------------- 冰

func _draw_ice(c: Vector2) -> void:
	var r := 25.0
	for i in 3:
		var ang: float = -PI * 0.5 + float(i) * PI / 3.0
		var dir := Vector2(cos(ang), sin(ang))
		var tail := c - dir * r
		var head := c + dir * r
		# 底：一笔更宽更暗的线，做出厚度
		draw_line(tail, head, Color(accent.darkened(0.45), 0.35), 6.0, true)
		# 主体
		draw_line(tail, head, accent, 3.6, true)
		# 高光：细白线，整体偏上偏左
		draw_line(tail + Vector2(-0.4, -0.9), head + Vector2(-0.4, -0.9),
			Color(1.0, 1.0, 1.0, 0.55), 1.2, true)
		# 两侧分枝
		for s in [0.52, 0.80]:
			var base: Vector2 = c + dir * (r * s)
			for side in [-1.0, 1.0]:
				var b_ang: float = ang + side * 0.66
				var b_dir := Vector2(cos(b_ang), sin(b_ang))
				var tip := base + b_dir * 9.5
				draw_line(base, tip, Color(accent.darkened(0.40), 0.30), 4.4, true)
				draw_line(base, tip, accent, 2.6, true)
				draw_line(base + Vector2(-0.3, -0.7), tip + Vector2(-0.3, -0.7),
					Color(1.0, 1.0, 1.0, 0.45), 0.9, true)
	# 中心：暗六边形 + 亮六边形 + 一点冰蓝高光
	draw_colored_polygon(_ngon(c, 5.4, 6), Color(accent.darkened(0.30), 0.95))
	draw_colored_polygon(_ngon(c + Vector2(-0.4, -0.4), 3.4, 6), Color(accent.lightened(0.45), 0.95))
	draw_circle(c + Vector2(-0.9, -0.9), 1.2, Color(1.0, 1.0, 1.0, 0.9))
	# 尖端小亮点（像结霜）
	for i in 3:
		var ang: float = -PI * 0.5 + float(i) * PI / 3.0
		var d := Vector2(cos(ang), sin(ang))
		draw_circle(c + d * (r + 2.4), 1.3, Color(0.86, 0.97, 1.0, 0.75))


# ---------------------------------------------------------------- 风

func _draw_wind(c: Vector2) -> void:
	for k in 3:
		var pts := PackedVector2Array()
		var base_y: float = c.y - 12.0 + float(k) * 11.0
		for i in 19:
			var t := float(i) / 18.0
			var x: float = c.x - 26.0 + t * 44.0
			var y: float = base_y + sin(t * TAU + float(k) * 0.6) * 3.2
			pts.append(Vector2(x, y))
		# 底下淡一笔当"气流厚度"
		draw_polyline(pts, Color(accent.r, accent.g, accent.b, 0.16), 7.0, true)
		# 主线
		draw_polyline(pts, Color(accent.darkened(0.10), 0.98), 3.4, true)
		# 高光细线
		var hi := PackedVector2Array()
		for p: Vector2 in pts:
			hi.append(p + Vector2(0.0, -0.8))
		draw_polyline(hi, Color(accent.lightened(0.45), 0.75), 1.1, true)
		# 收尾渐细：末尾一小段换成更细的线
		if pts.size() > 5:
			var tail := PackedVector2Array()
			for i in range(pts.size() - 6, pts.size()):
				tail.append(pts[i])
			draw_polyline(tail, Color(accent.lightened(0.15), 0.55), 1.4, true)

	# 两处卷涡：外深内亮两笔
	draw_arc(Vector2(c.x + 20.0, c.y - 13.0), 6.4, -PI * 0.95, PI * 0.45, 16,
		Color(accent.darkened(0.35), 0.55), 3.6, true)
	draw_arc(Vector2(c.x + 20.0, c.y - 13.0), 6.4, -PI * 0.95, PI * 0.45, 16,
		Color(accent.lightened(0.30), 0.9), 1.5, true)
	draw_arc(Vector2(c.x + 14.0, c.y + 13.0), 5.2, PI * 0.35, PI * 1.85, 16,
		Color(accent.darkened(0.35), 0.5), 3.2, true)
	draw_arc(Vector2(c.x + 14.0, c.y + 13.0), 5.2, PI * 0.35, PI * 1.85, 16,
		Color(accent.lightened(0.28), 0.85), 1.3, true)

	# 被吹起来的三个小点（大小递减）
	draw_circle(c + Vector2(24.0, 8.0), 1.7, Color(accent.lightened(0.35), 0.8))
	draw_circle(c + Vector2(27.5, 13.0), 1.2, Color(accent.lightened(0.25), 0.6))
	draw_circle(c + Vector2(21.5, 16.5), 0.9, Color(accent.lightened(0.15), 0.45))


# ---------------------------------------------------------------- 岩

func _draw_rock(c: Vector2) -> void:
	var body := PackedVector2Array([
		c + Vector2(-22, -3), c + Vector2(-14, -19), c + Vector2(3, -25),
		c + Vector2(18, -16), c + Vector2(24, 2), c + Vector2(13, 18),
		c + Vector2(-7, 21), c + Vector2(-20, 10),
	])
	var center := c + Vector2(0.0, -1.0)
	# 体块：暗底
	draw_colored_polygon(body, Color(accent.darkened(0.42), 1.0))
	# 主面（往中心收一点，留出暗边）
	draw_colored_polygon(_scale_pts(body, center, 0.90), Color(accent.darkened(0.12), 1.0))
	# 三个切面：亮面（左上）、中间调、暗面（右下） → 假 3D
	draw_colored_polygon(_scale_pts(body, center + Vector2(-3.0, -3.0), 0.62),
		Color(accent.lightened(0.16), 0.95))
	draw_colored_polygon(_scale_pts(body, center + Vector2(4.0, 2.0), 0.40),
		Color(accent.darkened(0.30), 0.85))
	# 棱线
	draw_line(c + Vector2(-22, -3), c + Vector2(-2, 4), Color(0.05, 0.05, 0.08, 0.45), 1.8, true)
	draw_line(c + Vector2(-2, 4), c + Vector2(18, -16), Color(0.05, 0.05, 0.08, 0.40), 1.6, true)
	draw_line(c + Vector2(-2, 4), c + Vector2(13, 18), Color(0.05, 0.05, 0.08, 0.35), 1.4, true)
	# 左上高光边（来光方向统一）
	draw_line(c + Vector2(-20.5, -4.5), c + Vector2(-13.0, -17.5),
		Color(1.0, 0.98, 0.92, 0.30), 1.6, true)
	draw_line(c + Vector2(-13.0, -17.5), c + Vector2(2.0, -23.0),
		Color(1.0, 0.98, 0.92, 0.22), 1.2, true)
	# 苔点 / 碎石：底部三小点，给点"活着"的细节
	draw_circle(c + Vector2(-8.0, 14.0), 1.5, Color(0.42, 0.62, 0.42, 0.55))
	draw_circle(c + Vector2(-3.5, 17.0), 1.0, Color(0.42, 0.62, 0.42, 0.40))
	draw_circle(c + Vector2(9.0, 12.0), 1.2, Color(0.30, 0.26, 0.20, 0.55))


# ---------------------------------------------------------------- 形状工具

func _ngon(center: Vector2, radius: float, segments: int) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in segments:
		var ang := -PI * 0.5 + TAU * float(i) / float(segments)
		pts.append(center + Vector2(cos(ang), sin(ang)) * radius)
	return pts


func _ellipse(center: Vector2, rx: float, ry: float, segments: int = 18) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in segments:
		var ang := TAU * float(i) / float(segments)
		pts.append(center + Vector2(cos(ang) * rx, sin(ang) * ry))
	return pts


## 以 anchor 为中心缩放多边形（用来叠出"由大到小"的渐变层）
func _scale_pts(pts: PackedVector2Array, anchor: Vector2, factor: float) -> PackedVector2Array:
	var out := PackedVector2Array()
	for p: Vector2 in pts:
		out.append(anchor + (p - anchor) * factor)
	return out
