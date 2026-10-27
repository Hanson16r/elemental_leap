extends Node
## 【单例 / 音效】—— 对应计划 Day 12「加背景音乐、跳跃音、死亡音」
##
## 这一版**不需要任何外部音频文件**：所有音效都是用代码算出波形再塞给引擎的。
## 为什么这么做？因为免费素材的授权很容易踩坑，而且下载素材对新手是额外的坑。
## 等你 Day 12 真的找到了 CC0 素材，把 _make_* 换成 load("res://audio/jump.wav") 就行。

## 总音量（暂停菜单里可以调）
var volume_db: float = -6.0

var _players: Array[AudioStreamPlayer] = []
var _next := 0
const VOICES := 6

var _jump: AudioStream
var _land: AudioStream
var _die: AudioStream
var _check: AudioStream
var _finish: AudioStream
var _click: AudioStream
var _pickup: AudioStream
var _element_use: AudioStream
var _element_clear: AudioStream


func _ready() -> void:
	# 多开几个播放器轮流用，避免"上一个音还没播完就被打断"
	for i in VOICES:
		var p := AudioStreamPlayer.new()
		p.bus = &"Master"
		p.volume_db = volume_db
		add_child(p)
		_players.append(p)

	# 采样率 22050 够用了，文件小、生成快
	_jump = _tone(0.12, 300.0, 800.0, 0.55, "square")
	_land = _tone(0.07, 180.0, 90.0, 0.35, "square")
	_die = _sweep_noise(0.45)
	_check = _chime()
	_finish = _fanfare()
	_click = _tone(0.05, 900.0, 700.0, 0.3, "sine")
	_pickup = _tone(0.10, 700.0, 1200.0, 0.45, "sine")
	_element_use = _tone(0.18, 240.0, 90.0, 0.5, "square")
	_element_clear = _tone(0.20, 320.0, 60.0, 0.35, "sine")


# ===================================================================== 对外接口

func play_jump() -> void:
	_play(_jump)


func play_land(force: float = 1.0) -> void:
	_play(_land, linear_to_db(clampf(force, 0.2, 1.0)))


func play_death() -> void:
	_play(_die)


func play_checkpoint() -> void:
	_play(_check)


func play_finish() -> void:
	_play(_finish)


func play_click() -> void:
	_play(_click)


## 捡起元素球：一声短促的上滑音
func play_pickup() -> void:
	_play(_pickup)


## 元素被用掉：一声"咚"的闷响（火盆 / 融冰 / 冻水共用）
func play_element_use() -> void:
	_play(_element_use)


## 火被浇灭：一声往下掉的水声
func play_element_clear() -> void:
	_play(_element_clear)


func set_volume(v: float) -> void:
	volume_db = linear_to_db(clampf(v, 0.0001, 1.0))
	for p in _players:
		p.volume_db = volume_db


func get_volume() -> float:
	return db_to_linear(volume_db)


# ===================================================================== 内部

func _play(stream: AudioStream, extra_db: float = 0.0) -> void:
	if stream == null:
		return
	var p := _players[_next]
	_next = (_next + 1) % VOICES
	p.stream = stream
	p.volume_db = volume_db + extra_db
	p.play()


## 生成一段"频率从 f0 滑到 f1"的音
func _tone(dur: float, f0: float, f1: float, amp: float, shape: String) -> AudioStreamWAV:
	return _make_wav(dur, func(t: float) -> float:
		var k := t / dur
		var f := lerpf(f0, f1, k)
		var phase := fmod(f * t, 1.0)
		var v := 0.0
		match shape:
			"square":
				v = 1.0 if phase < 0.5 else -1.0
			"triangle":
				v = 4.0 * absf(phase - 0.5) - 1.0
			_:
				v = sin(TAU * phase)
		var env := 1.0 - k                       # 线性衰减
		return v * amp * env * env
	)


## 死亡音：一路下坠 + 一点噪声
func _sweep_noise(dur: float) -> AudioStreamWAV:
	return _make_wav(dur, func(t: float) -> float:
		var k := t / dur
		var f := lerpf(500.0, 70.0, k)
		var v := sin(TAU * fmod(f * t, 1.0))
		return (v * 0.7 + randf_range(-1.0, 1.0) * 0.3) * 0.55 * (1.0 - k)
	)


## 检查点：两个音的短提示音
func _chime() -> AudioStreamWAV:
	return _make_wav(0.28, func(t: float) -> float:
		var v := 0.0
		if t < 0.12:
			v = sin(TAU * fmod(880.0 * t, 1.0))
		else:
			v = sin(TAU * fmod(1320.0 * t, 1.0))
		return v * 0.4 * (1.0 - t / 0.28)
	)


## 通关：三连音小号角
func _fanfare() -> AudioStreamWAV:
	var notes := [523.25, 659.25, 783.99, 1046.50]   # C5 E5 G5 C6
	return _make_wav(0.9, func(t: float) -> float:
		var idx := clampi(int(t / 0.18), 0, notes.size() - 1)
		var v := sin(TAU * fmod(float(notes[idx]) * t, 1.0))
		return v * 0.35 * (1.0 - t / 0.9)
	)


## 把 "t -> 振幅" 的函数采样成 16 位 PCM 的单声道 wav
func _make_wav(dur: float, sample_fn: Callable) -> AudioStreamWAV:
	var rate := 22050
	var count := int(dur * float(rate))
	var data := PackedByteArray()
	data.resize(count * 2)
	for i in count:
		var v: float = clampf(float(sample_fn.call(float(i) / float(rate))), -1.0, 1.0)
		var s := int(v * 32000.0)
		data.encode_s16(i * 2, s)
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = rate
	wav.stereo = false
	wav.data = data
	return wav
