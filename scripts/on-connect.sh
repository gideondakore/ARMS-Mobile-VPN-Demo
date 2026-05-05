#!/bin/bash
# OpenVPN client-connect hook.
#
# Called automatically by the OpenVPN server every time a client tunnel
# comes up. OpenVPN sets these environment variables for us:
#
#   common_name              — CN from the connecting client cert
#                              (e.g. "client1.domain.tld" or "gideon.dakore")
#   ifconfig_pool_remote_ip  — VPN-tunnel IP assigned to this client
#                              (e.g. "10.8.0.6")
#   trusted_ip               — client's real Internet IP
#   UV_USERNAME, UV_EMPLOYEE_ID — anything the client set via `setenv`
#
# Two responsibilities:
#   1. Append the (tunnel_ip, CN) pair to the session map so the Node
#      API can identify which cert each request came from.
#   2. Apply iptables rules so a client1 tunnel is constrained
#      at the network layer, not just at the application layer.
#
# Symlinked or copied to /etc/openvpn/scripts/on-connect.sh on the server.

set -e

CN="${common_name:-unknown}"
TUN_IP="${ifconfig_pool_remote_ip:-}"
REAL_IP="${trusted_ip:-unknown}"

SESSIONS=/var/run/openvpn/sessions
LOCK="${SESSIONS}.lock"

# Make sure the runtime directory exists (cleared on reboot).
mkdir -p /var/run/openvpn
touch "$SESSIONS"

# Atomically append to the session map. Strip any stale entry for the
# same tunnel IP first (defensive — tun pool reuse).
(
  flock -x 200
  if [ -n "$TUN_IP" ]; then
    sed -i "/^${TUN_IP} /d" "$SESSIONS"
    echo "${TUN_IP} ${CN}" >> "$SESSIONS"
  fi
) 200>"$LOCK"

logger -t openvpn "CONNECT cn=${CN} tunnel=${TUN_IP} real=${REAL_IP}"

# ── iptables: per-CN tunnel access policy ─────────────────────
#
# The base policy (set once at server boot) drops everything from
# tun0 by default. Below we punch holes per tunnel.
#
# Both tiers can hit the API on 10.8.0.1:3000 — Node's vpnIdentityGuard
# decides which paths within that port are allowed for the bootstrap CN.
# The iptables layer ensures no tunnel can reach OTHER ports on the
# gateway (SSH, internal tools, etc.) and that bootstrap tunnels can't
# scan the rest of the VPN subnet.

# Defensive cleanup — if a previous disconnect for this same TUN_IP
# never fired (network drop, OpenVPN crash, etc.), there can be stale
# rules tagged with the same tun=<ip> marker. Sweep them first so we
# don't accumulate duplicates over reconnects.
if [ -n "$TUN_IP" ]; then
  iptables-save | grep -F "tun=${TUN_IP}" | sed 's/^-A /-D /' | while read -r rule; do
    eval "iptables $rule" 2>/dev/null || true
  done
fi

if [ -n "$TUN_IP" ]; then
  if [ "$CN" = "client1.domain.tld" ]; then
    # Bootstrap: only TCP/3000 to the gateway. No subnet, no SSH, nothing else.
    iptables -I FORWARD 1 -s "$TUN_IP" -d 10.8.0.1 -p tcp --dport 3000 \
      -j ACCEPT -m comment --comment "vpn-cn=${CN} tun=${TUN_IP}"
    iptables -I INPUT 1 -i tun0 -s "$TUN_IP" -d 10.8.0.1 -p tcp --dport 3000 \
      -j ACCEPT -m comment --comment "vpn-cn=${CN} tun=${TUN_IP}"
  else
    # Personalized cert: full access to the VPN subnet.
    iptables -I FORWARD 1 -s "$TUN_IP" -d 10.8.0.0/24 \
      -j ACCEPT -m comment --comment "vpn-cn=${CN} tun=${TUN_IP}"
    iptables -I INPUT 1 -i tun0 -s "$TUN_IP" \
      -j ACCEPT -m comment --comment "vpn-cn=${CN} tun=${TUN_IP}"
  fi
fi

exit 0
