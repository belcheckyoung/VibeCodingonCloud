#!/bin/bash
# Installs OpenList and configures login-time startup on macOS.
# Never creates, reads or prints passwords or tokens.
set -eu

PORT="${OPENLIST_PORT:-5244}"
DATA_DIR="${OPENLIST_DATA:-$HOME/.openlist}"
AGENTS="$HOME/Library/LaunchAgents"
SERVER_LABEL="org.openlist.server"
DUCK_LABEL="org.openlist.mountainduck"
UID_NOW="$(id -u)"
WITH_DUCK=1
DUCK_APP="${MOUNTAIN_DUCK_APP:-/Applications/Mountain Duck.app}"

usage() {
  cat <<'U'
用法: scripts/setup.sh [--no-mountain-duck]

  --no-mountain-duck  只配置 OpenList，不添加 Mountain Duck 启动任务

已有配置不会被覆盖。需要重新生成时，先运行 scripts/uninstall.sh。
U
}

die() { echo "错误: $*" >&2; exit 1; }
log() { echo "==> $*"; }

for arg in "$@"; do
  case "$arg" in
    --no-mountain-duck) WITH_DUCK=0 ;;
    -h|--help) usage; exit 0 ;;
    *) usage >&2; die "未知参数 $arg" ;;
  esac
done

[ "$(uname -s)" = "Darwin" ] || die "这个脚本只支持 macOS"
command -v brew >/dev/null 2>&1 || die "请先安装 Homebrew: https://brew.sh"
if [ "$WITH_DUCK" -eq 1 ] && [ ! -d "$DUCK_APP" ]; then
  die "/Applications 里没有 Mountain Duck。请先安装，或加上 --no-mountain-duck"
fi

xml_escape() {
  printf '%s' "$1" | sed -e 's/&/\&amp;/g' -e 's/</\&lt;/g' -e 's/>/\&gt;/g'
}

port_in_use() {
  lsof -nP -iTCP:"$PORT" -sTCP:LISTEN >/dev/null 2>&1
}

is_loaded() {
  launchctl print "gui/$UID_NOW/$1" >/dev/null 2>&1
}

load_agent() {
  label="$1"
  plist="$AGENTS/$label.plist"
  plutil -lint "$plist" >/dev/null || die "$plist 格式无效"
  # launchd can refuse a plist carrying the quarantine attribute.
  xattr -d com.apple.quarantine "$plist" 2>/dev/null || true
  if is_loaded "$label"; then
    log "$label 已加载，跳过"
  else
    launchctl bootstrap "gui/$UID_NOW" "$plist" || die "加载 $label 失败，请运行 scripts/doctor.sh"
    log "已加载 $label"
  fi
}

if command -v openlist >/dev/null 2>&1; then
  log "OpenList 已安装"
else
  log "安装 OpenList"
  brew install openlist
fi
OPENLIST_BIN="$(command -v openlist)"

mkdir -p "$DATA_DIR/launchd-logs" "$AGENTS"
CONFIG="$DATA_DIR/config.json"

if [ ! -f "$CONFIG" ]; then
  port_in_use && die "端口 $PORT 已被占用，无法初始化配置"
  log "首次启动 OpenList，生成配置"
  "$OPENLIST_BIN" server --data "$DATA_DIR" >/dev/null 2>&1 &
  INIT_PID=$!
  i=0
  while [ ! -f "$CONFIG" ] && [ "$i" -lt 30 ]; do
    sleep 1
    i=$((i + 1))
  done
  kill "$INIT_PID" 2>/dev/null || true
  wait "$INIT_PID" 2>/dev/null || true
  [ -f "$CONFIG" ] || die "没有生成 $CONFIG"
fi

if grep -Eq '"address"[[:space:]]*:[[:space:]]*"127\.0\.0\.1"' "$CONFIG"; then
  log "OpenList 已限制为只监听本机"
elif grep -Eq '"address"[[:space:]]*:[[:space:]]*"0\.0\.0\.0"' "$CONFIG"; then
  cp "$CONFIG" "$CONFIG.bak.$(date +%Y%m%d%H%M%S)"
  chmod 600 "$CONFIG".bak.*
  sed -i '' -E 's/("address"[[:space:]]*:[[:space:]]*)"0\.0\.0\.0"/\1"127.0.0.1"/' "$CONFIG"
  grep -Eq '"address"[[:space:]]*:[[:space:]]*"127\.0\.0\.1"' "$CONFIG" || die "修改监听地址失败"
  log "已改为只监听 127.0.0.1，原配置已备份"
else
  die "无法识别 $CONFIG 里的监听地址，请手动改成 127.0.0.1 后重试"
fi

SERVER_PLIST="$AGENTS/$SERVER_LABEL.plist"
if [ -f "$SERVER_PLIST" ]; then
  log "$SERVER_LABEL 配置已存在，不覆盖"
else
  if port_in_use; then
    die "端口 $PORT 已被占用。请先停止手动运行的 OpenList，再重新执行"
  fi
  cat > "$SERVER_PLIST" <<P
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>Label</key><string>$SERVER_LABEL</string>
  <key>ProgramArguments</key>
  <array>
    <string>$(xml_escape "$OPENLIST_BIN")</string>
    <string>server</string>
    <string>--data</string>
    <string>$(xml_escape "$DATA_DIR")</string>
  </array>
  <key>RunAtLoad</key><true/>
  <key>KeepAlive</key><true/>
  <key>StandardOutPath</key><string>$(xml_escape "$DATA_DIR/launchd-logs/out.log")</string>
  <key>StandardErrorPath</key><string>$(xml_escape "$DATA_DIR/launchd-logs/err.log")</string>
</dict>
</plist>
P
fi
load_agent "$SERVER_LABEL"

if [ "$WITH_DUCK" -eq 1 ]; then
  DUCK_PLIST="$AGENTS/$DUCK_LABEL.plist"
  if [ -f "$DUCK_PLIST" ]; then
    log "$DUCK_LABEL 配置已存在，不覆盖"
  else
    cat > "$DUCK_PLIST" <<P
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>Label</key><string>$DUCK_LABEL</string>
  <key>ProgramArguments</key>
  <array>
    <string>/bin/sh</string>
    <string>-c</string>
    <string>until /usr/bin/curl -fs -o /dev/null http://127.0.0.1:$PORT/ping; do sleep 1; done; sleep 3; /usr/bin/open -a "Mountain Duck"</string>
  </array>
  <key>RunAtLoad</key><true/>
</dict>
</plist>
P
  fi
  load_agent "$DUCK_LABEL"
fi

cat <<N

自动配置完成。还需要手动完成：
1. 设置管理员密码: openlist admin random --data "$DATA_DIR"
   注意: 这会重置 admin 的密码，已有账号请先确认。
2. 按 README 获取令牌，并在 http://127.0.0.1:$PORT 添加存储。
3. 给账号开启 WebDAV read 和 WebDAV manage。
4. 在 Mountain Duck 里关闭「登录时启动」，并新建 WebDAV (HTTP) 书签。
5. 重启 Mac，放入一个小文件，确认它自动上传。
N
