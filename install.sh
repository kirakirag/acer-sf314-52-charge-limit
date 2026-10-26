#!/usr/bin/env bash
# Install charge-limit and its systemd timer. Run as root from the repo directory.
set -euo pipefail
cd "$(dirname "$0")"
[ "$(id -u)" = 0 ] || { echo "run with sudo" >&2; exit 1; }

if ! modprobe acpi_call 2>/dev/null; then
  if command -v apt-get >/dev/null; then
    apt-get install -y acpi-call-dkms
  else
    echo "install the acpi_call kernel module for your distro, then re-run" >&2
    exit 1
  fi
fi

install -m 755 charge-limit /usr/local/sbin/charge-limit
install -m 644 systemd/charge-limit.service systemd/charge-limit.timer /etc/systemd/system/
[ -f /etc/charge-limit.conf ] || printf 'ENABLED=1\nSTOP=80\nSTART=75\n' > /etc/charge-limit.conf
echo acpi_call > /etc/modules-load.d/acpi_call.conf

systemctl daemon-reload
systemctl enable --now charge-limit.timer
/usr/local/sbin/charge-limit status
