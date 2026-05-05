#!/bin/bash
# OpenVPN client-disconnect hook.
#
# Called when a client tunnel goes down. Reverses everything on-connect
# did: removes the session map entry and tears down any iptables rules
# that were tagged with this client's tunnel IP.

CN="${common_name:-unknown}"
TUN_IP="${ifconfig_pool_remote_ip:-}"
SESSIONS=/var/run/openvpn/sessions
LOCK="${SESSIONS}.lock"

# 1. Drop session map entry.
if [ -n "$TUN_IP" ] && [ -f "$SESSIONS" ]; then
  (
    flock -x 200
    sed -i "/^${TUN_IP} /d" "$SESSIONS"
  ) 200>"$LOCK"
fi

logger -t openvpn "DISCONNECT cn=${CN} tunnel=${TUN_IP}"

# 2. Strip iptables rules tagged with this tunnel IP. We added rules
# with a comment of the form "vpn-cn=<CN> tun=<TUN_IP>", so any rule
# whose comment contains "tun=${TUN_IP}" is ours.
#
# `iptables-save` emits each rule on its own line, with the comment
# string in double quotes. We MUST use `eval` so the shell re-parses
# the quoted argument as a single word — without it, the comment gets
# split on whitespace and `iptables -D` silently fails to match, which
# is what produces stale duplicate rules over reconnects.
if [ -n "$TUN_IP" ]; then
  iptables-save | grep -F "tun=${TUN_IP}" | sed 's/^-A /-D /' | while read -r rule; do
    eval "iptables $rule" 2>/dev/null || true
  done
fi

exit 0
