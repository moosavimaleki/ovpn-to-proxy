#!/usr/bin/env bash
set -euo pipefail

OVPN_FILE="${OVPN_FILE:-/ovpn/client.ovpn}"
AUTH_FILE="${AUTH_FILE:-/ovpn/auth.txt}"
PROXY_PORT="${PROXY_PORT:-3128}"

# (اختیاری) اگر OpenVPN جدید باشه، cipher قدیمی ممکنه نیاز به fallback داشته باشه
# این‌ها بی‌خطرن و کمک می‌کنن:
OPENVPN_EXTRA="${OPENVPN_EXTRA:---data-ciphers AES-128-CBC --data-ciphers-fallback AES-128-CBC}"

echo "[+] Fixing DNS resolv.conf ..."
cat >/etc/resolv.conf <<'EOF'
nameserver 1.1.1.1
nameserver 8.8.8.8
options ndots:0
EOF


echo "[+] Resolving VPN host from config..."
VPN_HOST="$(awk '$1=="remote"{print $2; exit}' "$OVPN_FILE")"
VPN_PORT="$(awk '$1=="remote"{print $3; exit}' "$OVPN_FILE")"
VPN_PROTO="$(awk '$1=="proto"{print $2; exit}' "$OVPN_FILE")"
VPN_PORT="${VPN_PORT:-443}"
VPN_PROTO="${VPN_PROTO:-tcp}"

# resolve once (برای اینکه توی iptables بتونیم IP دقیق بدیم)
VPN_IP="$(getent hosts "$VPN_HOST" | awk '{print $1; exit}' || true)"
if [[ -z "${VPN_IP:-}" ]]; then
  echo "[-] Could not resolve $VPN_HOST"
  exit 1
fi
echo "[+] VPN endpoint: $VPN_HOST ($VPN_IP) $VPN_PROTO/$VPN_PORT"

OPENVPN_ARGS=( --config "$OVPN_FILE" --auth-nocache --verb 3 )
if [[ -f "$AUTH_FILE" ]]; then
  OPENVPN_ARGS+=( --auth-user-pass "$AUTH_FILE" )
else
  # اگر auth-user-pass داخل کانفیگ هست ولی فایل ندادی، داخل کانتینر prompt ممکن نیست
  echo "[-] auth.txt not found at $AUTH_FILE (needed for auth-user-pass)."
  exit 1
fi

echo "[+] Starting OpenVPN (foreground logs)..."
# openvpn رو daemon نکنیم تا لاگ واضح ببینی
openvpn "${OPENVPN_ARGS[@]}" $OPENVPN_EXTRA \
  --log /dev/stdout \
  --writepid /run/openvpn.pid \
  --daemon

echo "[+] Waiting for tun0..."
for i in $(seq 1 30); do
  if ip link show tun0 >/dev/null 2>&1; then break; fi
  sleep 1
done
if ! ip link show tun0 >/dev/null 2>&1; then
  echo "[-] tun0 did not come up. Check logs above."
  exit 1
fi
echo "[+] tun0 is up."

echo "[+] Applying iptables kill-switch (fixed)..."
iptables -F
iptables -t nat -F || true

iptables -P OUTPUT DROP
iptables -P INPUT DROP
iptables -P FORWARD DROP

# allow loopback
iptables -A INPUT  -i lo -j ACCEPT
iptables -A OUTPUT -o lo -j ACCEPT

# allow established/related (خیلی مهم!)
iptables -A INPUT  -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT
iptables -A OUTPUT -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT

# allow inbound proxy connections on eth0
iptables -A INPUT  -i eth0 -p tcp --dport "$PROXY_PORT" -j ACCEPT

# allow VPN control channel to server (out + in from VPN server IP/port)
if [[ "$VPN_PROTO" == "udp" ]]; then
  iptables -A OUTPUT -o eth0 -p udp -d "$VPN_IP" --dport "$VPN_PORT" -j ACCEPT
  iptables -A INPUT  -i eth0 -p udp -s "$VPN_IP" --sport "$VPN_PORT" -j ACCEPT
else
  iptables -A OUTPUT -o eth0 -p tcp -d "$VPN_IP" --dport "$VPN_PORT" -j ACCEPT
  iptables -A INPUT  -i eth0 -p tcp -s "$VPN_IP" --sport "$VPN_PORT" -j ACCEPT
fi

# allow all over tun0
iptables -A OUTPUT -o tun0 -j ACCEPT
iptables -A INPUT  -i tun0 -j ACCEPT

echo "[+] Starting Squid..."
mkdir -p /var/run /var/log/squid /var/cache/squid
rm -f /var/run/squid.pid /run/squid.pid /var/run/squid.pid

# Start healthcheck in background
/healthcheck.sh &

exec squid -N -f /etc/squid/squid.conf