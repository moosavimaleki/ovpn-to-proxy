#!/usr/bin/env bash
set -euo pipefail

PROXY_PORT="${PROXY_PORT:-3128}"
VPN_INTERFACE="${dev:-${VPN_INTERFACE:-tun0}}"

container_interface() {
  if [[ -n "${CONTAINER_INTERFACE:-}" ]]; then
    printf '%s\n' "$CONTAINER_INTERFACE"
    return
  fi
  if [[ -n "${route_net_gateway:-}" ]]; then
    ip route get "$route_net_gateway" | awk '{for (i = 1; i <= NF; i++) if ($i == "dev") {print $(i + 1); exit}}'
    return
  fi
  ip route show default | awk 'NR == 1 {print $5}'
}

configure_dns() {
  local option key dns=() domains=()
  for ((index = 1; ; index += 1)); do
    key="foreign_option_${index}"
    option="${!key-}"
    [[ -z "$option" ]] && break
    case "$option" in
      'dhcp-option DNS '*) dns+=("${option#dhcp-option DNS }") ;;
      'dhcp-option DOMAIN '*) domains+=("${option#dhcp-option DOMAIN }") ;;
    esac
  done
  ((${#dns[@]})) || return
  {
    printf '# Generated from OpenVPN-pushed DNS\n'
    ((${#domains[@]})) && printf 'search %s\n' "${domains[*]}"
    for address in "${dns[@]}"; do printf 'nameserver %s\n' "$address"; done
  } >/etc/resolv.conf
}

configure_firewall() {
  local firewall="$1" container_net="$2"
  "$firewall" -F
  "$firewall" -t nat -F 2>/dev/null || true
  "$firewall" -P INPUT DROP
  "$firewall" -P OUTPUT DROP
  "$firewall" -P FORWARD DROP
  "$firewall" -A INPUT -i lo -j ACCEPT
  "$firewall" -A OUTPUT -o lo -j ACCEPT
  "$firewall" -A INPUT -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT
  "$firewall" -A OUTPUT -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT
  "$firewall" -A INPUT -i "$container_net" -p tcp --dport "$PROXY_PORT" -j ACCEPT
  "$firewall" -A INPUT -i "$VPN_INTERFACE" -j ACCEPT
  "$firewall" -A OUTPUT -o "$VPN_INTERFACE" -j ACCEPT
}

CONTAINER_NET="$(container_interface)"
[[ -n "$CONTAINER_NET" ]] || { echo '[-] Cannot determine the Docker-side interface.'; exit 1; }

configure_dns
configure_firewall iptables "$CONTAINER_NET"
command -v ip6tables >/dev/null && configure_firewall ip6tables "$CONTAINER_NET" || true

mkdir -p /var/run /var/log/squid /var/cache/squid
rm -f /var/run/squid.pid /run/squid.pid
squid -N -f /etc/squid/squid.conf &
SQUID_PID=$!
sleep 1
if ! kill -0 "$SQUID_PID" 2>/dev/null; then
  echo '[-] Squid failed to remain running after route-up.'
  exit 1
fi
printf '%s\n' "$SQUID_PID" >/run/squid.route-up.pid
echo "[+] VPN route is ready; Squid is listening on port $PROXY_PORT."
