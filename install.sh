#!/bin/bash
# ROCK 5B+: Fixes für die BELABOX (Bootloader, Lüfter, WLAN/Bluetooth)
# Copyright (c) 2026 IRL4YOU. Lizenz: CC BY-ND 4.0 mit Zusatzerlaubnis (LICENSE, ZUSATZERLAUBNIS.md).
# Aufruf als root auf der Box:
#   bash install.sh check
#   bash install.sh bootloader [--yes]
#   bash install.sh fan kupfer|alu
#   bash install.sh wlan
#   bash install.sh all kupfer|alu [--yes]
set -euo pipefail

SELF=${BASH_SOURCE[0]:-$0}
HERE=$(cd -- "$(dirname -- "$SELF")" && pwd)

# Sektoren (je 512 Byte) der beiden Bootloader-Blöcke auf der Karte
IDB_SEEK=64;    IDB_COUNT=660
ITB_SEEK=16384; ITB_COUNT=2816
BACKUP_SECTORS=32768   # erste 16 MiB

# Prüfsummen des Original-Bootloaders (BELABOX-Image 20250915, DDR v1.16, BL31 v1.45)
ORIG_IDB=f13a6ce2d7157467b99739a4c448db4010078434b699e1282cd73878431825e5
ORIG_ITB=b43dc0f3e18ebe74c0b48b2679747c1772604e4d68a590d646c3a2b908599a0a
# Prüfsummen des neuen Bootloaders (DDR v1.19, BL31 v1.51)
NEW_IDB=5e7872d1c9acb90510fb7fa2d49f4cbc8eaf0d9f636d8fba0d3b645b009efbe3
NEW_ITB=28d2247ebf8e577b37c2dd490f37b8e6b6577a06e3f908e0f53aadb90bf21365
# Prüfsummen der unveränderten Rockchip-Dateien in rockchip/ (aus github.com/rockchip-linux/rkbin)
DDR_FILE=rockchip/rk3588_ddr_lp4_2112MHz_lp5_2400MHz_v1.19.bin
DDR_SHA=e109f3e283c86ad74b6574f5538b11750dea4cab7668175717aa2af7994c28ef
BL31_FILE=rockchip/rk3588_bl31_v1.51.elf
BL31_SHA=2847c82a44aff28f1923eea31567c9cf01a7c4bcec4d3b9be1cbf6fcc965f84b

die() { echo "Fehler: $*" >&2; exit 1; }

sha() {
  if command -v sha256sum >/dev/null 2>&1; then sha256sum | cut -d' ' -f1
  else shasum -a 256 | cut -d' ' -f1; fi
}

# Für Tests: BOOT_DEV (Datei oder Gerät) und PBFIX_TEST=1 (keine Board- und Root-Prüfung)
dd_write_flags() {
  if [[ $(uname -s) == Linux ]]; then echo "conv=notrunc,fsync"; else echo "conv=notrunc"; fi
}

read_range() { # Gerät, Start, Anzahl -> Daten
  dd if="$1" bs=512 skip="$2" count="$3" 2>/dev/null
}

write_range() { # Datei, Gerät, Start, Anzahl
  # shellcheck disable=SC2046
  dd if="$1" of="$2" bs=512 seek="$3" count="$4" $(dd_write_flags) 2>/dev/null
}

restore_from_backup() { # Sicherung, Gerät
  write_range_from_backup() { dd if="$1" bs=512 skip="$3" count="$4" 2>/dev/null | dd of="$2" bs=512 seek="$3" count="$4" $(dd_write_flags) 2>/dev/null; }
  write_range_from_backup "$1" "$2" "$IDB_SEEK" "$IDB_COUNT"
  write_range_from_backup "$1" "$2" "$ITB_SEEK" "$ITB_COUNT"
  sync
}

check_board() {
  [[ ${PBFIX_TEST:-} == 1 ]] && return 0
  [[ $(id -u) == 0 ]] || die "Bitte als root ausführen."
  local model
  model=$( { tr -d '\0' < /proc/device-tree/model; } 2>/dev/null || true)
  [[ $model == 'Radxa ROCK 5B Plus' ]] || die "Nur für die Radxa ROCK 5B+ (gefunden: ${model:-unbekannt})."
}

