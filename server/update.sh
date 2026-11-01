#!/bin/bash
# Обновление игрового сервера Umwelt RP с GitHub Releases.
# Запускается таймером umwelt-update.timer раз в 2 минуты (см. setup.sh). Ничего не делает, если сборка та же.
set -euo pipefail
BASE="https://github.com/C0BecTb11/umwelt-rp/releases/download/latest"
DIR=/srv/umwelt
cd "$DIR"

curl -fsSL --retry 2 "$BASE/manifest.json?t=$(date +%s)" -o manifest.new || exit 0
NEW=$(python3 -c 'import json,sys; print(json.load(open("manifest.new"))["build"])')
SHA=$(python3 -c 'import json,sys; print(json.load(open("manifest.new"))["server_zip"]["sha256"])')
CUR=$(cat server/BUILD 2>/dev/null || echo none)
[ "$NEW" = "$CUR" ] && exit 0

echo "Новая сборка сервера: $CUR → $NEW"
curl -fsSL --retry 2 "$BASE/umwelt-server.zip?t=$(date +%s)" -o server.zip
if ! echo "$SHA  server.zip" | sha256sum -c --quiet -; then
  echo "Контрольная сумма не совпала (сборка ещё выкладывается?) — попробую в следующий раз"
  exit 0
fi
rm -rf server.new
python3 -m zipfile -e server.zip server.new/
echo "$NEW" > server.new/BUILD
chmod +x server.new/umwelt-server.x86_64
chown -R umwelt:umwelt server.new

systemctl stop umwelt-server || true
rm -rf server.old
[ -d server ] && mv server server.old
mv server.new server
systemctl start umwelt-server
echo "Сервер обновлён до сборки $NEW"
