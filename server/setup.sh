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

# Остановка с сохранением мира (BF-029): сигнал остановки Godot не ловит, поэтому служба просит сервер сохраниться
# файлом-запросом и ждёт до 10 с, пока он сохранит мир, уберёт файл и выйдет сам
cat > /usr/local/bin/umwelt-stop <<'STOP'
#!/bin/sh
F="/srv/umwelt/data/godot/app_userdata/Umwelt RP/stop.request"
touch "$F" 2>/dev/null || exit 0
i=0
while [ -e "$F" ] && [ "$i" -lt 40 ]; do sleep 0.25; i=$((i + 1)); done
exit 0
STOP
chmod +x /usr/local/bin/umwelt-stop

cat > /etc/systemd/system/umwelt-server.service <<UNIT
[Unit]
Description=Umwelt RP game server
After=network-online.target

[Service]
User=umwelt
WorkingDirectory=/srv/umwelt/server
Environment=XDG_DATA_HOME=/srv/umwelt/data
ExecStart=/srv/umwelt/server/umwelt-server.x86_64 --headless -- --server --port=$PORT --max=64
ExecStop=/usr/local/bin/umwelt-stop
TimeoutStopSec=20
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

# Фаервол (BF-043): с одного адреса на порт игры — не больше 1000 пакетов в секунду (честный игрок шлёт ~60),
# лишнее отбрасывается. Своя таблица nftables только для порта $PORT/UDP — правила ufw, sw-rpg и SSH не трогает.
# Если nft на сервере нет — пропускаем, ничего не ставим (пакет nftables может включить свою службу и сбросить чужие правила)
if command -v nft >/dev/null; then
  cat > /etc/umwelt-firewall.nft <<NFT
table inet umwelt_fw {}
delete table inet umwelt_fw
table inet umwelt_fw {
	set flood4 { type ipv4_addr; flags dynamic, timeout; timeout 1m; size 65535; }
	set flood6 { type ipv6_addr; flags dynamic, timeout; timeout 1m; size 65535; }
	chain input {
		type filter hook input priority -5; policy accept;
		udp dport $PORT update @flood4 { ip saddr limit rate over 1000/second burst 2000 packets } counter drop
		udp dport $PORT update @flood6 { ip6 saddr limit rate over 1000/second burst 2000 packets } counter drop
	}
}
NFT
  cat > /etc/systemd/system/umwelt-firewall.service <<UNIT
[Unit]
Description=Umwelt RP: ограничение пакетов на порт игры с одного адреса
After=network-pre.target
Before=umwelt-server.service

[Service]
Type=oneshot
RemainAfterExit=yes
ExecStart=$(command -v nft) -f /etc/umwelt-firewall.nft
ExecStop=$(command -v nft) delete table inet umwelt_fw

[Install]
WantedBy=multi-user.target
UNIT
else
  echo "!! nft не найден — фаервол для порта $PORT не поставлен (защита в самой игре работает)"
fi

systemctl daemon-reload
systemctl enable umwelt-server >/dev/null 2>&1
systemctl enable --now umwelt-update.timer >/dev/null 2>&1
if [ -f /etc/systemd/system/umwelt-firewall.service ]; then
  systemctl enable umwelt-firewall >/dev/null 2>&1
  systemctl restart umwelt-firewall && echo "== фаервол для порта $PORT/UDP включён (nft list table inet umwelt_fw)"
fi

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
