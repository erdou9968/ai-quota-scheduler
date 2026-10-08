# AI 五小时额度定时唤醒（Windows）

本项目整理自我的微信公众号 AI 工具实操文章，用于安排 Claude Code 与 Codex CLI 的五小时使用窗口。它不增加订阅额度，实际刷新时间请以官方用量页面为准。

**只想拿代码：** 点上面的 [`setup.ps1`](setup.ps1) 和 [`wake.ps1`](wake.ps1)，打开后点右上角的下载按钮（Download raw file）。两个文件放在同一个文件夹里。不需要注册 GitHub，也不需要会用 Git。

---

## 它解决什么问题

Claude 和 ChatGPT（Codex）的订阅额度按 5 小时窗口计算：从你发出第一条消息开始计时，5 小时后回满。窗口从哪一刻开始，取决于你每天第一句话几点发，所以经常出现“正忙的时候额度用完，要干等两三个小时”。

这套脚本用 Windows 任务计划程序，在你设定的时刻自动让 Claude Code 和 Codex 各回复一句 `OK`，把窗口起点固定下来。这样可以：

- 让额度在一段工作的**中间**刷新，一段集中工作能用上两个窗口；
- 让 Claude 和 Codex 的刷新时间错开，一边用完切另一边。

**适用边界：**

- 每周总额度不会因此变多。刷新得越勤，越容易提前碰到每周上限。
- 窗口规则由官方决定，可能调整。脚本只负责按时发一句话。
- 窗口额度已经用完时，唤醒会失败（日志里会写明），要等那个窗口自然刷新。

## 默认时刻（北京时间）

| | 唤醒 | 预计刷新 |
| --- | --- | --- |
| Claude | 05:00、10:05、15:10、20:15 | 约 10:00、15:05、20:10 |
| Codex | 07:30、12:35、17:40 | 约 12:30、17:35、22:40 |

“预计刷新”按 5 小时推算，不是每个时刻都实测过。每次唤醒比上个窗口到期晚 5 分钟，避免发进还没到期的旧窗口。请按自己的作息改（见下文）。

## 运行环境

