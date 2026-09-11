#!/usr/bin/env bash
set -euo pipefail

OVPN_FILE="${OVPN_FILE:-/ovpn/client.ovpn}"
AUTH_FILE="${AUTH_FILE:-/ovpn/auth.txt}"

if [[ ! -r "$OVPN_FILE" ]]; then
  echo "[-] OpenVPN profile is not readable: $OVPN_FILE"
  exit 1
fi

# Preserve Docker's resolver until the VPN has supplied DNS settings.
cp -L /etc/resolv.conf /run/resolv.conf.before-vpn 2>/dev/null || true

OPENVPN_ARGS=(
  --config "$OVPN_FILE"
  --script-security 2
  --route-up /route-up.sh
  --route-pre-down /route-pre-down.sh
)

# This OpenVPN-native route follows the active remote (including a hostname or
# failover remote) and keeps its control channel on the original gateway.
if [[ "${PIN_REMOTE_ROUTE:-true}" != "false" ]]; then
  OPENVPN_ARGS+=( --route remote_host 255.255.255.255 net_gateway )
fi

if [[ -f "$AUTH_FILE" ]]; then
  OPENVPN_ARGS+=( --auth-user-pass "$AUTH_FILE" )
fi
if [[ -n "${OPENVPN_DATA_CIPHERS:-}" ]]; then
  OPENVPN_ARGS+=( --data-ciphers "$OPENVPN_DATA_CIPHERS" )
fi
if [[ -n "${OPENVPN_DATA_CIPHERS_FALLBACK:-}" ]]; then
  OPENVPN_ARGS+=( --data-ciphers-fallback "$OPENVPN_DATA_CIPHERS_FALLBACK" )
fi
if [[ -n "${OPENVPN_EXTRA:-}" ]]; then
  read -r -a OPENVPN_EXTRA_ARGS <<<"$OPENVPN_EXTRA"
  OPENVPN_ARGS+=( "${OPENVPN_EXTRA_ARGS[@]}" )
fi

echo "[+] Starting OpenVPN; Squid starts only after route-up succeeds."
exec openvpn "${OPENVPN_ARGS[@]}"
