# ROCK 5B+: drei Fixes für die BELABOX

Urheber: IRL4YOU. Lizenz: [CC BY-ND 4.0](LICENSE) mit [Zusatzerlaubnis](ZUSATZERLAUBNIS.md), Namensnennung erforderlich. / Author: IRL4YOU. License: [CC BY-ND 4.0](LICENSE) with [additional permission](ZUSATZERLAUBNIS.md), attribution required.

## Wofür ist das

Drei Fixes für die **BELABOX auf der Radxa ROCK 5B+** (BELABOX-Image 20250915). Jeder Fix lässt sich einzeln installieren.

| Fix | Wofür | Wo |
|---|---|---|
| **Einfrieren** | Die Box kann sporadisch ohne Logeintrag einfrieren. Der Bootloader bekommt eine neuere Speicher-Firmware. | `bootloader/` und `rockchip/` hier |
| **Lüfter und Kühler** | Lüftersteuerung für Aluminium- und Kupferkühler. | `fan/` hier, Quelle: [rock5bplus-fan](https://github.com/IRL4YOU/rock5bplus-fan) |
| **WLAN und Bluetooth** | Im Original erscheint das WLAN doppelt und Bluetooth findet keine Geräte. Mit dem Fix gibt es das WLAN einmal und Bluetooth einmal, beides wie es sein soll. (Neuer Treiber für den eingebauten RTL8852BE.) | [belabox-rtl8852be](https://github.com/IRL4YOU/belabox-rtl8852be) |

Nicht für die Orange Pi 5 Plus und nicht für andere Images.

## Wer braucht was

- **Einfrieren:** Die Box reagiert plötzlich nicht mehr (kein Ping, kein SSH, keine Weboberfläche), im Log steht nichts, nur Strom trennen hilft.
- **Lüfter und Kühler:** Die Box soll leise und kühl laufen, mit Alu- oder Kupferkühler.
- **WLAN und Bluetooth:** Das WLAN wird doppelt angezeigt (zwei WLAN-Schnittstellen für denselben Chip) und Bluetooth findet gar keine Geräte. Nach dem Fix: eine WLAN-Schnittstelle (`wlan0`) und funktionierendes Bluetooth. Gespeicherte WLAN-Verbindungen, die an die alten Schnittstellen (`wlan1`, `wlan2`) gebunden waren, müssen danach neu angelegt werden.

## Voraussetzungen

- Radxa ROCK 5B+ mit dem BELABOX-Image 20250915 (Kernel 5.10.160-belabox).
- Zugang per SSH über LAN als root, `python3` und `git` (oder das Repository als ZIP von GitHub laden und auf die Box kopieren).
- Für den Bootloader: der Original-Bootloader des BELABOX-Images. Das Skript prüft das selbst.

## Installation

Auf der Box per SSH über LAN anmelden, als root:

```
git clone https://github.com/IRL4YOU/belabox-rock5bplus-fix
cd belabox-rock5bplus-fix
bash install.sh
```

Das Skript führt Schritt für Schritt durch die Installation. Es fragt, ob der Bootloader installiert werden soll (ja/nein), ob die Lüftersteuerung installiert werden soll (ja/nein, dann `1` für Kupfer oder `2` für Aluminium) und ob WLAN und Bluetooth installiert werden sollen (ja/nein). Zum Schluss zeigt es die Auswahl und fragt einmal, ob es loslegen soll.

Es prüft vorher, ob es eine ROCK 5B+ mit dem BELABOX-Image ist und ob der Bootloader das BELABOX-Original ist. Sonst ändert es nichts. Beim Bootloader sichert es vorher die Karte nach `/var/tmp`, prüft das Ergebnis nach dem Schreiben und schreibt bei einem Fehler die Sicherung selbst zurück. Danach `reboot`.

Ohne die Fragen: `bash install.sh check` (nur prüfen), `bash install.sh bootloader`, `bash install.sh fan kupfer` oder `fan alu`, `bash install.sh wlan`, `bash install.sh all kupfer`.

WLAN und Bluetooth: Das Paket aus [belabox-rtl8852be](https://github.com/IRL4YOU/belabox-rtl8852be) laden, entpacken und den Ordner `belabox-rtw89` neben `install.sh` legen.

Startet die Box nach dem Bootloader nicht: Karte am Rechner mit der Sicherung aus `/var/tmp` zurückschreiben oder mit dem BELABOX-Image neu beschreiben. Eine neue Karte startet immer mit dem Original.

## Lizenz

Eigener Teil (Skript, Beschreibung, Zusammenstellung): [CC BY-ND 4.0](LICENSE) mit [Zusatzerlaubnis](ZUSATZERLAUBNIS.md), Namensnennung IRL4YOU. Lüfter (`fan/`): MIT. Rockchip-Firmware, U-Boot und alles andere gehört anderen und behält seine Lizenz, siehe [NOTICE.md](NOTICE.md).

---

# ROCK 5B+: three fixes for the BELABOX

Three fixes for the **BELABOX on the Radxa ROCK 5B+** (BELABOX image 20250915), each installable on its own: **freezes** (newer memory firmware in the bootloader), **fan and cooler** (fan control for aluminium and copper coolers, source: [rock5bplus-fan](https://github.com/IRL4YOU/rock5bplus-fan)) and **WLAN and Bluetooth** (the original shows the WLAN twice and Bluetooth finds no devices; with the fix there is one WLAN and one working Bluetooth, as it should be; newer driver for the onboard RTL8852BE: [belabox-rtl8852be](https://github.com/IRL4YOU/belabox-rtl8852be)). Not for the Orange Pi 5 Plus or other images.

**Who needs what:** *Freezes:* the box suddenly stops responding (no ping, SSH or web UI), nothing in the log, only a power cycle helps. *Fan and cooler:* quiet and cool operation with an aluminium or copper cooler. *WLAN and Bluetooth:* the board's WLAN is unreliable or Bluetooth finds no devices. **Requirements:** ROCK 5B+ with BELABOX image 20250915 (kernel 5.10.160-belabox), SSH access over LAN as root, `python3` and `git` (or download the repository as ZIP and copy it to the box), and for the bootloader the original BELABOX bootloader (the script checks this itself).

## Installing

Log in to the box over SSH (LAN) as root: `git clone https://github.com/IRL4YOU/belabox-rock5bplus-fix`, `cd belabox-rock5bplus-fix`, `bash install.sh`. The script guides you step by step: install the bootloader (yes/no), install the fan control (yes/no, then `1` for copper or `2` for aluminium), install WLAN and Bluetooth (yes/no), then it shows your choice and asks once before it starts. It first checks that this is a ROCK 5B+ with the BELABOX image and the original BELABOX bootloader, otherwise it changes nothing. For the bootloader it backs up the card to `/var/tmp`, checks the result after writing and restores the backup itself on an error. Then `reboot`. For WLAN and Bluetooth put the package from belabox-rtl8852be (folder `belabox-rtw89`) next to `install.sh`. If the box does not start, write the backup back on a computer or re-flash the BELABOX image; a new card always starts with the original.

## License

Own part (script, description, compilation): [CC BY-ND 4.0](LICENSE) with [additional permission](ZUSATZERLAUBNIS.md), attribution IRL4YOU. Fan control (`fan/`): MIT. Rockchip firmware, U-Boot and everything else belongs to others and keeps its licence, see [NOTICE.md](NOTICE.md).
