# 04 · 把设备截图送到远端看见

## 问题

桥能截图，但截出来的 jpg 躺在手机的 `/sdcard/StepBridge/out/` 里。
直接把它读回云端会变成乱码——二进制经文本通道会损坏。

## 可行通道：ntfy 中转

设备端有 `curl`，ntfy 有公开实例可用。

### 设备侧上传

```sh
f=$(ls -t /sdcard/StepBridge/out/shot_*.jpg | head -1)
curl -s -T "$f" -H "Filename: shot.jpg" https://ntfy.mzte.de/<topic>
```

返回 JSON，里面带 `attachment.url`。

### 云侧取回

```sh
u=$(curl -s "https://ntfy.mzte.de/<topic>/json?poll=1&since=all" \
    | grep -o 'https://ntfy.mzte.de/file/[^"]*' | tail -1)
curl -sL -o shot.jpg "$u"
```

拿到本地 jpg 后就可以交给视觉模型看。

## 两个坑

### 设备 exec 单次约 10 秒

大图上传经常超时。解决办法是**后台跑**，然后过十几秒再去取：

```sh
nohup curl -s -T "$f" -H "Filename: shot.jpg" https://ntfy.mzte.de/<topic> \
  >/dev/null 2>&1 & echo started
```

### poll 返回多行

`?poll=1&since=all` 会把这个 topic 的历史全吐出来，最后一行不一定是你要的那张。
用 `grep -o 'https://[^"]*file/[^"]*' | tail -1` 取，别用 `tail -1 | json.load`。

## 备用实例

- `https://ntfy.mzte.de`（主）
- `https://ntfy.envs.net`（备）

两个都通的时候优先主实例；奇怪的是同样 300 KB 的文件，有时 6 秒传完，有时 7 秒不够，
所以永远用后台 + 轮询，别卡在前台等。

## 拿到图之后怎么用

1. 整屏看：判断「现在到底在哪个 App / 哪个页面」；
2. 裁条带放大：定位按钮，叠加坐标网格（每 100 px 一条线，标注原图坐标）；
3. 交叉验证：网格读数 + 局部放大读数对上了，再点。

这套流程是目前唯一稳定的坐标来源。
