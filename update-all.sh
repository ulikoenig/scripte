#!/bin/bash

set -e

SCRIPT_PATH="$0"

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

# Fortschrittsbalken-Funktion: Balken, Stichwort und Paketname in einer Zeile
progress_bar() {
  local progress=$1
  local total=$2
  local step_name="$3"
  local package="$4"
  local cols
  cols=$(tput cols 2>/dev/null || echo 80)
  local bar_space=20   # Platz für Balken + Prozent + Stichwort + Paketname
  local name_space=${#step_name}
  local package_space=${#package}
  local width=$((cols - bar_space - name_space - package_space - 4))  # 4 extra für Trennungen
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

# Schritt 1: apt-get update – Einzelpakete werden hier nicht angezeigt
progress_bar $((++current)) $steps "${step_names[0]}" ""
sudo apt-get update -y > /dev/null

# Schritt 2: apt-get dist-upgrade – zu aktualisierende Pakete anzeigen
apt_upgradable=$(apt-get -s dist-upgrade | awk '/^Inst /{print $2}' | tr '\n' ',' | sed 's/,$//')
progress_bar $((++current)) $steps "${step_names[1]}" "$apt_upgradable"
sudo apt-get dist-upgrade -y > /dev/null

# Schritt 3: autoremove (zu entfernende Pakete anzeigen)
autoremove_pkgs=$(apt-get -s autoremove | awk '/^Remv /{print $2}' | tr '\n' ',' | sed 's/,$//')
progress_bar $((++current)) $steps "${step_names[2]}" "$autoremove_pkgs"
while sudo apt-get autoremove --purge -y 2>/dev/null | grep -q "entfernt"; do :; done

# Schritt 4: apt-get clean (keine Paketnamen)
progress_bar $((++current)) $steps "${step_names[3]}" ""
sudo apt-get clean > /dev/null

# Schritt 5: Snap-Updates – zuvor abfragen
snap_updates=$(snap refresh --list 2>/dev/null | awk 'NR>1{print $1}' | tr '\n' ',' | sed 's/,$//')
progress_bar $((++current)) $steps "${step_names[4]}" "$snap_updates"
sudo snap refresh > /dev/null 2>&1

# Schritt 6: Snap-Altlasten entfernen – abgeschaltete Revisionen anzeigen
snap_disabled=$(snap list --all | awk '/disabled/{print $1 "("$3")"}' | tr '\n' ',' | sed 's/,$//')
progress_bar $((++current)) $steps "${step_names[5]}" "$snap_disabled"
LANG= snap list --all | awk '/disabled/{print $1, $3}' | while read snapname revision; do sudo snap remove "$snapname" --revision="$revision" > /dev/null 2>&1; done

# Schritt 7: Flatpak-Updates & -Altlasten
flatpak_updates=$(flatpak update --appstream 2>/dev/null | grep "Ref" | awk '{print $2}' | tr '\n' ',' | sed 's/,$//')
progress_bar $((++current)) $steps "${step_names[6]}" "$flatpak_updates"
flatpak update -y > /dev/null 2>&1
flatpak_unused="Unbenutzte Runtimes/Extensions werden nun entfernt"
progress_bar $steps $steps "${step_names[6]}" "$flatpak_unused"
flatpak uninstall --unused -y > /dev/null 2>&1

progress_bar $steps $steps "Abgeschlossen" ""
echo -e "\nFertig!"
