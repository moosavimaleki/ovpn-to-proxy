#!/bin/bash

# URL to check for connectivity
CHECK_URL="http://www.google.com"
PROXY_HOST="127.0.0.1"
PROXY_PORT="${PROXY_PORT:-3128}"

echo "[HealthCheck] Starting monitoring loop..."

# Initial grace period to allow VPN/Squid to stabilize
sleep 30

while true; do
    if ! curl -s --max-time 10 --proxy "http://${PROXY_HOST}:${PROXY_PORT}" "$CHECK_URL" -o /dev/null; then
        echo "[HealthCheck] Connection check failed! Restarting container..."
        # Kill PID 1 (Squid/Entrypoint) to force container restart
        kill 1
        exit 1
    fi
    sleep 30
done
