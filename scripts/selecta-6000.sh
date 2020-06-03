#!/bin/bash
. util.sh
exec 2> ${LOG_ROOT}/playlist.err
FALLBACK_STREAM=${FALLBACK_STREAM:-brb}
MEDIA_DIR=${MEDIA_DIR:-/media}
PLAYLIST_DIR=${PLAYLIST_DIR:-/media/playlists}
BAD_SONG_LOG=${BAD_SONG_LOG:-${LOG_ROOT}/bad_songs.log}
# Prevent respawnbomb
[ -z "$LOG_ROOT" ] && { echo "ERROR: LOG_ROOT is empty: ${LOG_ROOT}"; exit 1; }

# Get the command of the streamer process calling us
STREAMER=${1:-$(ps -o cmd= $(ps -o ppid= $PPID)|cut -d\- -f 3|cut -d. -f1)}
PLAYLIST_VAR="STREAM_${STREAMER^^}_PLAYLISTS"
#echo "Computed $PLAYLIST_VAR for $STREAMER_CMD" >> ${LOG_ROOT}/playlist.err
PLAYLISTS=(${!PLAYLIST_VAR})
SONG_LOG="${LOG_ROOT}/playlist.${STREAMER}.log"
NOW_PLAYING=${LOG_ROOT}/now-playing-${STREAMER}
[ -e $NOW_PLAYING ] && cp $NOW_PLAYING ${LOG_ROOT}/previous-${STREAMER}

# randomly play commercials 10 percent of the time
function commercial() {
  # Dont evaluate on fallback stream (or we would flip the logic and pull from other p
  #grep -i "${STREAMER_CMD}" <<< $FALLBACK_STREAM && return 1
  random_chance=10
  ! (($(shuf -i 0-100 -n1) % $random_chance))
}

# choose random playlist from list and random song frmo that
function selecta() {
  local _playlist=''
  # and sometimeas, commercials, for the lulz.
  commercial && _playlist='commercials' || _playlist="${PLAYLISTS[$RANDOM % ${#PLAYLISTS[@]}]}";
  # TODO: fix piping to logger
  # logger "And now, a word from our sponsors..." info >$LOGFIFO;

  local _selection=$(shuf ${PLAYLIST_DIR}/${_playlist}.m3u -n 1)
  echo $_selection
}

function now_playing(){
  local _song="$1"

  # TODO: fix piping to logger
  #logger "Selected: ${song}" info >$LOGFIFO
  echo  "$(date '+%Y-%m-%d %T %Z') ${_song}"  >>${SONG_LOG}
  echo "${_song}" |tee $NOW_PLAYING

}

# If we have already selected a song using a previous/back command,
next=${LOG_ROOT}/next-${STREAMER}
[ -e ${next} ] && {
  song="$(cat ${next})";
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
    # TODO: fix piping to logger
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

now_playing "$song"
