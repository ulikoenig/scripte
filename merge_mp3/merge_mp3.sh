#!/bin/bash

# Globstar aktivieren für echte Rekursion (**) und nullglob, falls Ordner leer sind
shopt -s globstar nullglob

REQUIRED_TOOLS=("ffmpeg" "eyeD3" "jq" "awk")

check_dependencies() {
    local missing_tools=()

    for tool in "${REQUIRED_TOOLS[@]}"; do
        if ! command -v "$tool" &> /dev/null; then
            missing_tools+=("$tool")
        fi
    done

    if [ ${#missing_tools[@]} -ne 0 ]; then
        echo "❌ Fehler: Folgende Tools sind nicht installiert:"
        for tool in "${missing_tools[@]}"; do
            echo "  - $tool"
        done
        echo ""
        echo "💡 Installationshinweise für Ubuntu 24.04:"
        echo "------------------------------------------------"
        echo "sudo apt update"
        
        for tool in "${missing_tools[@]}"; do
            case $tool in
                "eyeD3") echo "sudo apt install eyed3" ;;
                *)       echo "sudo apt install $tool" ;;
            esac
        done
        echo "------------------------------------------------"
        exit 1
    fi
}

extractCover () {
    local SOURCEDIR="$1"
    local SOURCEFILE="$2"
    local DESTINATION="$3"
    
    ffmpeg -loglevel error -y -i "$SOURCEFILE" -an -vcodec copy "$DESTINATION" >/dev/null 2>&1
    
    if [ ! -f "$DESTINATION" ] || [ ! -s "$DESTINATION" ]; then
        echo "   -> Kein embedded Cover, suche im Verzeichnis..."
        local COVERFILE=$(find "$SOURCEDIR" -maxdepth 1 -type f \( -iname "*.jpg" -o -iname "*.png" \) | head -1)
        if [ -n "$COVERFILE" ]; then
            cp "$COVERFILE" "$DESTINATION"
        fi
    fi
}

check_dependencies

TMPDIR=$(mktemp -d)
trap 'rm -rf "$TMPDIR"' EXIT

for D in **/; do
    D="${D%/}"
    FILES=("$D"/*.mp3)
    
    if [ ${#FILES[@]} -eq 0 ]; then
        continue
    fi

    echo "▶ Verarbeite Ordner: $D"
    
    FIRSTFILE="${FILES[0]}"
    FINALFILE="${D}.mp3"
    TMP_OUT="$TMPDIR/output.mp3"
    TMP_COVER="$TMPDIR/cover.jpg"
    CONCAT_LIST="$TMPDIR/concat.txt"
    FFMETA_FILE="$TMPDIR/metadata.txt"
    
    rm -f "$TMP_OUT" "$TMP_COVER" "$CONCAT_LIST" "$FFMETA_FILE"

    # FFMETADATA Header schreiben
    echo ";FFMETADATA1" > "$FFMETA_FILE"
    CURRENT_TIME=0

    # 1. Schleife durch alle Dateien: Concat-Liste und Kapitel-Metadaten aufbauen
    for f in "${FILES[@]}"; do
        safe_path=$(realpath "$f" | sed "s/'/'\\\\''/g")
        echo "file '$safe_path'" >> "$CONCAT_LIST"

        # Dauer und Tags der aktuellen Datei in einem Rutsch als JSON auslesen
        INFO=$(ffprobe -v quiet -print_format json -show_entries format=duration:format_tags "$f")
        
        # Werte extrahieren (robuster Umgang mit fehlenden Tags via `// {}`)
        DURATION=$(echo "$INFO" | jq -r '.format.duration // 0')
        TITLE=$(echo "$INFO" | jq -r '(.format.tags // {} | to_entries[]? | select(.key | ascii_downcase == "title") | .value) // ""' | head -n1)
        TRACK=$(echo "$INFO" | jq -r '(.format.tags // {} | to_entries[]? | select(.key | ascii_downcase == "track") | .value) // ""' | head -n1)

        # Tracknummer bereinigen (z.B. "02/14" -> "02" oder "2" -> "02")
        TRACK_CLEAN=$(echo "$TRACK" | cut -d'/' -f1)
        if [[ "$TRACK_CLEAN" =~ ^[0-9]+$ ]]; then
            TRACK_CLEAN=$(printf "%02d" "$TRACK_CLEAN")
        else
            TRACK_CLEAN=""
        fi

        # Kapitel-Titel zusammenbauen (Fallback auf Dateiname, falls Titel leer)
        if [[ -n "$TRACK_CLEAN" && -n "$TITLE" ]]; then
            CHAP_TITLE="$TRACK_CLEAN - $TITLE"
        elif [[ -n "$TITLE" ]]; then
            CHAP_TITLE="$TITLE"
        else
            CHAP_TITLE="$(basename "$f" .mp3)"
        fi

        # Dauer in Millisekunden umrechnen (LC_ALL=C verhindert Komma/Punkt-Fehler bei deutschen Systemen)
        DURATION_MS=$(LC_ALL=C awk "BEGIN {print int($DURATION * 1000)}")
        END_TIME=$((CURRENT_TIME + DURATION_MS))

        # Kapitel in Metadaten-Datei schreiben
        echo "[CHAPTER]" >> "$FFMETA_FILE"
        echo "TIMEBASE=1/1000" >> "$FFMETA_FILE"
        echo "START=$CURRENT_TIME" >> "$FFMETA_FILE"
        echo "END=$END_TIME" >> "$FFMETA_FILE"
        echo "title=$CHAP_TITLE" >> "$FFMETA_FILE"

        # Startzeit für den nächsten Track aktualisieren
        CURRENT_TIME=$END_TIME
    done

    # 2. Album/Artist-Metadaten der ersten Datei extrahieren
    FIRST_INFO=$(ffprobe -v quiet -print_format json -show_entries format_tags "$FIRSTFILE")
    ALBUM=$(echo "$FIRST_INFO" | jq -r '(.format.tags // {} | to_entries[]? | select(.key | ascii_downcase == "album") | .value) // ""' | head -n1)
    ARTIST=$(echo "$FIRST_INFO" | jq -r '(.format.tags // {} | to_entries[]? | select(.key | ascii_downcase == "artist") | .value) // ""' | head -n1)

    # 3. Zusammenfügen und Kapitel (Metadaten) integrieren (-id3v2_version 3 sorgt für hohe Kompatibilität der CHAP-Frames)
    ffmpeg -loglevel error -f concat -safe 0 -i "$CONCAT_LIST" -i "$FFMETA_FILE" -map_metadata 1 -map 0 -c copy -id3v2_version 3 "$TMP_OUT"
    
    # 4. Cover extrahieren
    extractCover "$D" "$FIRSTFILE" "$TMP_COVER"

    # 5. Generelles Tagging mit eyeD3 (eyeD3 erhält die Kapitel-Frames unangetastet)
    EYE_ARGS=(
        --title="${ALBUM:-$D}" 
        --album="$ALBUM" 
        --artist="$ARTIST"
        --remove-all-comments
        --quiet
    )

    if [ -f "$TMP_COVER" ]; then
        EYE_ARGS+=(--add-image="$TMP_COVER:FRONT_COVER")
    fi

    eyeD3 "${EYE_ARGS[@]}" "$TMP_OUT" > /dev/null
    
    # 6. Finale Datei verschieben
    mv "$TMP_OUT" "$FINALFILE"
    echo "   ✅ Erstellt mit Kapiteln: $FINALFILE"

done

echo "🎉 Alle Ordner erfolgreich verarbeitet!"