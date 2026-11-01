#!/bin/bash
# Установка игрового сервера Umwelt RP на сервер (Debian/Ubuntu). Запускать от root ОДИН раз:
#   bash <(curl -fsSL https://raw.githubusercontent.com/C0BecTb11/Umwelt-RP/main/server/setup.sh)
# Безопасно запускать повторно. Другие проекты на сервере не трогает:
# отдельный пользователь umwelt, папка /srv/umwelt, лимит памяти 450 МБ, порт 7777/UDP.
set -euo pipefail
RAW="https://raw.githubusercontent.com/C0BecTb11/Umwelt-RP/main/server"
PORT=7777

echo "== Umwelt RP: установка сервера"
[ "$(id -u)" = "0" ] || { echo "Нужно запускать от root"; exit 1; }

command -v curl >/dev/null && command -v python3 >/dev/null || { apt-get update -q </dev/null && apt-get install -y -q curl python3 </dev/null; }

id umwelt >/dev/null 2>&1 || useradd --system --home /srv/umwelt --shell /usr/sbin/nologin umwelt
mkdir -p /srv/umwelt/data
chown -R umwelt:umwelt /srv/umwelt

# swap 1 ГБ, если его нет: на 1 ГБ памяти без него сервер может упасть при пике
if [ "$(swapon --show | wc -l)" = "0" ] && [ ! -f /swapfile ]; then
  echo "== создаю swap 1 ГБ"
  fallocate -l 1G /swapfile && chmod 600 /swapfile && mkswap /swapfile >/dev/null && swapon /swapfile
  grep -q '^/swapfile' /etc/fstab || echo '/swapfile none swap sw 0 0' >> /etc/fstab
fi

if ss -lun | grep -q ":$PORT "; then
  echo "!! ВНИМАНИЕ: порт $PORT/UDP уже кем-то занят — напиши об этом в чат"
fi

curl -fsSL "$RAW/update.sh" -o /usr/local/bin/umwelt-update
chmod +x /usr/local/bin/umwelt-update

cat > /etc/systemd/system/umwelt-server.service <<UNIT
[Unit]
Description=Umwelt RP game server
After=network-online.target

[Service]
User=umwelt
WorkingDirectory=/srv/umwelt/server
Environment=XDG_DATA_HOME=/srv/umwelt/data
ExecStart=/srv/umwelt/server/umwelt-server.x86_64 --headless -- --server --port=$PORT --max=64
Restart=always
RestartSec=3
MemoryMax=450M
Nice=5

[Install]
WantedBy=multi-user.target
UNIT

cat > /etc/systemd/system/umwelt-update.service <<UNIT
[Unit]
Description=Umwelt RP: проверка обновлений сервера

[Service]
Type=oneshot
ExecStart=/usr/local/bin/umwelt-update
UNIT

cat > /etc/systemd/system/umwelt-update.timer <<UNIT
[Unit]
Description=Umwelt RP: обновления каждые 2 минуты

[Timer]
OnBootSec=30
OnUnitActiveSec=2min

[Install]
WantedBy=timers.target
UNIT

systemctl daemon-reload
systemctl enable umwelt-server >/dev/null 2>&1
systemctl enable --now umwelt-update.timer >/dev/null 2>&1

if command -v ufw >/dev/null && ufw status | grep -q "Status: active"; then
  ufw allow $PORT/udp >/dev/null && echo "== открыт порт $PORT/UDP в ufw"
fi

echo "== скачиваю последнюю сборку"
/usr/local/bin/umwelt-update || true
sleep 3
if systemctl is-active --quiet umwelt-server; then
  echo "== ГОТОВО: сервер Umwelt RP запущен на порту $PORT/UDP"
else
  echo "!! Сервер не запустился. Последние строки журнала:"
  journalctl -u umwelt-server -n 15 --no-pager || true
fi
echo "Журнал сервера: journalctl -u umwelt-server -f"
