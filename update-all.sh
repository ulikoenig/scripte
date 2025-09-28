#!/bin/bash
###############################################################################
# update-all.sh – Systemweites Upgrade-Skript für Ubuntu/Debian (Snap/Flatpak)
#
# Beschreibung:
#   Aktualisiert alle Systempakete (APT), Snap- und Flatpak-Anwendungen, entfernt
#   nicht mehr benötigte Pakete, löst Abhängigkeitsprobleme, zeigt Fortschrittsbalken
#   und Status. Installations-/Uninstallfunktion, Akku-Prüfung (--no-battery/-nb) und
#   LAN-only-Check (--lan-only/-l).
#
#   Aufruf (am besten mit sudo):
#       sudo ./update-all.sh
#       sudo ./update-all.sh --install
#       sudo update-all.sh  # nach Installation
#       ./update-all.sh --help
#       sudo update-all.sh --no-battery
#       sudo update-all.sh --lan-only
#
#   Unterstützte Systeme:
#     - Ubuntu (ab 20.04)
#     - Debian (ab 10)
#
# Autor:   Uli König
# Quelle:  https://github.com/ulikoenig/scripte/blob/main/update-all.sh
# Version: siehe Variable VERSION
###############################################################################

VERSION="1.0.0"
AUTOR="Uli König"
SCRIPT_URL="https://github.com/ulikoenig/scripte/blob/main/update-all.sh"
INSTALL_PATH="/usr/local/bin/update-all.sh"
SCRIPT_NAME="update-all.sh"

print_help() {
  echo "###############################################################################"
  echo "# update-all.sh v$VERSION – Systemweites Upgrade für Ubuntu/Debian-Systeme    #"
  echo "###############################################################################"
  echo
  echo "Dieses Skript aktualisiert Systempakete (APT), Snap-/Flatpak-Apps, löst Abhängigkeitsprobleme"
  echo "und entfernt nicht mehr benötigte Pakete. Zeigt Fortschrittsbalken und Status."
  echo
  echo "Optionen:"
  echo "  -i, --install       Installiert als $INSTALL_PATH (Root-Rechte nötig, ggf. Nachfrage)"
  echo "  -u, --uninstall     Deinstalliert (Root-Rechte, Nachfrage vor Löschung)"
  echo "  -h, --help          Zeigt diese Hilfe"
  echo "  -nb, --no-battery   Beendet, falls im Akkubetrieb"
  echo "  -l,  --lan-only     Beendet, falls NICHT via LAN online (z.B. via WLAN/Mobilfunk)"
  echo
  echo "Nutzung:"
  echo "  sudo $SCRIPT_NAME"
  echo "  Empfohlen für: Ubuntu/Debian, mit Snap/Flatpak"
  echo
  echo "Autor: $AUTOR"
  echo "Quelle: $SCRIPT_URL"
  echo "###############################################################################"
  exit 0
}

check_battery() {
  local battery_state=""
  if command -v upower >/dev/null; then
    battery_state=$(upower -i $(upower -e | grep battery) 2>/dev/null | awk -F': ' '/state/{print $2}' | head -n1)
    if [[ "$battery_state" == "discharging" ]]; then
      echo "WARNUNG: Der Computer läuft aktuell im Akkubetrieb!"
      echo "Bitte schließen Sie das Gerät ans Netzteil und starten Sie das Update erneut."
      exit 1
    fi
  elif command -v acpi >/dev/null; then
    battery_state=$(acpi -b | awk '{print $3}' | head -n1)
    if [[ "$battery_state" == "Discharging" ]]; then
      echo "WARNUNG: Der Computer läuft aktuell im Akkubetrieb!"
      echo "Bitte schließen Sie das Gerät ans Netzteil und starten Sie das Update erneut."
      exit 1
    fi
  elif [ -r /sys/class/power_supply/BAT0/status ]; then
    battery_state=$(cat /sys/class/power_supply/BAT0/status)
    if [[ "$battery_state" == "Discharging" ]]; then
      echo "WARNUNG: Der Computer läuft aktuell im Akkubetrieb!"
      echo "Bitte schließen Sie das Gerät ans Netzteil und starten Sie das Update erneut."
      exit 1
    fi
  fi
}

check_lan() {
  # Prüfe aktives Interface für die Standardroute
  local lanok=0
  local lanname=""
  local defroute_iface
  defroute_iface=$(ip route | awk '/default/ {print $5}' | head -n1)
  if [[ "$defroute_iface" =~ ^(eth|enp|eno|ens)[0-9a-z]*$ ]]; then
    lanok=1;
    lanname="$defroute_iface"
  fi
  # WLAN: "wl", "wlan", "wifi"
  # Mobil: "wwan", "usb", "tty", "rmnet"
  if [[ $lanok -eq 0 ]]; then
    echo "WARNUNG: Die Internetverbindung erfolgt NICHT über LAN/Ethernet."
    echo "Aktuell verwendet: $defroute_iface"
    echo "Das Skript beendet sich aus Sicherheitsgründen. Bitte kabelgebundene Verbindung verwenden!"
    exit 1
  fi
}

