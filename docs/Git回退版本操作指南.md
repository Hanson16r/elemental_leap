# Git 回退版本操作指南

> 适用项目：元素之境（目录仍叫 `ice-tower-jump`，Godot 4.7.2）
> 远端：`https://github.com/Hanson16r/elemental_leap.git` · 分支：`main`
> 环境：Windows + PowerShell（文中命令可直接粘贴到 VS Code 终端或 PowerShell）
> 最后更新：2026-10-28

---

## 零、先搞清楚：你说的"回退"是哪一种？

Git 里"回到以前"有五种完全不同的意思，用错命令的代价从"没关系"到"代码全没"不等。
**动手前先在下表找到你要的那一行。**

| 我想要…… | 用哪一节 | 危险度 | 会不会丢东西 |
|---|---|---|---|
| 某个文件改坏了，恢复成仓库里的样子 | [§2 恢复单个文件](#2-恢复单个文件最常用) | ⭐ 低 | 丢该文件未提交的改动 |
| 先看看旧版本长什么样，不想动现在的代码 | [§3 旧版本另开一个目录](#3-旧版本另开一个目录不影响当前开发) | ⭐ 低 | 不丢 |
| 把整个项目退回到某一次提交 | [§4 整体回退](#4-整体回退到某一次提交) | ⭐⭐ 中 | 看用哪个参数 |
| 刚才 commit 的内容不想要了 | [§5 撤销刚提交但还没 push](#5-撤销刚提交还没-push) | ⭐⭐ 中 | 看用哪个参数 |
| 已经 push 到 GitHub 了，要撤掉 | [§6 撤销已 push 的提交](#6-撤销已经-push-的提交只能-revert) | ⭐⭐⭐ 高 | 只能往前加反向提交 |
| 手滑 reset 了，提交"消失"了 | [§7 reflog 救命](#7-救命-reflog把消失的提交找回来) | ✅ 能救 | 基本都救得回来 |

> **本仓库当前状态**：`main` 上只有一次提交 `7eaf237`（"冰塔跳跃 Demo：14 关 + 自检工具"），
> 也就是目前唯一的一个存档点。后文例子都用它。
> 确认一下你本地的版本号和远端是否一致：
>
> ```powershell
> git log --oneline -5
> git status
> git ls-remote origin          # 需要能连上 GitHub
> ```

---

## 一、动手前必做：30 秒备份

**任何回退之前，先给现在的状态留个后路。** 这是本指南最重要的一节。

```powershell
# 1. 看看现在有哪些没提交的改动
git status

# 2. 把它们打包存档（含新增的未跟踪文件）
git stash push -u -m "回退前备份 $(Get-Date -Format 'yyyyMMdd-HHmm')"

# 3. 确认存档成功
git stash list          # 能看到刚才那条 stash@{0}
```

`stash` 是"暂时收起来"，随时能拿回来：

```powershell
git stash pop           # 恢复最近一次存档，并从列表里删掉
git stash apply         # 恢复但保留记录（想多救几次就用这个）
git stash list
git stash show -p stash@{0}     # 看看这条存档里改了什么
git stash drop stash@{0}        # 确认不要了再删
```

**比 stash 更笨但绝对不会错的办法**：把整个 `ice-tower-jump` 文件夹复制一份到桌面，
改名 `ice-tower-jump-备份-20261028`。花钱买不到这种安心。

⚠️ `git stash` 只保护**已跟踪文件 + 加 `-u` 后的新文件**，而且 stash 存在本机 `.git` 里。
如果你连 `.git` 都想删，那就必须用文件夹复制。

---

## 二、恢复单个文件（最常用）

### 恢复成仓库里的最新版本

```powershell
# 先把当前改动备份下来
git diff -- 本人关卡审核说明.txt > 说明.txt.patch

# 恢复（新版 Git 推荐 restore，checkout 是旧写法但也能用）
git restore -- 本人关卡审核说明.txt
# 等价：git checkout -- 本人关卡审核说明.txt
```

### 恢复到某一次提交里的版本

```powershell
git restore --source=7eaf237 -- 本人关卡审核说明.txt

# 想看更早的版本就改提交号；也可以用相对写法：
git restore --source=HEAD~1 -- scripts/player.gd
```

### 只看内容、不覆盖文件（最安全）

```powershell
git show 7eaf237:本人关卡审核说明.txt
```

中文文件名如果显示成 `\346\234...` 这种八进制转义，加 `-c core.quotepath=false`：

```powershell
git -c core.quotepath=false show 7eaf237 --stat
```

### 中文内容输出乱码时

PowerShell 重定向偶尔会把 UTF-8 弄成 GBK。做法是直接用 `restore`（不经过管道），
或者显式指定编码：

```powershell
git show 7eaf237:本人关卡审核说明.txt | Out-File -FilePath 旧版说明.txt -Encoding utf8
```

---

## 三、旧版本另开一个目录（不影响当前开发）

**想拿旧版本跑一遍、对比着看、或者从中抄代码，用这个。** 当前工作区一动都不动。

### 方法 A：worktree（推荐，省磁盘，共享同一个仓库）

```powershell
# 在上一级目录生成 ice-tower-jump-旧版 文件夹，内容 = 提交 7eaf237 的样子
git worktree add ../ice-tower-jump-旧版 7eaf237

# 看完删掉（先删目录，再让 git 忘记它）
git worktree remove ../ice-tower-jump-旧版
git worktree list
```

> 注意：worktree 里的 `.godot` 是空的，第一次用 Godot 打开会重新导入一遍，属于正常现象。

### 方法 B：从 GitHub 下载压缩包（连 Git 都不用）

浏览器打开：

```
https://github.com/Hanson16r/elemental_leap/archive/7eaf237.zip
```

或者：仓库首页 → **Commits** → 点某个提交 → 右上角 **Download ZIP**。
单个文件则点进文件 → **Raw** 右键另存。

### 方法 C：重新 clone 一份

```powershell
git clone https://github.com/Hanson16r/elemental_leap.git ice-tower-jump-旧版
cd ice-tower-jump-旧版
git switch --detach 7eaf237
```

---

## 四、整体回退到某一次提交

### 4.1 先"只看不搬"（分离 HEAD，零风险）

```powershell
git switch --detach 7eaf237     # 工作区变成那一版，但不在任何分支上
# 逛完回来：
git switch main
```

这时 `git status` 会提示 "HEAD detached"，是正常现象，**不要在分离状态直接改代码然后 commit**，
那些提交会挂在一个没有分支指向的地方（虽然 §7 能捞回来，但没必要给自己找事）。

想在这个版本上继续干，就给它开个分支：

```powershell
git switch -c 回到旧版 7eaf237
```

### 4.2 `git reset` 的三种模式（核心区别）

`git reset` 只搬动**分支指针**，三种模式对"暂存区"和"工作区文件"的处理不同：

| 命令 | 提交历史 | 暂存区 | 工作区文件 | 什么时候用 |
|---|---|---|---|---|
| `git reset --soft <提交>` | 退回去 | 保留（改动还在暂存区） | **不动** | 想把几个提交合成一个，重新写 message |
| `git reset --mixed <提交>` | 退回去 | 清空 | **不动** | 想重新挑文件提交（默认模式） |
| `git reset --hard <提交>` | 退回去 | 清空 | **一起覆盖** ⚠️ | 确定现在的改动全都不要了 |

记住一句话：**`--soft` 只动历史，`--hard` 连你的文件一起动。**

### 4.3 真的要把整个项目退回那一版

```powershell
# 0. 备份（§1），这一步别省
git stash push -u -m "reset前备份"

# 1. 确认目标提交号没错（重要！）
git log --oneline -5

# 2. 执行
git reset --hard 7eaf237

# 3. 看看现在的状态
git status
git log --oneline -1
```

`--hard` 之后工作区里所有未提交的改动**永久消失**（除非之前 stash 过，或者文件被 Godot 之外的编辑器留了备份）。
stash 里的东西在 reset `--hard` 之后仍然存在，可以 `git stash pop` 拿回来。

### 4.4 reset 之后要和远端对齐

如果已经把坏的提交 push 上去了，**不要**用 `--force` 硬推（见 §6），改成往前加反向提交。
如果还没 push，reset 之后正常 `git push` 会提示落后/分叉，按 §6 处理。

---

## 五、撤销"刚提交但还没 push"

场景：`git commit` 完了，发现提交里有错文件 / message 写错 / 干脆整个提交不想要。

```powershell
# 假设要撤销最近一次提交

# 要保留改动、只是把提交拆开重新提交（最常用）
git reset --soft HEAD~1

# 改动保留在工作区、但取消暂存（重新挑文件）
git reset HEAD~1              # 等价于 --mixed

# 改动全部丢弃（危险，确认后再用）
git reset --hard HEAD~1
```

只改提交信息、内容不变：

```powershell
git commit --amend -m "新的提交信息"
```

⚠️ `--amend` 会生成新的提交号。**只要这个提交已经 push 过，就不要 amend**，
否则远端和本地历史分叉，要么 force push（危险），要么手工收拾（麻烦）。

---

## 六、撤销已经 push 的提交（只能 revert）

已经上了 GitHub 的提交，**默认假设别人可能已经拉过**。所以不能改写历史，只能
"再做一次相反的改动，形成新提交"。

```powershell
# 撤销某一个提交（生成一条反向提交，历史完整保留）
git revert 7eaf237

# 不自动提交，先看看它改了什么
git revert --no-commit 7eaf237
git diff --staged

# 撤销连续的几个提交（按从新到旧的顺序写）
git revert --no-commit HEAD~2..HEAD
git commit -m "回退最近两次提交"

# 中途乱了想放弃
git revert --abort
```

revert 的好处：**历史是只增不减的**，任何时候都能看出"谁在什么时候回退了什么"，
也随时能再 revert 回来。

### 关于 `git push --force`

```powershell
git push --force            # ❌ 不要对 main 用
git push --force-with-lease # 稍微安全一点，但仍然会覆盖远端历史
```

这两个命令会让远端**丢掉**被覆盖的提交。对你个人单人项目、且确认没有别的地方在用这个仓库时，
偶尔是可接受的；但这是唯一一种"GitHub 上的旧版本会消失"的操作。
本指南的建议是：**能 revert 就 revert，别 force。**

---

## 七、救命：reflog 把"消失"的提交找回来

`git reset --hard` 之后、`git commit --amend` 之后、误删分支之后 —— 只要没有
`git gc` 清理过，提交对象通常还在。`reflog` 是"HEAD 去过哪里的流水账"。

```powershell
# 1. 看最近 30 次 HEAD 移动记录
git reflog -30

# 输出长这样：
# 7eaf237 (HEAD -> main) HEAD@{0}: reset: moving to 7eaf237
# a1b2c3d HEAD@{1}: commit: 加了第 15 关
# ...

# 2. 找到你要回去的那一行，直接跳过去
git reset --hard HEAD@{1}

# 或者用提交号
git reset --hard a1b2c3d

# 3. 只想把某个丢失提交里的一个文件捞出来
git show a1b2c3d:scenes/level_15.tscn > level_15.tscn
git restore --source=a1b2c3d -- scenes/level_15.tscn
```

分支的 reflog 也可以单独看：

```powershell
git reflog show main
```

reflog 默认保留 90 天（可达对象），足够救命。**它是本机记录，不随 push 同步。**

---

## 八、本项目的具体操作实例

当前状态：`main` = `7eaf237`，工作区有 `本人关卡审核说明.txt` 未提交的 3 行改动。

### 例 1：我改了 `本人关卡审核说明.txt`，改坏了，想恢复

```powershell
git diff -- 本人关卡审核说明.txt              # 先看看改了什么，值不值得救
git restore -- 本人关卡审核说明.txt
```

### 例 2：我想在改关卡之前先立一个存档点

```powershell
git add -A
git commit -m "存档：改关卡前的稳定版"
git push
# 记下提交号，之后随时能回到这里
git log --oneline -1
```

### 例 3：我改完关卡发现第 3 关跳不过去了，想整体回到 `7eaf237`

```powershell
git stash push -u -m "关卡改崩了，先存着"
git reset --hard 7eaf237
# 想从崩掉的版本里抄点东西：
git stash show -p stash@{0} -- scenes/level_03.tscn
```

### 例 4：我已经把改崩的版本 push 上去了，想撤回

```powershell
git log --oneline -5                  # 找到要撤的那几个提交
git revert --no-commit HEAD~2..HEAD   # 撤销最近两次
git commit -m "回退：关卡 3 改崩，恢复 7eaf237 的数值"
git push
```

---

## 九、速查表

```powershell
# —— 看状态 ——
git status                            # 当前改动
git log --oneline --graph -10         # 历史
git diff                              # 未暂存的改动
git diff --staged                     # 已暂存的改动
git show 7eaf237:路径                 # 某提交里某文件的内容

# —— 备份 ——
git stash push -u -m "说明"           # 存起来
git stash list                        # 看存档
git stash pop                         # 拿回来并删除
git stash apply                       # 拿回来但保留

# —— 恢复单文件 ——
git restore -- 文件                   # 恢复成最新提交
git restore --source=提交号 -- 文件   # 恢复成指定提交
git restore --staged -- 文件          # 只从暂存区撤出，文件内容不动

# —— 整体回退 ——
git switch --detach 提交号            # 只看不搬
git worktree add ../旧版 提交号       # 另开目录
git reset --soft 提交号               # 退历史，改动保留在暂存区
git reset 提交号                      # 退历史，改动保留在工作区
git reset --hard 提交号               # 退历史 + 覆盖文件（危险）

# —— 撤销已推送 ——
git revert 提交号                     # 反向提交（安全）
git revert --abort                    # 放弃 revert

# —— 救命 ——
git reflog -30                        # 找丢失的提交
git reset --hard HEAD@{n}             # 跳回去
```

---

## 十、三条铁律

1. **回退前先 `git stash` 或复制文件夹。** 备份的 30 秒，省下的是几小时。
2. **`git reset --hard` 和 `git push --force` 之前，先把目标提交号念一遍。**
   `git log --oneline -5` 看一眼，确认没念错。
3. **上了 GitHub 的历史只往前加，不改写。** 要撤就 `git revert`，别 force push。

> 顺带一提：`git reset`、`git revert`、`git stash` 全都只影响**本地**。
> 在你执行 `git push` 之前，GitHub 上的东西一点没变；这本身就是一层保险。

---

## 十一、单人项目最省心的节奏

```powershell
# 每次动大改动之前
git switch -c 试做第15关        # 开分支，main 一直保持可玩
git add -A && git commit -m "存档：开始做第15关"
git push -u origin 试做第15关

# 做成了
git switch main
git merge 试做第15关
git push

# 做砸了
git switch main                 # 一秒回到稳定版，分支留着当尸体也无所谓
git branch -D 试做第15关        # 本地删掉（远端那份还在）
```

`main` 永远能跑 = 你永远有一个可以回去的地方。
