#!/bin/bash
FALLBACK_STREAM=${FALLBACK_STREAM:-brb}
PLAYLISTS=($STREAM_RADIO_PLAYLISTS)
MEDIA_DIR=${MEDIA_DIR:-/media}
PLAYLIST_DIR=${PLAYLIST_DIR:-/media/playlists}
BAD_SONG_LOG=${BAD_SONG_LOG:-${LOG_ROOT}/bad_songs.log}

# Get the command of the streamer process calling us
STREAMER_CMD=$(ps -o cmd= $(ps -o ppid= $PPID))

# If we are called by the brb streamer 
# TODO: pull playlists for multiple streams from STREAM_$STREAM_PLAYLISTS
echo "$STREAMER_CMD" |grep -q $FALLBACK_STREAM && {
  # Pick a random commercial
  find ${MEDIA_DIR}/commercials | shuf -n 1
  exit 0;
}

function selecta() {
  local _playlist=''
  # randomly play commercials 10 percent of the time
  random_chance=10
  ! (($(shuf -i 0-100 -n1) % $random_chance)) \
    && {
       logger "And now, a word from our sponsors..." > $LOGFIFO
       _playlist='commercials' \;
     } \
    || _playlist="${PLAYLISTS[$RANDOM % ${#PLAYLISTS[@]}]}"

   local _selection=$(shuf ${PLAYLIST_DIR}/${_playlist}.m3u -n 1)
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
    # Log song to bad song file and init-logger:info
    [ -n "$song" ] && logger $(echo "Skipping 'unplayable' $song" |tee $BAD_SONG_LOG) info >$LOGFIFO
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

logger "Selected: ${song}" >$LOGFIFO
now_playing=${LOG_ROOT}/now-playing
[ -e $now_playing ] && cp $now_playing ${LOG_ROOT}/previous
echo "${song}" |tee $now_playing
