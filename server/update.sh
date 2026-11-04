#!/bin/bash
# Обновление игрового сервера Umwelt RP с GitHub Releases.
# Запускается таймером umwelt-update.timer раз в 2 минуты (см. setup.sh). Ничего не делает, если сборка та же.
# Ставится на сервер один раз (setup.sh или вручную владельцем) — изменения этого файла в репозитории сами на сервер
# не попадают. Версия с проверкой подписи — с 2026-11-04 (BF-039).
set -euo pipefail
BASE="https://github.com/C0BecTb11/Umwelt-RP/releases/download/latest"
DIR=/srv/umwelt
cd "$DIR"

command -v openssl > /dev/null || { echo "Нет openssl — подпись проверить нечем, не обновляюсь (apt install openssl)"; exit 0; }
curl -fsSL --retry 2 "$BASE/manifest.json?t=$(date +%s)" -o manifest.new || exit 0
# Подпись манифеста (BF-039): открытый ключ подписи — здесь, в скрипте, а не из релиза. Без верной подписи не обновляемся
curl -fsSL --retry 2 "$BASE/manifest.sig?t=$(date +%s)" -o manifest.sig || exit 0
base64 -d manifest.sig > manifest.sig.bin 2>/dev/null || { echo "Подпись манифеста испорчена — не обновляюсь"; exit 0; }
cat > update_key.pem <<'KEY'
-----BEGIN PUBLIC KEY-----
MIIBIjANBgkqhkiG9w0BAQEFAAOCAQ8AMIIBCgKCAQEA36oDz4y6ACmsP5CXzetl
uAaLXlh+kH3nI3kGFcnOE7Q7dnhkM8HhV3WHdoILoWQbmFVNi8l95XCHwzpTFgxe
91B5DJatopGX8kvwFOCsCZO/vCAQYgEa6PtSi9eYRuA8oW4zEhERIUKx6TuGTgbA
0/nhTFKFI0E9B1AjkBdauFG+l2nwzIOH1kl2Zg02otWH3yKTFNnvWMUisV28O5Sc
unfEL+eh/i/SGTpBhIUsQ2MVpcXM1qIaguk2Fwh1xDI1HyA0oCz8b3QN2Zc1YyDB
XFtyH5V0gd18RnX4B+Z5elK/7ab71avQPQ4Rear/jL+w76gUfCAohW2PEuAomjJv
zQIDAQAB
-----END PUBLIC KEY-----
KEY
if ! openssl dgst -sha256 -verify update_key.pem -signature manifest.sig.bin manifest.new > /dev/null 2>&1; then
  echo "Подпись манифеста не сошлась (сборка ещё выкладывается или подмена) — не обновляюсь"
  exit 0
fi
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
