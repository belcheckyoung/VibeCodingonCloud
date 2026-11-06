#!/bin/bash
# Removes the login-time startup tasks. Keeps OpenList, its data and all cloud files.
set -eu

AGENTS="$HOME/Library/LaunchAgents"
UID_NOW="$(id -u)"
BACKUP="$HOME/openlist-launchd-backup-$(date +%Y%m%d%H%M%S)"

for S in org.openlist.mountainduck org.openlist.server; do
  launchctl bootout "gui/$UID_NOW/$S" 2>/dev/null || true
  if [ -f "$AGENTS/$S.plist" ]; then
    mkdir -p "$BACKUP"
    mv "$AGENTS/$S.plist" "$BACKUP/"
    echo "已停用 $S，配置移到 $BACKUP"
  else
    echo "$S 没有配置，跳过"
  fi
done

cat <<N

OpenList、数据目录和云盘文件都没有删除。
如需继续清理：
- 卸载程序: brew uninstall openlist
- 取消授权: 在阿里云盘 App 的授权管理里解除 OpenList 授权
- 恢复 Mountain Duck 的「登录时启动」
删除数据目录前，请先确认没有待上传的文件。
N
