#!/bin/bash
MYDIR="$PWD"
#for D in *; do
find * -type d | while IFS= read -r D; do
    if [ -d "${D}" ]; then
        echo "DIR ${D}"   # your processing here
        cd "${D}"
        mp3wrap "/tmp/${PWD##*/}.mp3" *.mp3
        mp3val -f "/tmp/${PWD##*/}_MP3WRAP.mp3"
        rm "/tmp/${PWD##*/}_MP3WRAP.mp3.bak"

        files=$(ls -AU *.mp3 | head -1)
        echo id3cp -2 "${files[0]}" "/tmp/${PWD##*/}_MP3WRAP.mp3"
        id3cp -2 "${files[0]}" "/tmp/${PWD##*/}_MP3WRAP.mp3"

        for f in *.mp3; do mv -- "$f" "${f%.mp3}.old"; done
        mv "/tmp/${PWD##*/}_MP3WRAP.mp3" "../${PWD##*/}.mp3"
        cd "$MYDIR"
    fi
done