check_kernel() {
  [[ ${PBFIX_TEST:-} == 1 ]] && return 0
  local k; k=$(uname -r)
  [[ $k == 5.10.160-belabox ]] || die "Falscher Kernel ($k). Nur für das BELABOX-Image 20250915 mit Kernel 5.10.160-belabox."
}

boot_device() {
  if [[ -n ${BOOT_DEV:-} ]]; then echo "$BOOT_DEV"; return; fi
  local src parent
  src=$(findmnt -no SOURCE / 2>/dev/null) || die "Wurzel-Dateisystem nicht gefunden."
  parent=$(lsblk -ndo PKNAME "$src" 2>/dev/null) || die "Boot-Gerät nicht gefunden."
  [[ -n $parent ]] || die "Boot-Gerät nicht gefunden."
  echo "/dev/$parent"
}

bootloader_state() { # Gerät -> neu | original | unbekannt
  local idb itb
  idb=$(read_range "$1" "$IDB_SEEK" "$IDB_COUNT" | sha)
  itb=$(read_range "$1" "$ITB_SEEK" "$ITB_COUNT" | sha)
  if [[ $idb == "$NEW_IDB" && $itb == "$NEW_ITB" ]]; then echo neu
  elif [[ $idb == "$ORIG_IDB" && $itb == "$ORIG_ITB" ]]; then echo original
  else echo unbekannt; fi
}

confirm() { # Frage
  [[ ${ASSUME_YES:-0} == 1 ]] && return 0
  local a; read -r -p "$1 (ja/nein) " a
  [[ $a == ja ]]
}

do_bootloader() {
  check_board; check_kernel
  local dev state idb_file itb_file backup_dir backup build BAUEN
  dev=$(boot_device)
  command -v python3 >/dev/null 2>&1 || die "python3 fehlt."
  BAUEN="$HERE/bootloader/bauen.pyc"; [[ -f $BAUEN ]] || BAUEN="$HERE/bootloader/bauen.py"
  [[ -f $BAUEN && -f $HERE/$DDR_FILE && -f $HERE/$BL31_FILE ]] \
    || die "Dateien in bootloader/ oder rockchip/ fehlen. Bitte das Repository komplett herunterladen."
  [[ $(sha < "$HERE/$DDR_FILE") == "$DDR_SHA" && $(sha < "$HERE/$BL31_FILE") == "$BL31_SHA" ]] \
    || die "Prüfsumme der Rockchip-Dateien stimmt nicht. Bitte neu herunterladen."
  state=$(bootloader_state "$dev")
  case $state in
    neu) echo "Bootloader: schon aktualisiert (DDR v1.19, BL31 v1.51). Nichts zu tun."; return 0 ;;
    unbekannt) die "Der Bootloader auf $dev ist nicht der BELABOX-Original-Bootloader. Es wurde nichts geändert." ;;
  esac
  echo "Bootloader auf $dev: Original (DDR v1.16, BL31 v1.45)."
  # Neuen Bootloader erzeugen und prüfen
  build=$(mktemp -d "${TMPDIR:-/var/tmp}/pbfix-build-XXXXXX")
  python3 "$BAUEN" "$dev" "$HERE/$DDR_FILE" "$HERE/$BL31_FILE" "$build" \
    || { rm -rf "$build"; die "Der neue Bootloader konnte nicht gebaut werden. Es wurde nichts geändert."; }
  idb_file="$build/idbloader.bin"; itb_file="$build/u-boot.itb.bin"
  if [[ $(sha < "$idb_file") != "$NEW_IDB" || $(sha < "$itb_file") != "$NEW_ITB" ]]; then
    rm -rf "$build"; die "Das Ergebnis stimmt nicht mit der Erwartung überein. Es wurde nichts geändert."
  fi
  backup_dir=${BACKUP_DIR:-/var/tmp}
  mkdir -p "$backup_dir"
  backup="$backup_dir/boot-sicherung-$(date +%Y%m%d-%H%M%S).bin"
  confirm "Sicherung nach $backup anlegen und Bootloader jetzt schreiben?" || { rm -rf "$build"; echo "Abgebrochen."; return 1; }
  read_range "$dev" 0 "$BACKUP_SECTORS" > "$backup"
  [[ $(stat -c %s "$backup" 2>/dev/null || stat -f %z "$backup") -eq $((BACKUP_SECTORS * 512)) ]] \
    || { rm -rf "$build"; die "Sicherung unvollständig, nichts geschrieben."; }
  sha < "$backup" > "$backup.sha256"
  echo "Sicherung: $backup"
  write_range "$idb_file" "$dev" "$IDB_SEEK" "$IDB_COUNT" || true
  write_range "$itb_file" "$dev" "$ITB_SEEK" "$ITB_COUNT" || true
  sync
  rm -rf "$build"
  [[ $(uname -s) == Linux && -w /proc/sys/vm/drop_caches ]] && echo 3 > /proc/sys/vm/drop_caches || true
  if [[ $(bootloader_state "$dev") != neu ]]; then
    echo "Rücklesen stimmt nicht. Schreibe die Sicherung zurück." >&2
    restore_from_backup "$backup" "$dev"
    if [[ $(bootloader_state "$dev") == original ]]; then
      die "Der Original-Bootloader wurde wiederhergestellt. Nichts geändert."
    fi
    die "Wiederherstellung unvollständig! Karte am Rechner mit $backup zurückschreiben."
  fi
  echo "Bootloader geschrieben und geprüft (DDR v1.19, BL31 v1.51)."
  echo "Jetzt neu starten: reboot"
}

