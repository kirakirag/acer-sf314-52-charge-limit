#!/usr/bin/env bash
# Remove charge-limit and clear the charge-inhibit bit so the battery charges normally.
set -euo pipefail
[ "$(id -u)" = 0 ] || { echo "run with sudo" >&2; exit 1; }

systemctl disable --now charge-limit.timer 2>/dev/null || true
if [ -x /usr/local/sbin/charge-limit ]; then
  printf 'ENABLED=0\n' > /etc/charge-limit.conf
  /usr/local/sbin/charge-limit status
fi
rm -f /usr/local/sbin/charge-limit /etc/systemd/system/charge-limit.service \
  /etc/systemd/system/charge-limit.timer /etc/charge-limit.conf /etc/modules-load.d/acpi_call.conf
systemctl daemon-reload
