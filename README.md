# Mountain Duck + OpenList：把阿里云盘挂载成可写入的 Mac 文件夹

用 OpenList 在本机提供 WebDAV，再用 Mountain Duck 挂载到 Finder：

```text
Finder → Mountain Duck → OpenList（127.0.0.1:5244）→ 阿里云盘开放平台 API
```

适合存放素材、文档和已结束的项目归档。正在开发的代码、`.git`、`node_modules`、缓存和 AI 工具配置建议留在本地。

> 这是个人经验整理，不是阿里云盘、OpenList 或 Mountain Duck 的官方方案。第三方服务和会员规则可能变化，请自行评估风险，并为重要文件保留其他备份。

## 实测范围

| 项目 | 状态 |
| --- | --- |
| Apple 芯片 Mac 上手动配置 | 已实测 |
| 上传、覆盖、改名 | 已实测 |
| 重启后自动上传 | 已实测 1 次 |
| 几 GB 的大文件 | 未专门测试 |
| 阿里云盘以外的存储 | 未实测 |
| `scripts/setup.sh` 在真实 Mac 的干净环境运行 | **未实测**，只做过语法检查和模拟测试 |

欢迎通过 Issue 反馈你的系统版本和结果。

## 准备

- macOS、[Homebrew](https://brew.sh) 和 Mountain Duck
- 阿里云盘账号。第三方应用权益包和 SVIP 是两套权益，请先在 App 内确认当前规则

## 快速开始

### 1. 运行脚本

先阅读脚本内容，再运行：

```bash
git clone https://github.com/belcheckyoung/VibeCodingonCloud.git
cd VibeCodingonCloud
./scripts/setup.sh
```

脚本会安装 OpenList、限制为只监听本机，并添加两个登录任务：先启动 OpenList，就绪后再打开 Mountain Duck。它不会读取或保存密码和令牌，也不会覆盖已有的启动配置。

### 2. 设置密码

```bash
openlist admin random --data ~/.openlist
```

这会重置 `admin` 的密码。把密码存进密码管理器，不要写进命令行参数或截图。

### 3. 获取刷新令牌

打开 [api.oplist.org](https://api.oplist.org)，选择“阿里云盘 - 验证登录 (OAuth App)”，勾选“使用 OpenList 提供的参数”，授权后复制 `Refresh Token`。

**安全提示：** 这种方式配置最快，但令牌获取和续期会经过 OpenList 的在线服务。介意的话，可以[注册自己的开放平台应用](https://doc.oplist.org/guide/drivers/aliyundrive_open)。令牌泄露后，到阿里云盘 App 的授权管理里解除授权。

### 4. 添加存储

打开 `http://127.0.0.1:5244`，登录后添加存储：

| 字段 | 填写内容 |
| --- | --- |
| 驱动 | `AliyundriveOpen` |
| 挂载路径 | `/aliyun` |
| 根文件夹 ID | `root` |
| 刷新令牌 | 上一步的 `Refresh Token` |
| Use online api | 开启 |
| Api url address | `https://api.oplist.org/alicloud/renewapi` |
| 移除方式 | `Trash` |

保存后状态应为 `Working`。

### 5. 开启 WebDAV 写入

在用户设置里勾选 `WebDAV read` 和 `WebDAV manage`。保存前确认密码框为空，浏览器自动填充也没有挡住复选框。

### 6. 测试写入

分两次运行。先输入密码：

```bash
read -s "PW?输入 OpenList 密码: "; echo
```

再运行（把 `用户名` 换成你的）：

```bash
echo "webdav write test" > /tmp/openlist-test.txt
curl -u "用户名:$PW" -T /tmp/openlist-test.txt http://127.0.0.1:5244/dav/aliyun/openlist-test.txt -w "\nHTTP %{http_code}\n"
unset PW
```

返回 `HTTP 201` 或 `204` 就通过了。

### 7. 配置 Mountain Duck

关闭它的“登录时启动”，再新建书签：

| 字段 | 填写内容 |
| --- | --- |
| 协议 | `WebDAV (HTTP)` |
| 服务器 | `127.0.0.1` |
| 端口 | `5244` |
| 用户名、密码 | OpenList 的账号密码 |
| 路径 | `/dav/aliyun` |

### 8. 验证

重启 Mac，不要手动连接，往挂载目录放一个小文件。文件自动出现在阿里云盘，才算配置完成。确认完成前不要删除本地原文件。

## 脚本

| 脚本 | 作用 |
| --- | --- |
| `scripts/setup.sh` | 安装并配置启动任务，可重复运行 |
| `scripts/doctor.sh` | 只读诊断，不读取配置文件和数据库 |
| `scripts/uninstall.sh` | 停用启动任务，保留 OpenList、数据和云盘文件 |

## 更多

- [排错指南](docs/troubleshooting.md)
- [让 Claude/GPT 修改默认存储位置](docs/ai-migration-prompt.md)
- [OpenList](https://github.com/OpenListTeam/openlist)，它还支持其他存储，但能否写入要看具体驱动，请自行测试

## 许可证

[MIT](LICENSE)
