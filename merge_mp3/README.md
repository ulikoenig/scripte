# 🎵 MP3 Album Merger (Lossless mit Kapitelmarken)

Dieses Bash-Skript fasst MP3-Dateien, die in Ordnern (z. B. Alben oder Hörbüchern) liegen, automatisch zu jeweils einer einzigen, großen MP3-Datei zusammen.

Das Besondere daran: Die Umwandlung erfolgt **verlustfrei** (ohne erneute Komprimierung) und die ursprünglichen Einzeltitel werden als **ID3v2-Kapitelmarken** (Chapters) in die neue Datei integriert. So verhält sich die fertige Datei in modernen Playern wie ein Hörbuch, in dem man bequem von Track zu Track springen kann.

## ✨ Features

- 🔄 **Rekursive Verarbeitung:** Das Skript durchsucht automatisch alle Unterordner. Du kannst es einfach im Hauptverzeichnis deiner Musik- oder Hörbuchsammlung starten.

- 🚀 **100% Verlustfrei (Zero Generation Loss):** Durch die Nutzung des nativen FFmpeg-Concat-Demuxers (`-c copy`) werden die MP3-Bitstreams auf Dateiebene aneinandergehängt. Es findet **keine** Neukomprimierung statt. Die Audioqualität bleibt exakt erhalten.

- 📑 **Automatische Kapitelmarkierungen:** Die Längen der Einzeltitel werden millisekundengenau berechnet und als `ID3v2-CHAP`-Frames in die finale Datei geschrieben. Der Kapitelname generiert sich automatisch aus Tracknummer und Titel-Tag der Quelldateien (z. B. `03 - Songname`).

- 🖼️ **Intelligentes Cover-Management:** Das Skript sucht zuerst nach einem bereits eingebetteten Cover in der ersten MP3-Datei. Findet es keines, sucht es im Ordner nach einer `.jpg`- oder `.png`-Datei und bettet diese als Front-Cover in die finale Datei ein.

- 🏷️ **ID3-Tagging:** Die finale Datei wird automatisch mit dem Album- und Artist-Tag versehen (ausgelesen aus der ersten Datei des jeweiligen Ordners).

## 🛠️ Voraussetzungen

Das Skript wurde für **Ubuntu 24.04** (inklusive **WSL2** unter Windows) geschrieben. Es benötigt folgende Standard-Tools:

- `ffmpeg` (für das Zusammenfügen, Extrahieren von Covern und Metadaten)

- `eyeD3` (für das saubere ID3-Tagging)

- `jq` (zum sicheren Parsen der JSON-Ausgaben von ffprobe)

- `awk` (für mathematische Berechnungen der Zeitstempel)

Das Skript prüft beim Start automatisch, ob alle Programme vorhanden sind. Fehlt etwas, bricht es ab und zeigt dir genau den passenden `apt`-Befehl zur Installation an.

Manuelle Installation der Abhängigkeiten:

Bash

```
`sudo apt update`

`sudo apt install ffmpeg eyed3 jq awk`
```

## 📦 Installation & Nutzung

1. Lade das Skript herunter (z. B. als `merge\_mp3.sh`) und lege es in das übergeordnete Verzeichnis deiner Alben.

2. Mache das Skript ausführbar:

Bash

```
`chmod +x merge\_mp3.sh`
```

3. Führe das Skript aus:

Bash

```
`./merge\_mp3.sh`
```

## 📂 Erwartete Ordnerstruktur

Das Skript erwartet, dass die MP3-Dateien in Ordnern liegen. Es ignoriert Dateien, die direkt im Hauptverzeichnis liegen.

**Vorher:**

Plaintext

```
`MeineMusik/`

`├── Skript/merge\_mp3.sh`

`├── Album A/`

`│   ├── 01-Intro.mp3`

`│   ├── 02-Song.mp3`

`│   └── cover.jpg`

`└── Hörbuch B/`

`    ├── CD1/`

`    │   ├── 01-Kapitel1.mp3`

`    │   └── 02-Kapitel2.mp3`

`    └── CD2/`

`        ├── 01-Kapitel3.mp3`

`        └── 02-Kapitel4.mp3`
```

**Nachher:**

Plaintext

```
`MeineMusik/`

`├── Skript/merge\_mp3.sh`

`├── Album A/`

`│   ├── 01-Intro.mp3`

`│   ├── 02-Song.mp3`

`│   └── cover.jpg`

`├── Album A.mp3         \<-- NEU (inkl. Cover & Kapitel)`

`└── Hörbuch B/`

`    ├── CD1/`

`    │   ├── 01-Kapitel1.mp3`

`    │   └── 02-Kapitel2.mp3`

`    ├── CD1.mp3         \<-- NEU`

`    ├── CD2/`

`    │   ├── 01-Kapitel3.mp3`

`    │   └── 02-Kapitel4.mp3`

`    └── CD2.mp3         \<-- NEU`
```

*(Hinweis: Die originalen Dateien werden zur Sicherheit **nicht** gelöscht. Du kannst sie nach erfolgreicher Prüfung der generierten Dateien manuell entfernen).*

## 🧠 Wie es unter der Haube funktioniert

1. **Sichere Arrays & Globstar:** Das Skript nutzt `shopt -s globstar`, um echte Bash-Rekursion zu ermöglichen. Alle Pfade werden in sicheren Arrays gespeichert, sodass Leerzeichen oder Sonderzeichen (wie `'` oder `&`) in Dateinamen keine Fehler verursachen.

2. **ffprobe & jq:** Die Metadaten (Länge, Titel, Track, Artist, Album) werden als sauberes JSON exportiert und case-insensitive (Groß-/Kleinschreibung ignorierend) geparst.

3. **FFMETADATA:** Während das Skript über die Dateien iteriert, schreibt es eine temporäre Metadatendatei im FFMETADATA1-Format. Hierbei werden die Längen der Tracks kumuliert addiert, um die Start- und Endzeiten der Kapitel in Millisekunden zu definieren.

4. **FFmpeg Concat:** Über eine generierte `concat.txt`-Liste fügt FFmpeg die Tracks zusammen und brennt gleichzeitig die Metadaten-Datei als `ID3v2` Tags in den Header.

## ⚠️ Bekannte Limitierungen

- **Gleiche Audio-Eigenschaften:** Da das Skript nicht neu codiert (`-c copy`), müssen alle MP3-Dateien innerhalb eines Ordners dieselbe Abtastrate (Sample Rate, z. B. 44100 Hz) und dieselbe Kanalanzahl (Stereo/Mono) haben. Bei gerippten Alben oder Hörbüchern ist dies in der Regel ohnehin der Fall. Sind die Formate gemischt, kann es bei der Wiedergabe der zusammengefassten Datei zu Pitch-Problemen (Micky-Maus-Stimme) kommen.

