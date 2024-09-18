#!/bin/bash
mp3wrap "/tmp/${PWD##*/}.mp3" *.mp3 && mp3val -f "/tmp/${PWD##*/}_MP3WRAP.mp3" && rm "/tmp/${PWD##*/}_MP3WRAP.mp3.bak" && for f in *.mp3; do mv -- "$f" "${f%.mp3}.old"; done && mv "/tmp/${PWD##*/}_MP3WRAP.mp3" "${PWD##*/}.mp3"