- Windows 10 / 11，自带的 Windows PowerShell 即可。
- 电脑在设定时刻开机或睡眠（睡眠会被唤醒；关机则错过，开机后补跑一次）。
- 已安装 [Git for Windows](https://git-scm.com/downloads/win)（Claude Code 在 Windows 上需要它）。
- 已安装并登录 Claude Code 命令行（`claude`）和／或 Codex 命令行（`codex`）。只用其中一个也可以。

## 第一步：准备 CLI，并确认用的是订阅账号

**这一步最重要。** 用 API Key 登录的话，调用走按量计费，既花钱，也碰不到订阅的 5 小时窗口。

Claude Code：在 PowerShell 里运行 `claude`，按提示用 Claude Pro / Max 账号登录。进入后输入 `/status`，确认登录方式是订阅账号，而不是 API Key。如果设置过环境变量 `ANTHROPIC_API_KEY`，Claude Code 可能优先用它，建议删除。

Codex：运行 `codex`，选择用 ChatGPT 账号登录（Sign in with ChatGPT），不要选 API Key。

## 第二步：下载脚本

方法一（不用 GitHub 账号）：分别打开 [`setup.ps1`](setup.ps1)、[`wake.ps1`](wake.ps1)，点右上角下载按钮。

方法二：点仓库首页绿色的 **Code** 按钮 → **Download ZIP**，解压。

把两个 `.ps1` 放进一个**以后不会移动**的文件夹，例如 `D:\ai-quota-scheduler`。定时任务记的是这个路径，挪走后要重新注册。

## 第三步：修改时刻（可选）

默认时刻是按作者的作息算的。自己算的方法：

1. 找出每天的集中工作时段，例如 8:00–12:00。
2. 第一次唤醒 = 这段工作的**中点** − 5 小时。8–12 点的中点是 10:00，就在 05:00 唤醒；10:00 刷新后，10–12 点又是满额度。
3. 之后每隔 5 小时 5 分钟再唤醒一次：10:05、15:10、20:15……
4. 两家都用时，另一家错开约半段工作，例如让它在每段工作开始时刷新。

时刻在注册时作为参数传入，不用改脚本内容（见下一步）。时刻按**北京时间**填写，与电脑的系统时区无关。

## 第四步：注册定时任务

在脚本所在文件夹空白处按住 Shift 点右键 →「在终端中打开」（或「在此处打开 PowerShell 窗口」），运行：

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\setup.ps1
```

用自己的时刻：

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\setup.ps1 -ClaudeTimes '06:00','11:05','16:10' -CodexTimes '08:30','13:35'
```

会注册两个任务：`AI-Quota-Wake-Claude`、`AI-Quota-Wake-Codex`。重复运行只会更新这两个任务，不会重复添加。只用一家的话，注册完把另一个删掉即可（见“暂停、修改、删除”）。

## 第五步：手动测试

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\wake.ps1 -Target Both
Get-Content .\ai-quota-wake.log -Tail 10
```

`-Target` 可选 `Claude`、`Codex`、`Both`。注意：测试会真的各发一条短消息，占用一点额度，也会让当前时刻成为新窗口的起点（如果当前没有正在计时的窗口）。

## 检查日志和实际刷新时间

日志在脚本同目录的 `ai-quota-wake.log`，时间为北京时间：

- `Claude OK: OK` / `Codex OK: OK`：调用成功。
- `try failed` 后面跟着报错原文，例如未登录、额度已用完、找不到 Git Bash；`FAILED` 表示这次唤醒没成功。
- `claude CLI not found` / `codex CLI not found`：定时任务环境里找不到命令，检查是否安装、是否在 PATH 中。

日志里的 `OK` 只能证明命令发出去了。窗口实际几点刷新，以官方用量页面为准：Claude 在 claude.ai 的 Settings → Usage，Codex 在 https://chatgpt.com/codex/settings/usage。装好后的第一两天，对照一下页面显示的刷新时刻。

## 暂停、修改、删除

查看任务和下次运行时间：

```powershell
Get-ScheduledTask -TaskName 'AI-Quota-Wake-*' | Get-ScheduledTaskInfo | Select-Object TaskName, LastRunTime, LastTaskResult, NextRunTime
```

暂停 / 恢复：

```powershell
Disable-ScheduledTask -TaskName 'AI-Quota-Wake-Claude'
Enable-ScheduledTask  -TaskName 'AI-Quota-Wake-Claude'
```

修改时刻：带新参数重新运行一次 `setup.ps1`。

删除：

```powershell
Unregister-ScheduledTask -TaskName 'AI-Quota-Wake-Claude' -Confirm:$false
Unregister-ScheduledTask -TaskName 'AI-Quota-Wake-Codex'  -Confirm:$false
```

也可以在开始菜单搜索“任务计划程序”，在“任务计划程序库”里找到这两个任务，右键禁用或删除。

## 常见问题

**会不会每天多出很多聊天记录？** 不会。Claude 用 `--no-session-persistence`，Codex 用 `--ephemeral`，都不保存会话，只在本地写日志。如果你的 CLI 版本不支持这两个参数，唤醒会失败并在日志里写明，不会退回保存会话的方式。

**花多少额度？** 每次一句话，Claude 用 Haiku 模型，Codex 用低推理强度，占用很少。

**上课、开会、放假时也会唤醒吗？** 会，照常发一句。不用 AI 的时段空转一句话影响很小，不必按星期区分。

**电脑系统时区不是北京时间怎么办？** 不影响。任务的开始时间带了 `+08:00`，Windows 会按北京时间触发，夏令时也不影响。不在国内、想按本地时间设置的话，把 `setup.ps1` 里的 `+08:00` 改成自己的时差。

**唤醒时会弹窗吗？** PowerShell 以隐藏窗口运行，个别电脑上可能闪一下。

**会唤醒睡眠中的电脑吗？** 会（任务开启了“唤醒计算机运行此任务”）。不想要的话，在任务计划程序里打开任务属性 →“条件”，取消这一项。

**为什么不用 Agent 自带的定时任务？** 也可以，设置更简单，但每次都会新增一条对话记录。这套脚本的好处是不留会话、两家时间可以统一管理。

## 已验证与未验证

- 作者的电脑（Windows，系统时区设为美东时间）自 2026-10-02 起按这套方式每天运行，日志中两家都有大量成功记录；北京时间触发在非北京时区下工作正常。
- Codex 一个窗口的刷新时刻已与额度页面对上；其余“预计刷新”按 5 小时推算。
- 本仓库的公开版去掉了作者私人用的扩展功能，代码经过静态检查，尚未在其他读者的电脑上逐一测试。遇到问题请看日志里的报错。

## 文件

- `setup.ps1`：注册两个每日定时任务（参数 `-ClaudeTimes`、`-CodexTimes`，北京时间）。
- `wake.ps1`：被定时任务调用，向 Claude Code / Codex 发一句话并写日志（参数 `-Target Claude|Codex|Both`）。
