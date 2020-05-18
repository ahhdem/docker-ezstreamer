#!/bin/bash

FALLBACK_STREAM=${FALLBACK_STREAM:-brb}
PLAYLISTS=($ICECAST_RADIO_PLAYLISTS)
MEDIA_DIR=${MEDIA_DIR:-/var/lib/mopidy/media}
PLAYLIST_DIR=${PLAYLIST_DIR:-/var/lib/mopidy/playlists}

LOG_ROOT=${LOG_ROOT:-/config/}
BAD_SONG_LOG=${BAD_SONG_LOG:-${LOG_ROOT}/bad_songs.log}
# Get the command of the streamer process calling us
STREAMER_CMD=($(ps -o cmd= $(ps -o ppid= $PPID)))

# If we are called by the brb streamer 
# TODO: pull playlists for multiple streams from ICECAST_$STREAM_PLAYLISTS
echo $STREAMER_CMD |grep $FALLBACK_STREAM && {
  # Pick a random commercial
  ls ${MEDIA_DIR}/commercials | shuf -n 1
  exit 0;
}

function selecta() {
  shuf ${PLAYLIST_DIR}/${PLAYLISTS[$RANDOM % ${#PLAYLISTS[@]}]}.m3u -n 1
}

next=${LOG_ROOT}/next
[ -e ${next} ] && {
  song=$(cat ${next});
  rm -f ${next};
}

# begin with: empty string song:
# until song contains a path to a file that both
  # 1: exists
  # 2: has valid audio file headers
until [ -e "$song" ] && (file --mime-type "$song" |grep audio >/dev/null); do
  # If song isnt empty (above conditions werent satisfied:
    # Log song to bad song file
  [ -n "$song" ] && echo "Skipping $song" >> $BAD_SONG_LOG
  # Get potential selection
  candidate=$(selecta)
  # Ensure we haven't already marked it as bad
  while grep -q "$candidate" $BAD_SONG_LOG; do
    # try again if so
    candidate=$(selecta)
  done
  # Return song to loop for validation
  song="${MEDIA_DIR}/${candidate}"
done

now_playing=${LOG_ROOT}/now-playing
[ -e $now_playing ] && cp $now_playing ${LOG_ROOT}/previous
echo "${song}" |tee $now_playing