install_script() {
  if [ "$(id -u)" -ne 0 ]; then
    echo "Bitte mit Root-Rechten (sudo) installieren!"
    exit 1
  fi
  if [ -f "$INSTALL_PATH" ]; then
    read -p "Eine Version existiert bereits unter $INSTALL_PATH. Überschreiben? [j/N] " answer
    if [[ ! "$answer" =~ ^[JjYy] ]]; then
      echo "Installation abgebrochen."
      exit 1
    fi
  fi
  cp "$0" "$INSTALL_PATH"
  chown root:root "$INSTALL_PATH"
  chmod 755 "$INSTALL_PATH"
  echo "Installiert als $INSTALL_PATH und ausführbar gesetzt!"
  exit 0
}

uninstall_script() {
  if [ "$(id -u)" -ne 0 ]; then
    echo "Bitte mit Root-Rechten (sudo) deinstallieren!"
    exit 1
  fi
  if [ ! -f "$INSTALL_PATH" ]; then
    echo "Kein Skript unter $INSTALL_PATH vorhanden."
    exit 1
  fi
  read -p "Wirklich $INSTALL_PATH löschen? [j/N] " answer
  if [[ "$answer" =~ ^[JjYy] ]]; then
    rm "$INSTALL_PATH"
    echo "Skript gelöscht!"
  else
    echo "Löschung abgebrochen."
  fi
  exit 0
}

case "$1" in
  -i|--install)
    install_script ;;
  -u|--uninstall)
    uninstall_script ;;
  -h|--help)
    print_help ;;
  -nb|--no-battery)
    check_battery
    echo "Gerät ist NICHT im Akkubetrieb, Updates werden ausgeführt ..."
    shift ;;
  -l|--lan-only)
    check_lan
    echo "LAN-Kabelverbindung erkannt, Updates werden ausgeführt ..."
    shift ;;
esac

steps=7
step_names=(
  "APT-Update"
  "APT-Upgrade"
  "Autoremove"
  "Clean"
  "Snap"
  "Snap-Reste"
  "Flatpak"
)

progress_bar() {
  local progress=$1
  local total=$2
  local step_name="$3"
  local package="$4"
  local cols
  cols=$(tput cols 2>/dev/null || echo 80)
  local bar_space=20
  local name_space=${#step_name}
  local package_space=${#package}
  local width=$((cols - bar_space - name_space - package_space - 4))
  ((width < 10)) && width=10

  local filled=$((progress * width / total))
  local empty=$((width - filled))
  printf "\r["
  for ((i=0; i<filled; i++)); do printf "#"; done
  for ((i=0; i<empty; i++)); do printf " "; done
  printf "] %3d%%  %s: %s" $((progress * 100 / total)) "$step_name" "$package"
}

handle_error() {
  progress_bar 0 $steps "Reparatur läuft..." ""
  echo -e "\nFehler erkannt. Versuche, kaputte Abhängigkeiten zu reparieren..." >&2
  sudo apt-get --fix-broken install -y 2>&1 | tee /dev/stderr
  if [ -z "$RETRY" ]; then
    echo "Starte das Skript nach Reparatur einmal neu..." >&2
    RETRY=1 exec "$SCRIPT_PATH"
  else
    progress_bar 0 $steps "Reparatur gescheitert!" ""
    echo "Reparatur wurde bereits versucht. Bitte prüfen Sie das System manuell." >&2
    exit 1
  fi
}

trap 'handle_error' ERR

current=0

progress_bar $current $steps "Start..." ""

progress_bar $((++current)) $steps "${step_names[0]}" ""
sudo apt-get update -y > /dev/null

apt_upgradable=$(apt-get -s dist-upgrade | awk '/^Inst /{print $2}' | tr '\n' ',' | sed 's/,$//')
progress_bar $((++current)) $steps "${step_names[1]}" "$apt_upgradable"
sudo apt-get dist-upgrade -y > /dev/null

autoremove_pkgs=$(apt-get -s autoremove | awk '/^Remv /{print $2}' | tr '\n' ',' | sed 's/,$//')
progress_bar $((++current)) $steps "${step_names[2]}" "$autoremove_pkgs"
while sudo apt-get autoremove --purge -y 2>/dev/null | grep -q "entfernt"; do :; done

progress_bar $((++current)) $steps "${step_names[3]}" ""
sudo apt-get clean > /dev/null

snap_updates=$(snap refresh --list 2>/dev/null | awk 'NR>1{print $1}' | tr '\n' ',' | sed 's/,$//')
progress_bar $((++current)) $steps "${step_names[4]}" "$snap_updates"
sudo snap refresh > /dev/null 2>&1

snap_disabled=$(snap list --all | awk '/disabled/{print $1 "("$3")"}' | tr '\n' ',' | sed 's/,$//')
progress_bar $((++current)) $steps "${step_names[5]}" "$snap_disabled"
LANG= snap list --all | awk '/disabled/{print $1, $3}' | while read snapname revision; do sudo snap remove "$snapname" --revision="$revision" > /dev/null 2>&1; done

flatpak_updates=$(flatpak update --appstream 2>/dev/null | grep "Ref" | awk '{print $2}' | tr '\n' ',' | sed 's/,$//')
progress_bar $((++current)) $steps "${step_names[6]}" "$flatpak_updates"
flatpak update -y > /dev/null 2>&1
flatpak_unused="Unbenutzte Runtimes/Extensions werden nun entfernt"
progress_bar $steps $steps "${step_names[6]}" "$flatpak_unused"
flatpak uninstall --unused -y > /dev/null 2>&1

progress_bar $steps $steps "Abgeschlossen" ""
echo -e "\nFertig!"
