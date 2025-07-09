#!/bin/bash
#Ein Skript um ein Ubuntu 24.04 inkl. snap und Flatpak zu updaten
#/usr/local/bin/update-all.sh
#sudo chmod a+x-w /usr/local/bin/update-all.sh

set -e

SCRIPT_PATH="$0"

# Fortschrittsbalken-Funktion, dynamisch an Terminalbreite angepasst
progress_bar() {
  local progress=$1
  local total=$2
  local cols
  cols=$(tput cols 2>/dev/null || echo 80)
  local bar_space=10        # Platz für [ ] und Prozentanzeige
  local width=$((cols - bar_space))
  ((width < 10)) && width=10   # Mindestbreite

  local filled=$((progress * width / total))
  local empty=$((width - filled))
  printf "\r["
  for ((i=0; i<filled; i++)); do printf "#"; done
  for ((i=0; i<empty; i++)); do printf " "; done
  printf "] %3d%%" $((progress * 100 / total))
}

handle_error() {
  echo -e "\nFehler erkannt. Versuche, kaputte Abhängigkeiten zu reparieren..." >&2
  sudo apt-get --fix-broken install -y 2>&1 | tee /dev/stderr
  if [ -z "$RETRY" ]; then
    echo "Starte das Skript nach Reparatur einmal neu..." >&2
    RETRY=1 exec "$SCRIPT_PATH"
  else
    echo "Reparatur wurde bereits versucht. Bitte prüfen Sie das System manuell." >&2
    exit 1
  fi
}

trap 'handle_error' ERR

steps=7
current=0

# Schritt 1: apt-get update
progress_bar $((++current)) $steps
sudo apt-get update -y > /dev/null

# Schritt 2: apt-get dist-upgrade
progress_bar $((++current)) $steps
sudo apt-get dist-upgrade -y > /dev/null

# Schritt 3: autoremove (wiederholt, falls nötig)
progress_bar $((++current)) $steps
while sudo apt-get autoremove --purge -y 2>/dev/null | grep -q "entfernt"; do :; done

# Schritt 4: apt-get clean
progress_bar $((++current)) $steps
sudo apt-get clean > /dev/null

# Schritt 5: Snap-Updates (Meldungen unterdrückt)
progress_bar $((++current)) $steps
sudo snap refresh > /dev/null 2>&1

# Schritt 6: Snap-Altlasten entfernen
progress_bar $((++current)) $steps
LANG= snap list --all | awk '/disabled/{print $1, $3}' | while read snapname revision; do sudo snap remove "$snapname" --revision="$revision" > /dev/null 2>&1; done

# Schritt 7: Flatpak-Updates & -Altlasten
progress_bar $((++current)) $steps
flatpak update -y > /dev/null 2>&1
flatpak uninstall --unused -y > /dev/null 2>&1

# Fortschrittsbalken auf 100 % setzen und Zeile abschließen
progress_bar $steps $steps
echo -e "\nFertig!"