do_fan() {
  check_board; check_kernel
  local variant=${1:-}
  [[ $variant == kupfer || $variant == alu ]] || die "Aufruf: bash install.sh fan kupfer|alu"
  [[ -f $HERE/fan/install.sh ]] || die "fan/install.sh fehlt."
  ( cd "$HERE/fan" && bash install.sh "$variant" )
}

do_wlan() {
  check_board; check_kernel
  local dir=${WLAN_DIR:-$HERE/belabox-rtw89}
  if [[ -f $dir/rtw89ctl.py ]]; then
    echo "WLAN und Bluetooth: Paket gefunden in $dir."
    ( cd "$dir" && python3 rtw89ctl.py check )
    confirm "Treiber bauen und installieren (dauert einige Minuten)?" || { echo "Abgebrochen."; return 1; }
    ( cd "$dir" \
      && python3 rtw89ctl.py build --output /var/tmp/belabox-rtw89-build-1 \
      && python3 rtw89ctl.py install --build-dir /var/tmp/belabox-rtw89-build-1 --accept-experimental )
    echo "Jetzt neu starten: reboot"
  else
    echo "WLAN und Bluetooth: Paket nicht gefunden."
    echo "Bitte von https://github.com/IRL4YOU/belabox-rtl8852be laden, entpacken und den Ordner belabox-rtw89"
    echo "neben dieses Skript legen (oder WLAN_DIR=<Ordner> setzen), dann erneut: bash install.sh wlan"
  fi
}

do_check() {
  [[ ${PBFIX_TEST:-} == 1 || $(id -u) == 0 ]] || die "Bitte als root ausführen (sudo bash install.sh check)."
  local rc=0
  preflight || rc=1
  if command -v systemctl >/dev/null 2>&1; then
    echo "  Lüftersteuerung: $(systemctl is-active rock5bplus-fan.service 2>/dev/null || true)"
  fi
  local drv=""
  [[ -e /sys/class/net/wlan0/device/driver ]] && drv=$(basename "$(readlink -f /sys/class/net/wlan0/device/driver)")
  echo "  WLAN-Treiber: ${drv:-unbekannt}"
  return $rc
}

preflight() { # zeigt in einfachen Worten, ob alles passt
  local ok=0 model k dev state
  echo "Prüfung:"
  model=$( { tr -d '\0' < /proc/device-tree/model; } 2>/dev/null || true)
  if [[ ${PBFIX_TEST:-} == 1 || $model == 'Radxa ROCK 5B Plus' ]]; then echo "  [OK]    Gerät: Radxa ROCK 5B+"
  else echo "  [FEHLT] Gerät: ${model:-unbekannt} (nur ROCK 5B+)"; ok=1; fi
  k=$(uname -r)
  if [[ ${PBFIX_TEST:-} == 1 || $k == 5.10.160-belabox ]]; then echo "  [OK]    Kernel: $k"
  else echo "  [FEHLT] Kernel: $k (nötig: 5.10.160-belabox, BELABOX-Image 20250915)"; ok=1; fi
  if [[ $ok == 0 ]]; then
    dev=$(boot_device); state=$(bootloader_state "$dev")
    case $state in
      original) echo "  [OK]    Bootloader: BELABOX-Original, Fix kann eingespielt werden" ;;
      neu)      echo "  [OK]    Bootloader: Fix ist schon eingespielt" ;;
      *)        echo "  [FEHLT] Bootloader: nicht das BELABOX-Original, wird nicht verändert"; ok=1 ;;
    esac
  fi
  return $ok
}

