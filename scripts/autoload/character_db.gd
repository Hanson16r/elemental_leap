extends Node
## 【单例 / 角色图鉴】—— 主菜单「选择角色」要用的数据全在这里。
##
## 一张行走图（scripts/character/*.png）是 576×384，可以切成 48×48 的小格子：
##   横向 12 列 = 4 组，每组 3 帧（站立 / 迈左脚 / 迈右脚）；
##   纵向 8 行  = 2 段，每段 4 行朝向（下 / 左 / 右 / 上）。
## 所以**一张图里其实躺着 4×2 = 8 个不同的角色**。
##
## 本项目只用其中一组：group 0（第 1~3 列）+ block 0（第 1~4 行）。
##   · idle 动画取这一段的第 0 行（正面站立）
##   · run  动画取这一段的第 2 行
## 和 scenes/player.tscn 里原来手摆的 AtlasTexture 完全一致，
## 所以选了「蒙德少女」就等于回到改动之前的样子。
##
## 想加新角色只要两步：
##   1. 把图片丢进 scripts/character/（同样是 576×384 的行走图）；
##   2. 在下面 ROSTER 里照抄一段，换 id / name / desc / sheet。
## 想用同一张图里的其它小人？改 group（0~3）或 block（0~1）就行。

## 单帧边长（像素）
const FRAME_SIZE := 48
## 一个动画几帧
const FRAMES_PER_ANIM := 3
## 一个 block 几行
const ROWS_PER_BLOCK := 4
## idle 用 block 里的第几行（0 = 正面站立）
const IDLE_ROW := 0
## run 用 block 里的第几行
const RUN_ROW := 2
## 动画帧率
const ANIM_FPS := 12.0

## 默认角色：没选过、或存档是旧版（还没有这一项）时用它。
## 故意和原来 player.tscn 里那张图一致 —— 老玩家打开不会觉得「我的角色变了」。
const DEFAULT_ID := "mond_girl"

## 可选角色表。顺序 = 界面上的顺序。
## id    存档里记的字符串（改它会丢玩家的选择，尽量别改）
## name  界面上显示的名字
## desc  卡片下面那行小字
## sheet 行走图路径
## group / block  取这张图的哪一小块（见文件开头说明）
const ROSTER: Array = [
	{
		"id": "li_yue_boy",
		"name": "璃月少年",
		"desc": "褐发，沉得住气",
		"sheet": "res://scripts/character/1璃月行走图男.png",
		"group": 0,
		"block": 0,
	},
	{
		"id": "mond_boy",
		"name": "蒙德少年",
		"desc": "金发，脚步轻快",
		"sheet": "res://scripts/character/1蒙德行走图男.png",
		"group": 0,
		"block": 0,
	},
	{
		"id": "li_yue_girl",
		"name": "璃月少女",
		"desc": "白衣白发",
		"sheet": "res://scripts/character/2璃月行走图女1.png",
		"group": 0,
		"block": 0,
	},
	{
		"id": "mond_girl",
		"name": "蒙德少女",
		"desc": "金发，默认角色",
		"sheet": "res://scripts/character/2蒙德行走图女1.png",
		"group": 0,
		"block": 0,
	},
]

## 切好的 SpriteFrames 缓存：{"mond_girl": SpriteFrames, ...}
## 4 张卡片 + 玩家自己，一共只会切 4 次图，之后都复用同一个资源。
var _frames_cache: Dictionary = {}


# ===================================================================== 查询

## 按 id 找一条角色数据；找不到返回空字典
func get_entry(id: String) -> Dictionary:
	for entry in ROSTER:
		if str(entry["id"]) == id:
			return entry
	return {}


## 按 id 找角色数据；找不到就退回默认角色（存档被手改坏了也不会崩）
func get_entry_or_default(id: String) -> Dictionary:
	var entry := get_entry(id)
	if entry.is_empty():
		return get_entry(DEFAULT_ID)
	return entry


## 当前选中的角色 id。
## 真正的数据存在 GameState.character_id（跟着关卡进度存进同一个存档文件），
## 这里只是顺手兜个底：存档里没有 / 写了不认识的 id 时，回默认角色。
func selected_id() -> String:
	if get_entry(GameState.character_id).is_empty():
		GameState.character_id = DEFAULT_ID
	return GameState.character_id


## 当前选中的那条角色数据（界面显示名字用）
func selected_entry() -> Dictionary:
	return get_entry_or_default(selected_id())


## 选中一个角色并存档。id 不认识就什么都不做（防手改存档）
func select(id: String) -> bool:
	if get_entry(id).is_empty():
		push_warning("[Characters] 没有这个角色：" + id)
		return false
	GameState.character_id = id
	GameState.save_progress()
	return true


# ===================================================================== 行走图 → 动画

## 把一张行走图里的一小块切成 SpriteFrames（idle 3 帧 + run 3 帧）。
## AnimatedSprite2D.sprite_frames 直接吃它；玩家和选人卡片用的是同一份。
func build_frames(id: String) -> SpriteFrames:
	if _frames_cache.has(id):
		return _frames_cache[id]

	var entry := get_entry_or_default(id)
	var sheet_path := str(entry["sheet"])
	if not ResourceLoader.exists(sheet_path):
		push_warning("[Characters] 找不到行走图：" + sheet_path)
		return null
	var tex := load(sheet_path) as Texture2D
	if tex == null:
		push_warning("[Characters] 行走图加载失败：" + sheet_path)
		return null

	var frames := SpriteFrames.new()
	# SpriteFrames 新建时自带一个空的 "default" 动画，删掉免得 HUD 里多一项
	if frames.has_animation("default"):
		frames.remove_animation("default")
	_add_anim(frames, "idle", tex, entry, IDLE_ROW)
	_add_anim(frames, "run", tex, entry, RUN_ROW)

	_frames_cache[id] = frames
	return frames


## 往 frames 里加一个动画：从 tex 的第 row 行切 FRAMES_PER_ANIM 帧
func _add_anim(frames: SpriteFrames, anim_name: String, tex: Texture2D,
		entry: Dictionary, row: int) -> void:
	frames.add_animation(anim_name)
	frames.set_animation_loop(anim_name, true)
	frames.set_animation_speed(anim_name, ANIM_FPS)

	var group := int(entry["group"])
	var block := int(entry["block"])
	# 行号要加上 block 的偏移：block 0 从第 0 行开始，block 1 从第 4 行开始
	var y := (block * ROWS_PER_BLOCK + row) * FRAME_SIZE

	for i in FRAMES_PER_ANIM:
		# 列号同理：group 0 从第 0 列开始，group 1 从第 3 列开始
		var x := (group * FRAMES_PER_ANIM + i) * FRAME_SIZE
		var atlas := AtlasTexture.new()
		atlas.atlas = tex
		atlas.region = Rect2(x, y, FRAME_SIZE, FRAME_SIZE)
		frames.add_frame(anim_name, atlas)
