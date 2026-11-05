#!/bin/bash
set -euo pipefail
test "$(id -u)" = 0
source_dir=$(cd -- "$(dirname -- "$0")" && pwd)
# Aufruf: install.sh [alu|kupfer]  (ohne Angabe: alu, die vorsichtigere Kurve)
variant=${1:-alu}
case $variant in
  alu|kupfer) ;;
  *) echo "Aufruf: $0 [alu|kupfer]" >&2; exit 2 ;;
esac
script="$source_dir/$variant/rock5bplus-fan-$variant.sh"
[[ $(tr -d '\0' < /proc/device-tree/model) == 'Radxa ROCK 5B Plus' ]]
bash -n "$script"
echo "Kuehler-Variante: $variant"
umask 077
backup=$(mktemp -d /var/tmp/belabox-fan-backup-XXXXXX)
for file in /usr/local/bin/rock5bplus-fan.sh /etc/systemd/system/rock5bplus-fan.service; do
  if [[ -e $file ]]; then cp -a "$file" "$backup/"; fi
done
echo "Vorherige Dateien (falls vorhanden): $backup"
# Stoppen vor dem Austausch verhindert Aenderungen an einer laufenden Skriptdatei.
if systemctl is-active --quiet rock5bplus-fan.service; then
  systemctl stop rock5bplus-fan.service
fi
install -m 755 "$script" /usr/local/bin/rock5bplus-fan.sh
install -m 644 "$source_dir/rock5bplus-fan.service" /etc/systemd/system/rock5bplus-fan.service
systemd-analyze verify /etc/systemd/system/rock5bplus-fan.service
systemctl daemon-reload
systemctl enable rock5bplus-fan.service
systemctl restart rock5bplus-fan.service
sleep 7
systemctl is-active rock5bplus-fan.service
systemctl is-enabled rock5bplus-fan.service
systemctl show rock5bplus-fan.service -p NRestarts -p MainPID -p Result
cat /sys/class/hwmon/hwmon*/pwm1
echo 'LUEFTER_INSTALLATION_ERFOLGREICH'
