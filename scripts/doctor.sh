#!/bin/bash
# Read-only checks. Does not read config.json or the OpenList database,
# and does not print request logs that could contain tokens.
set -u

PORT="${OPENLIST_PORT:-5244}"
DATA_DIR="${OPENLIST_DATA:-$HOME/.openlist}"
AGENTS="$HOME/Library/LaunchAgents"
UID_NOW="$(id -u)"

echo "== 系统"
sw_vers -productVersion 2>/dev/null || uname -s
command -v openlist >/dev/null 2>&1 && echo "openlist: $(command -v openlist)" || echo "openlist: 未安装"
[ -d "/Applications/Mountain Duck.app" ] && echo "Mountain Duck: 已安装" || echo "Mountain Duck: 未在 /Applications 找到"

echo
echo "== OpenList 服务"
curl -s -o /dev/null -m 5 -w "ping: HTTP %{http_code}\n" "http://127.0.0.1:$PORT/ping"
LISTEN="$(lsof -nP -iTCP:"$PORT" -sTCP:LISTEN 2>/dev/null | tail -n 1)"
if [ -z "$LISTEN" ]; then
  echo "监听: 没有进程监听 $PORT"
else
  echo "$LISTEN"
  case "$LISTEN" in
    *"127.0.0.1:$PORT"*) echo "监听范围: 仅本机" ;;
    *) echo "警告: 不是只监听 127.0.0.1，局域网设备可能可以访问" ;;
  esac
fi

for S in org.openlist.server org.openlist.mountainduck; do
  echo
  echo "== $S"
  P="$AGENTS/$S.plist"
  if [ ! -f "$P" ]; then
    echo "配置: 不存在"
    continue
  fi
  plutil -lint "$P"
  if xattr "$P" 2>/dev/null | grep -q '^com.apple.quarantine$'; then
    echo "警告: 配置带有隔离标记，launchd 可能拒绝加载"
  fi
  launchctl print "gui/$UID_NOW/$S" 2>&1 | grep -E "state =|last exit code|Could not find" | head -n 3
done

echo
echo "== 最近的请求状态码（OpenList 日志）"
LOG="$DATA_DIR/log/log.log"
if [ -r "$LOG" ]; then
  grep GIN "$LOG" | tail -n 200 | awk -F'|' '{gsub(/ /,"",$2); split($5,a," "); print $2, a[1]}' | sort | uniq -c | sort -rn | head -n 10
else
  echo "读不到 $LOG"
fi
