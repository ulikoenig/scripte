#!/bin/bash
###############################################################################
# update-all.sh – Systemweites Upgrade-Skript für Ubuntu/Debian (mit Snap/Flatpak)
#
# Beschreibung:
#   Dieses Skript aktualisiert alle klassischen Systempakete (APT), Snap-Pakete
#   und Flatpak-Anwendungen. Es entfernt nicht mehr benötigte Pakete,
#   löst automatisch Paket-Abhängigkeitsprobleme, zeigt einen Fortschrittsbalken
#   und Statusanzeige für den jeweiligen Schritt und das zu bearbeitende Paket.
#
#   Es unterstützt zudem:
#     - Installation als /usr/local/bin/update-all.sh (mit Option -i oder --install)
#     - Deinstallation (mit Option -u oder --uninstall)
#     - Hilfe/Parametersyntax und Beschreibung anzeigen (-h oder --help)
#
#   Aufruf (empfohlen immer mit sudo):
#       sudo ./update-all.sh              # für einmalige Ausführung
#       sudo ./update-all.sh -i           # installiert das Skript systemweit
#       sudo update-all.sh                # nach Installation (immer mit sudo)
#       ./update-all.sh -h                # zeigt Hilfe/Parameter und Beschreibung an
#
#   Unterstützte Systeme:
#     - Ubuntu (ab 20.04)
#     - Debian (ab 10)
#
# Autor:   Uli König
# Quelle:  https://github.com/ulikoenig/scripte/blob/main/update-all.sh
# Version: siehe Variable VERSION
###############################################################################

# ========================== METADATEN =========================
VERSION="1.0.0"
AUTOR="Uli König"
SCRIPT_URL="https://github.com/ulikoenig/scripte/blob/main/update-all.sh"
INSTALL_PATH="/usr/local/bin/update-all.sh"
SCRIPT_NAME="update-all.sh"

# ========================== HILFE =============================
print_help() {
  echo "###############################################################################"
  echo "# update-all.sh v$VERSION – Systemweites Upgrade für Ubuntu/Debian-Systeme    #"
  echo "###############################################################################"
  echo                                                  
  echo "Dieses Skript aktualisiert systemweite Pakete (APT), Snap- und Flatpak-Apps,"
  echo "löst Paket-Abhängigkeitsprobleme und entfernt automatisch nicht mehr benötigte"
  echo "Pakete. Es zeigt dabei einen Fortschrittsbalken mit Statusanzeige."
  echo                                                  
  echo "Optionen:"
  echo "  -i, --install     Installiert das Skript fest als $INSTALL_PATH"
  echo "                   (Root-Rechte erforderlich, ggf. vorhandene Version nach Nachfrage überschreiben)"
  echo "  -u, --uninstall   Entfernt das Skript wieder (Root-Rechte erforderlich, Nachfrage vor Löschung)"
  echo "  -h, --help        Zeigt diese Hilfe an"
  echo
  echo "Nutzung:"
  echo "  sudo $SCRIPT_NAME"
  echo "  Empfohlen für: Ubuntu/Debian, mit Snap/Flatpak-Support"
  echo                                                  
  echo "Autor: $AUTOR"
  echo "Quelle: $SCRIPT_URL"
  echo "###############################################################################"
  exit 0
}

# ========================== INSTALLER ==========================
install_script() {
  if [ "$(id -u)" -ne 0 ]; then
    echo "Bitte führen Sie die Installation mit Root-Rechten (sudo) aus!"
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

# ========================= UNINSTALLER =========================
uninstall_script() {
  if [ "$(id -u)" -ne 0 ]; then
    echo "Bitte führen Sie die Deinstallation mit Root-Rechten (sudo) aus!"
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

# ========================== PARAMETER - MAIN ===================
case "$1" in
  -i|--install)
    install_script ;;
  -u|--uninstall)
    uninstall_script ;;
  -h|--help)
    print_help ;;
esac

# ========================== UPDATE LOGIK =======================
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
