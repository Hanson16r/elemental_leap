extends Node
## 【单例 / 全局信号总线】
##
## 为什么要有这个：节点之间不互相认识的时候，怎么通知对方？
## 答案就是信号。但"掉落死亡区"不应该知道"关卡脚本"叫什么名字。
## 所以把常用信号集中放在这里，谁想听就 connect，谁想喊就 emit。
##
## 用法（喊）：Events.player_died.emit()
## 用法（听）：Events.player_died.connect(_on_player_died)

## 玩家死了（掉进死亡区 / 碰到火焰）。
## 目前 Player.die() 会 emit 它，同时 player 自己也有一个 died 信号给关卡脚本用
## （关卡需要等死亡动画播完再重生，所以走的是 player.died）。
## 这里保留它是给以后用的：比如加"HUD 抖一下""统计关卡难度"这类不关心是谁在听的逻辑。
signal player_died

## 玩家碰到检查点
signal checkpoint_reached(position: Vector2)

## 玩家到达终点
signal level_finished(level_number: int)

## 关卡开始/重开时广播，HUD 用来重置显示
signal level_started(level_number: int, level_title: String)

## 踩到按钮
signal button_pressed(button_id: String)

## 门被要求打开
signal door_opened(door_id: String)

# ===================================================================== 元素系统（Day 4~7）
## 玩家捡起一个元素（参数是 Element.Kind）
signal element_picked(kind: int)

## 玩家把元素用掉了（火盆、融冰、冻水都会发）
signal element_used(kind: int)

## 玩家手里的元素被清空（比如走进水幕）
signal element_cleared(kind: int)

## HUD 用：玩家手里的元素变了（包括变成"无"）
signal element_changed(kind: int)

# ===================================================================== 收集品（第 12 关起）
## 吃到金币（参数是这一关当前金币数）
signal coin_collected(count: int)

## 捡到钥匙
signal key_collected
