#!/bin/bash
. util.sh
exec 2> ${LOG_ROOT}/playlist.err
FALLBACK_STREAM=${FALLBACK_STREAM:-brb}
PLAYLISTS=($STREAM_RADIO_PLAYLISTS)
MEDIA_DIR=${MEDIA_DIR:-/media}
PLAYLIST_DIR=${PLAYLIST_DIR:-/media/playlists}
BAD_SONG_LOG=${BAD_SONG_LOG:-${LOG_ROOT}/bad_songs.log}
# Prevent respawnbomb
[ -z "$LOG_ROOT" ] && { echo "ERROR: LOG_ROOT is empty: ${LOG_ROOT}"; exit 1; }

# Get the command of the streamer process calling us
STREAMER_CMD=${1:-$(ps -o cmd= $(ps -o ppid= $PPID))}

# If we are called by the brb streamer 
# TODO: pull playlists for multiple streams from STREAM_$STREAM_PLAYLISTS
echo "$STREAMER_CMD" |grep -q $FALLBACK_STREAM && {
  # Pick a random commercial
  _selection=$(shuf ${PLAYLIST_DIR}/commercials.m3u -n 1)
  echo ${MEDIA_DIR}/${_selection}
  exit 0;
}

# randomly play commercials 10 percent of the time
function commercial() {
  random_chance=10
  ! (($(shuf -i 0-100 -n1) % $random_chance))
}

function selecta() {
  local _playlist=''
  _playlist="${PLAYLISTS[$RANDOM % ${#PLAYLISTS[@]}]}";
  commercial && _playlist='commercials';
  # logger "And now, a word from our sponsors..." info >$LOGFIFO;

  local _selection=$(shuf ${PLAYLIST_DIR}/${_playlist}.m3u -n 1)
  echo $_selection
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
  # Get potential selection
    # Log song to bad song file and init-logger:info
    #[ -n "$song" ] && logger $(echo "Skipping 'unplayable' $song" |tee $BAD_SONG_LOG) info >$LOGFIFO
    [ -n "$song" ] && echo "Skipping 'unplayable' $song" >> $BAD_SONG_LOG
  candidate=$(selecta)
  # Ensure we haven't already marked it as bad
  while grep -q "$candidate" $BAD_SONG_LOG; do
    # try again if so
    candidate=$(selecta)
  done
  # Return song to loop for validation
  song="${MEDIA_DIR}/${candidate}"
done

#logger "Selected: ${song}" info >$LOGFIFO
now_playing=${LOG_ROOT}/now-playing
[ -e $now_playing ] && cp $now_playing ${LOG_ROOT}/previous
echo "${song}" |tee $now_playing
