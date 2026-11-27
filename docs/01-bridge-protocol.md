# 01 · 桥的协议与命令集

## 为什么不用 HTTP

第一版验证 App 开过 HTTP 端口（18766 + Bearer token），能用，但有两个问题：
需要常驻 socket、需要管理 token、断网重连麻烦。
主程序最后选了**文件队列**：稳定、可审计、进程允许被杀。

## 队列模型

```
写命令                            读结果
  ↓                                ↑
/sdcard/StepBridge/in/<id>.cmd   /sdcard/StepBridge/out/<id>.res
```

- 桥每 **250 ms** 扫一次 `in/`，按文件名排序取命令；
- 命令体是一个 JSON，包含 `op` 和该 op 的参数；
- 执行完把结果写成同名 `.res`；
- 截图命令会额外落一张 jpg 到 `out/`。

## 命令集

| op | 作用 |
|---|---|
| `ping` | 探活 |
| `dump` | 读控件树（`compactOnly` 只回文本行，`limit` 限制条数） |
| `tap` | 点按，支持 `by=text` / `x,y` / `index` |
| `long` | 长按（`x,y,ms`） |
| `swipe` | 滑动（`x1,y1,x2,y2,ms`） |
| `back` / `home` / `recents` | 系统导航三键 |
| `notifications` | 下拉通知栏 |
| `close` | 连续 back 直到回到桌面（带 `expect` / `max` / `delay`） |
| `launch` | 按包名拉起 App（`pkg`,`ms`） |
| `text` | 往当前焦点输入框打字，无焦点返回 `no focused input` |
| `wait` | 纯等待（`ms`） |
| `shot` | 截图，落 jpg 到 `out/` |
| `ocr` | 区域 OCR（`region:[x1,y1,x2,y2]`） |
| `find` | 找目标（先树后 OCR），返回坐标但不点击 |
| `do` | 找 + 点 + 验证，`verify: changed\|gone\|text:…\|app:…` |
| `exists` | 判断目标是否存在 |
| `allow` | 点掉系统授权弹窗的「允许」 |
| `chain` | 批量执行（见下） |

## chain：把一串动作压成一次交互

```json
{"op":"chain","steps":[
  {"op":"launch","pkg":"com.autonavi.minimap","ms":5000},
  {"op":"tap","x":969,"y":1978,"delay":900},
  {"op":"swipe","x1":600,"y1":1800,"x2":600,"y2":700,"ms":450,"delay":1600},
  {"op":"shot"}
]}
```

- 每步支持 `delay`（**本步执行前**的 sleep，默认 250 ms）和 `stopOnError`；
- `chain` 在桥进程内一次跑完，中途不回到宿主，所以不会被打断。

**这是最关键的用法**：所有「连续动作」必须塞进一条 chain。
一次 chain 跑完，UI 状态才是连贯的。

## 结果长什么样

每一步都会带：

```json
{"op":"do","ok":true,"app":"com.autonavi.minimap",
 "located":{"mode":"text","center":[964,2261],"nodeText":"正常营业","matches":1},
 "verify":{"spec":"changed","ok":true,"beforeHash":"2563046b","afterHash":"882a3686"},
 "appAfter":"com.autonavi.minimap","ms":3038}
```

- `beforeHash/afterHash` 是整屏结构指纹，用来判断「点完之后页面到底变没变」；
- `ok:false` + `code:NOT_FOUND` 表示没找到目标、**没有点击任何东西**；
- `ok:false` + `code:NOT_VERIFIED` 表示点到了，但页面指纹没变——通常是没点中热区。

## 生命周期与故障判定

桥是一个带前台服务的 App，被杀之后 `in/` 里的命令就**一直躺着**。

判定死亡的方法很简单：

```sh
ls /sdcard/StepBridge/in/     # 还有 cmd
ls /sdcard/StepBridge/out/    # 没有对应 res
```

两者同时成立 = 桥已经死了。让用户点一下桌面图标重启即可，
**重启后积压的命令会按顺序补跑**，不需要重发。
