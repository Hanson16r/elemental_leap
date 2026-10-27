class_name Element
extends RefCounted
## 【元素系统的唯一数据源】
##
## 为什么要把"名字 / 颜色 / 枚举"集中在一个文件里？
## 因为元素球、HUD、接收器、关卡脚本都要用到它们。如果每个文件各写一份，
## 以后加"雷"的时候要改 5 个地方，一定漏。集中在这里，只改一处。
##
## 用法：
##   Element.Kind.FIRE
##   Element.name_of(kind)   -> "火"
##   Element.color_of(kind)  -> Color(...)
##
## 10 天版只实现火/水/冰/风；雷/草/石保留在枚举里，先写进设计文档。

enum Kind {
	NONE,
	FIRE,
	WATER,
	ICE,
	WIND,
	LIGHTNING,
	GRASS,
	ROCK,
}


## 元素的中文名（HUD、元素球上的字都用它）
static func name_of(kind: int) -> String:
	match kind:
		Kind.FIRE:
			return "火"
		Kind.WATER:
			return "水"
		Kind.ICE:
			return "冰"
		Kind.WIND:
			return "风"
		Kind.LIGHTNING:
			return "雷"
		Kind.GRASS:
			return "草"
		Kind.ROCK:
			return "石"
		_:
			return "无"


## 元素的代表色（元素球、HUD、接收器都用它）
static func color_of(kind: int) -> Color:
	match kind:
		Kind.FIRE:
			return Color(1.0, 0.45, 0.18)
		Kind.WATER:
			return Color(0.25, 0.65, 1.0)
		Kind.ICE:
			return Color(0.65, 0.95, 1.0)
		Kind.WIND:
			return Color(0.55, 1.0, 0.75)
		Kind.LIGHTNING:
			return Color(1.0, 0.9, 0.35)
		Kind.GRASS:
			return Color(0.45, 0.9, 0.45)
		Kind.ROCK:
			return Color(0.7, 0.65, 0.55)
		_:
			return Color(0.75, 0.78, 0.82)


## 10 天版真正实现的元素。雷/草只写设计文档，先不做。
static func is_implemented(kind: int) -> bool:
	return kind == Kind.FIRE or kind == Kind.WATER or kind == Kind.ICE \
		or kind == Kind.WIND or kind == Kind.ROCK
