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

        # Parse metrics for human-readable output
        HTTP_CODE=$(echo "$STATS" | grep -o 'HTTP_CODE=[^ ]*' | cut -d= -f2)
        TIME_TOTAL=$(echo "$STATS" | grep -o 'TIME_TOTAL=[^ ]*' | cut -d= -f2 | sed 's/s//')
        TIME_CONNECT=$(echo "$STATS" | grep -o 'TIME_CONNECT=[^ ]*' | cut -d= -f2 | sed 's/s//')
        SPEED_BYTES=$(echo "$STATS" | grep -o 'SPEED=[^ ]*' | cut -d= -f2 | sed 's/B\/s//')

        # Convert speed to KB/s or MB/s
        if (( $(echo "$SPEED_BYTES > 1048576" | bc -l) )); then
            SPEED_HUMAN=$(echo "scale=2; $SPEED_BYTES / 1048576" | bc -l) MB/s
        else
            SPEED_HUMAN=$(echo "scale=2; $SPEED_BYTES / 1024" | bc -l) KB/s
        fi

        # Format times to 3 decimal places
        TIME_TOTAL_FMT=$(printf "%.3f" "$TIME_TOTAL")
        TIME_CONNECT_FMT=$(printf "%.3f" "$TIME_CONNECT")

        echo "[$(date '+%Y-%m-%d %H:%M:%S')] [HealthCheck] OK | HTTP:$HTTP_CODE | Total:${TIME_TOTAL_FMT}s | Connect:${TIME_CONNECT_FMT}s | Speed:$SPEED_HUMAN"
    fi
    
    sleep $PERIOD
done
