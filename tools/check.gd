extends Node
## 项目自检 —— 改坏了项目时用它快速定位
##
## 用法一：双击项目根目录的「自检.bat」
## 用法二：命令行
##   Godot_v4.7.2-stable_win64.exe --headless --path <项目目录> --quit res://scenes/check.tscn
##
## 它会依次做四件事：
##   1. 加载所有 .gd 脚本（语法错误会在这里暴露）
##   2. 加载并实例化所有 .tscn 场景（节点/资源引用错误会在这里暴露）
##   3. 核对输入映射（left/right/jump/restart）
##   4. 核对主场景、单例配置，以及「选择角色」用到的行走图
## 有任何一项失败就以退出码 1 结束，方便脚本判断。

const REQUIRED_ACTIONS := ["left", "right", "jump", "restart"]
const REQUIRED_AUTOLOADS := ["Events", "GameState", "Sfx", "Characters"]
const LEVEL_SCENES := [
	"res://scenes/levels/level_1.tscn",
	"res://scenes/levels/level_2.tscn",
	"res://scenes/levels/level_3.tscn",
	"res://scenes/levels/level_4.tscn",
	"res://scenes/levels/level_5.tscn",
	"res://scenes/levels/level_6.tscn",
	"res://scenes/levels/level_7.tscn",
	"res://scenes/levels/level_8.tscn",
	"res://scenes/levels/level_9.tscn",
	"res://scenes/levels/level_10.tscn",
	"res://scenes/levels/level_11.tscn",
]

var _errors: int = 0


func _ready() -> void:
	print("")
	print("========== 冰塔跳跃 Demo · 项目自检 ==========")

	var gd_files: Array[String] = []
	var tscn_files: Array[String] = []
	_collect("res://", gd_files, tscn_files)

	_check_scripts(gd_files)
	_check_scenes(tscn_files)
	_check_inputs()
	_check_globals()

	print("")
	if _errors == 0:
		print(">>> OK 自检通过：脚本、场景、输入映射、单例、主场景全部正常。")
	else:
		print(">>> BAD 自检发现 ", _errors, " 个问题，看上面带 FAIL 的行。")
	print("============================================")

	get_tree().quit(0 if _errors == 0 else 1)


func _fail(msg: String) -> void:
	_errors += 1
	print("FAIL   ", msg)


func _ok(msg: String) -> void:
	print("ok     ", msg)


# ------------------------------------------------------------------ 1. 脚本

func _check_scripts(files: Array[String]) -> void:
	print("--- 1/4 加载脚本（", files.size(), " 个）---")
	for path in files:
		var res := ResourceLoader.load(path, "Script")
		if res == null:
			_fail("脚本加载失败：" + path)
		elif not (res is Script):
			_fail("不是脚本：" + path)
		else:
			_ok(path)


# ------------------------------------------------------------------ 2. 场景

func _check_scenes(files: Array[String]) -> void:
	print("--- 2/4 加载并实例化场景（", files.size(), " 个）---")
	for path in files:
		var packed := ResourceLoader.load(path, "PackedScene") as PackedScene
		if packed == null:
			_fail("场景加载失败：" + path)
			continue
		var node := packed.instantiate()
		if node == null:
			_fail("场景实例化失败：" + path)
			continue
		node.free()
		_ok(path)


# ------------------------------------------------------------------ 3. 输入

func _check_inputs() -> void:
	print("--- 3/4 输入映射 ---")
	for action in REQUIRED_ACTIONS:
		if InputMap.has_action(action):
			_ok("输入动作 " + action)
		else:
			_fail("缺少输入动作：" + action + "（项目设置 → 输入映射 里补）")


# ------------------------------------------------------------------ 4. 全局配置

func _check_globals() -> void:
	print("--- 4/4 主场景与单例 ---")
	var main := str(ProjectSettings.get_setting("application/run/main_scene", ""))
	if main == "":
		_fail("没有设置主场景")
	elif ResourceLoader.exists(main):
		_ok("主场景 = " + main)
	else:
		_fail("主场景指向的文件不存在：" + main)

	for name in REQUIRED_AUTOLOADS:
		var path := str(ProjectSettings.get_setting("autoload/" + name, ""))
		if path == "":
			_fail("缺少单例（autoload）：" + name)
		else:
			_ok("单例 " + name + " = " + path)

	for path in LEVEL_SCENES:
		if ResourceLoader.exists(path):
			_ok("关卡存在 " + path)
		else:
			_fail("关卡文件不存在：" + path)

	# 角色图鉴：照着「选择角色」界面真正会走的那条路切一次图，
	# 图丢了 / 尺寸不够 / 表格填错都会在这里暴露。
	for entry in Characters.ROSTER:
		var id := str(entry["id"])
		if Characters.build_frames(id) == null:
			_fail("角色 %s 的行走图切不出来：%s" % [id, str(entry["sheet"])])
		else:
			_ok("角色 " + id)


# ------------------------------------------------------------------ 工具

func _collect(dir_path: String, gd_files: Array[String], tscn_files: Array[String]) -> void:
	var dir := DirAccess.open(dir_path)
	if dir == null:
		return
	dir.list_dir_begin()
	var entry := dir.get_next()
	while entry != "":
		if not entry.begins_with("."):
			var full := dir_path.path_join(entry)
			if dir.current_is_dir():
				_collect(full, gd_files, tscn_files)
			elif entry.ends_with(".gd"):
				gd_files.append(full)
			elif entry.ends_with(".tscn"):
				tscn_files.append(full)
		entry = dir.get_next()
	dir.list_dir_end()
