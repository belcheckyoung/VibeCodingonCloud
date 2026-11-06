# 排错

先运行只读诊断：

```bash
./scripts/doctor.sh
```

然后按这个顺序排查：OpenList 是否运行 → `curl` 能否写入 → Mountain Duck 能否登录 → 同步队列是否卡住。

| 现象 | 原因 | 解决方法 |
| --- | --- | --- |
| 重启后一直返回 `401` | Mountain Duck 比 OpenList 早启动，错过了登录 | 先重新连接，不要急着改密码；再关闭它的“登录时启动” |
| 所有文件都传不上去 | 队列最前面的任务反复失败 | 看日志，先解决排在最前面的任务 |
| WebDAV 返回 `403` | 没有开启 `WebDAV manage` | 重新勾选保存，并确认已生效 |
| 连到 `443` 被拒绝 | 协议选成了 WebDAV (HTTPS) | 改成 HTTP，端口填 `5244` |
| `curl` 返回 `HTTP 000` | 测试文件不存在，或 OpenList 没运行 | 看状态码上方的具体报错 |
| 命令停在 `heredoc>` | 长段粘贴被截断 | 按 `Ctrl+C` 退出，改用仓库脚本 |
| `brew services` 报错 | Homebrew 的这个包没有服务定义 | 使用 `scripts/setup.sh` |
| `Bootstrap failed: 5` | 配置带隔离标记，或配置内容不完整 | 运行 `scripts/doctor.sh`，用 `xattr` 和 `plutil -p` 检查 |

## 日志位置

| 位置 | 用来确认什么 |
| --- | --- |
| `~/.openlist/log/log.log` | 请求状态码、启动时间、存储是否加载成功 |
| `~/.openlist/launchd-logs/` | `launchd` 启动后的输出和报错 |
| `~/Library/Logs/Mountain Duck/` | 登录失败、连接拒绝、队列重试 |

OpenList 日志里可能出现阿里云盘访问令牌，分享前请先脱敏，不要原样外传。