ask_cooler() {
  local a
  echo "   Welcher Kühler ist verbaut?  1 = Kupfer, 2 = Aluminium" >&2
  read -r -p "   Zahl (1 oder 2): " a
  case $a in 1) echo kupfer ;; 2) echo alu ;; *) die "Bitte 1 oder 2 eingeben." ;; esac
}

ask_yes() { # Frage -> 0 bei ja, 1 bei nein
  local a
  while true; do
    read -r -p "$1 (ja/nein) " a
    case $a in ja|j|Ja|JA) return 0 ;; nein|n|Nein|NEIN) return 1 ;; esac
    echo "Bitte ja oder nein eintippen."
  done
}

guided() {
  local do_bl=0 do_fan_=0 do_wlan_=0 cooler=""
  echo "ROCK 5B+: Fixes für die BELABOX"
  echo
  check_board; check_kernel
  preflight || die "Die Prüfung ist nicht bestanden. Es wurde nichts geändert."
  echo
  ask_yes "1) Bootloader installieren (gegen das Einfrieren)?" && do_bl=1
  if ask_yes "2) Lüftersteuerung installieren?"; then
    do_fan_=1; cooler=$(ask_cooler)
  fi
  ask_yes "3) WLAN- und Bluetooth-Treiber installieren?" && do_wlan_=1
  if [[ $do_bl == 0 && $do_fan_ == 0 && $do_wlan_ == 0 ]]; then echo "Nichts ausgewählt. Ende."; return 0; fi
  echo
  echo "Ausgewählt:"
  [[ $do_bl == 1 ]] && echo "  - Bootloader"
  [[ $do_fan_ == 1 ]] && echo "  - Lüftersteuerung ($cooler)"
  [[ $do_wlan_ == 1 ]] && echo "  - WLAN und Bluetooth"
  ask_yes "Jetzt ausführen?" || { echo "Abgebrochen. Es wurde nichts geändert."; return 1; }
  ASSUME_YES=1
  [[ $do_bl == 1 ]] && do_bootloader
  [[ $do_fan_ == 1 ]] && do_fan "$cooler"
  [[ $do_wlan_ == 1 ]] && do_wlan
  echo
  echo "Fertig. Wenn Bootloader oder WLAN installiert wurden, bitte jetzt neu starten: reboot"
}

install_all() { # Kühler
  check_board; check_kernel
  preflight || die "Die Prüfung ist nicht bestanden. Es wurde nichts geändert."
  echo
  echo "Es werden nacheinander eingerichtet: Bootloader, Lüfter ($1), WLAN und Bluetooth."
  confirm "Alles jetzt installieren?" || { echo "Abgebrochen."; return 1; }
  ASSUME_YES=1
  do_bootloader
  do_fan "$1"
  do_wlan
  echo
  echo "Fertig. Bitte jetzt neu starten: reboot"
}

usage() {
  sed -n '2,9p' "$SELF" | sed 's/^# \{0,1\}//'
}

main() {
  local cmd=${1:-}; shift || true
  local args=() a
  for a in "$@"; do
    if [[ $a == --yes ]]; then ASSUME_YES=1; else args+=("$a"); fi
  done
  case $cmd in
    check) do_check ;;
    bootloader) do_bootloader ;;
    fan) do_fan "${args[0]:-}" ;;
    wlan) do_wlan ;;
    all)
      [[ ${args[0]:-} == kupfer || ${args[0]:-} == alu ]] || die "Aufruf: bash install.sh all kupfer|alu [--yes]"
      install_all "${args[0]}"
      ;;
    "") if [[ -t 0 ]]; then guided; else usage; fi ;;
    *) usage; exit 2 ;;
  esac
}

if [[ $SELF == "$0" ]]; then main "$@"; fi
