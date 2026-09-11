#!/usr/bin/env bash
set -euo pipefail

# No proxy must remain reachable while the tunnel is down.
squid -k shutdown 2>/dev/null || true
if [[ -r /run/squid.route-up.pid ]]; then
  kill "$(cat /run/squid.route-up.pid)" 2>/dev/null || true
fi
rm -f /var/run/squid.pid /run/squid.pid
rm -f /run/squid.route-up.pid

# Allow OpenVPN to reconnect to any remote profile. No user-facing proxy is
# running at this point, so this cannot leak proxied traffic.
for firewall in iptables ip6tables; do
  command -v "$firewall" >/dev/null || continue
  "$firewall" -F || true
  "$firewall" -t nat -F 2>/dev/null || true
  "$firewall" -P INPUT ACCEPT || true
  "$firewall" -P OUTPUT ACCEPT || true
  "$firewall" -P FORWARD ACCEPT || true
done

if [[ -r /run/resolv.conf.before-vpn ]]; then
  cp /run/resolv.conf.before-vpn /etc/resolv.conf
fi
