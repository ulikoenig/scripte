#!/bin/bash
#echo "EXT=.mp3" > ~/.mp3split
exctractCover () {
	SOURCEDIR=$1
	SOURCEFILE=$2
	DESTINATION=$3
	ffmpeg -i "$SOURCEFILE" "$DESTINATION"
#	eyeD3 --write-images=$DESTINATION $SOURCEFILE
	retVal=$?
	if [ $retVal -ne 0 ]; then
		echo Keine Cover in Quelldatei
		COVERFILE=$(find "$SOURCEDIR" -type f -exec file --mime-type {} \+ | awk -F: '{if ($2 ~/image\//) print $1}' | head -1)
		echo Gefunden: $COVERFILE
		cp "$COVERFILE" "$DESTINATION"
	fi
}


for D in *; do
    if [ -d "${D}" ]; then
	TMPFILE=$(mktemp)
	NEWFILE="$TMPFILE".mp3
	TMPCOVER="$TMPFILE".cover.jpg

	echo NEWFILE: $NEWFILE
	NEWFILEFINAL="${D}".mp3
	FIRSTFILE=`ls -1 "${D}"/*.mp3 | head -1`
	TAGS=$(ffprobe -print_format json -show_entries stream=codec_name:format -select_streams a:0 -v quiet "$FIRSTFILE")
        mp3wrap "$NEWFILE"  "${D}"/*.mp3  # your processing here
	mv "$TMPFILE"_MP3WRAP.mp3 "$NEWFILE"
        mp3val -f -nb "$NEWFILE"

	exctractCover "${D}" "$FIRSTFILE" "$TMPCOVER"

	TITLE=$(echo $TAGS |  jq  -r '.format.tags.title')
	ARTIST=$(echo $TAGS |  jq -r '.format.tags.artist')
	ALBUM=$(echo $TAGS |  jq -r '.format.tags.album')
	ALBUMARTIST=$(echo $TAGS |  jq -r '.format.tags.album_artist')
	GENRE=$(echo $TAGS |  jq -r '.format.tags.genre')
	BARCODE=$(echo $TAGS |  jq -r '.format.tags.BARCODE')
	TSRC=$(echo $TAGS |  jq -r '.format.tags.TSRC')
	TBPM=$(echo $TAGS |  jq -r '.format.tags.TBPM')
	DATE=$(echo $TAGS |  jq -r '.format.tags.date')
	YEAR=$(date --date="$DATE" "+%Y")
	PUBLISHER=$(echo $TAGS |  jq -r '.format.tags.publisher')
	TRACKDATE=$(echo $TAGS |  jq -r '.format.tags.date')
	CV=$(printf '%q' "${D}")
	COVERFILE="$TMPCOVER":FRONT_COVER
	echo $TAGS |  jq '.format.tags'
	echo Title $TITLE
	echo Coverfile $COVERFILE
        #ls  "${D}"/*.mp3  # your processing here
#	ls -alsh "$NEWFILE"
#	FILEALT=$(printf '%q' "$NEWFILE")
	echo YEAR: $YEAR

	#Jahr setzen
	if [ -z "$YEAR" ]; then
		YEARPARAM=""
	else
		YEARPARAM=--release-year="$YEAR"
	fi

	#Deutsch als Sprache erkennen
	if [[ $GENRE == *"Deutsch"* ]]; then
		LANGPARAM=--text-frame="TLAN:deu"
	else
		LANGPARAM=""
	fi

	if [ -f "$TMPCOVER" ]; then
		COVERPARAM=--add-image="$TMPCOVER":FRONT_COVER
		echo Cover Param: $COVERPARAM
	else
		COVERPARAM=""
		echo Kein Cover gefunden
	fi



	eyeD3 --title="$ALBUM" --album="$ALBUM" --artist="$ARTIST" --album-artist="$ALBUMARTIST" --genre="$GENRE"  --remove-all-comments --text-frame="TSRC:$TSRC" --text-frame="TBPM:$TBPM"  --text-frame="TPUB:$PUBLISHER"  --text-frame="TDAT:$DATE"  --remove-frame="TENC"  --remove-frame="TRCK" $LANGPARAM  $YEARPARAM "$NEWFILE"
	eyeD3 $COVERPARAM "$NEWFILE"
	eyeD3 --to-v1.1 "$NEWFILE"

	#Audiobook ID3v1 setzen
	if [[ $GENRE == *"Hörbuch"* ]]; then
		eyeD3 -1 --genre="Audiobook" "$NEWFILE"
	fi

#	id3v2 -t "$TITLE" -a "$ARTIST" -A "$ALBUM" -c "" -T "" --TSRC "$TSRC" --TPUB "$PUBLISHER" --TRDA "$TRACKDATE"  "$NEWFILE"
	mv "$NEWFILE" "$NEWFILEFINAL"
	rm "$TMPFILE"*
    fi
done

