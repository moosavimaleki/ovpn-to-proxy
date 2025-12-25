#!/bin/bash

# URL to check for connectivity
CHECK_URL="http://www.google.com"
PROXY_HOST="127.0.0.1"
PROXY_PORT="${PROXY_PORT:-3128}"

echo "[HealthCheck] Starting monitoring loop..."

# Kubernetes-style parameters
INITIAL_DELAY=6
PERIOD=3
FAILURE_THRESHOLD=2
CONSECUTIVE_FAILURES=0

# Initial grace period to allow VPN/Squid to stabilize
sleep $INITIAL_DELAY

while true; do
    # Capture metrics using curl's write-out feature
    STATS=$(curl -s -w "HTTP_CODE=%{http_code} TIME_TOTAL=%{time_total}s TIME_CONNECT=%{time_connect}s SPEED=%{speed_download}B/s" --max-time 5 --proxy "http://${PROXY_HOST}:${PROXY_PORT}" "$CHECK_URL" -o /dev/null)
    CURL_EXIT=$?

    if [ $CURL_EXIT -ne 0 ]; then
        CONSECUTIVE_FAILURES=$((CONSECUTIVE_FAILURES + 1))
        echo "[$(date '+%Y-%m-%d %H:%M:%S')] [HealthCheck] Check FAILED ($CONSECUTIVE_FAILURES/$FAILURE_THRESHOLD) - Exit Code: $CURL_EXIT"
        
        if [ $CONSECUTIVE_FAILURES -ge $FAILURE_THRESHOLD ]; then
            echo "[$(date '+%Y-%m-%d %H:%M:%S')] [HealthCheck] Failure threshold reached. Restarting container..."
            kill 1
            exit 1
        fi
    else
        # Reset failure counter on success
        if [ $CONSECUTIVE_FAILURES -gt 0 ]; then
            echo "[$(date '+%Y-%m-%d %H:%M:%S')] [HealthCheck] Connection recovered."
        fi
        CONSECUTIVE_FAILURES=0
        echo "[$(date '+%Y-%m-%d %H:%M:%S')] [HealthCheck] Connection OK: $STATS"
    fi
    
    sleep $PERIOD
done
