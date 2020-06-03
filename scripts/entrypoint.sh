#!/bin/bash
TMPDIR=$(mktemp -d)     # Set TMPDIR for entrypoint process
. /util.sh              # Import utility functions
initLogger              # Initilize logfolders/files and fifo
#tail -f $LOGFIFO&       # Watch fifo for logs
# Capture logs from other scripts (selecta-6000.sh)
[ -d /tmp/pids ] || ln -s $TMPDIR/ /tmp/pids

function local_cleanup() {
  rm -rf  ${TMPDIR}
  unlink /tmp/pids
}

trap local_cleanup EXIT

declare -A LOGS=( [bad_song]=${LOG_ROOT}/bad_songs.log [missing]=${LOG_ROOT}/missing_songs.log [repair]=${LOG_ROOT}/file_repair.log [failed]=${LOG_ROOT}/failed_repair.log )
for log in ${LOGS[@]}; do touch $log; done

# EZstreamer [via selecta-6000.sh, called in exstreamer-${stream}.xml], will log files not detected as audio to {LOGS['bad_song']}
function ezstreamer() {
  # Start multiple streams
  # AUTOSTREAM_RADIO_PLAYLISTS="classicrock electronic incoming" ??
  AUTOSTREAMS=${AUTOSTREAMS:-"radio commercials"}

  [ ! -e ${LOGS['bad_song']} ] && touch ${LOGS['bad_song']}
  #tail -f ${LOGS['bad_song']}&

  # Periodically check {LOGS['bad_song']} and attempt to repair mp3 files
  fixBadSongs 2>&1 >>${LOGS['repair']}&
  #tail -f ${LOGS['repair']}&

  for stream in $AUTOSTREAMS; do
    supervise $stream ezstream -c /config/ezstream-${stream}.xml & #| tee| logStream $stream info&
  done
  $($USE_CHUNEBOT) && supervise chunebot python3 /chunebot/chunebot.py &#| tee |logStream chunebot info&
}

function invalid() {
  # Provide mechanism to skip songs which failed repair
  local _song="$1"
  grep -q "${_song}" ${LOGS['failed']}
}

function fixBadSongs() {
  [ ! -e ${LOGS['failed']} ] && touch ${LOGS['failed']}
  #tail -f ${LOGS['failed']}&
  # Every 5 mins
  while sleep 300; do
    # Cycle through the mp3 files in the {LOGS['bad_song']}
    for song in $(grep -i mp3 ${LOGS['bad_song']}|awk '{ $1=""; $2=""; print}'); do
      if [ -e "$song" ]; then
        # Preserve timestamp
        local _mtime=$(stat -c %y "$song");
        if ! invalid "$song"; then
          echo "Trying to repair: ${song}"
          mp3val "$song" -f || {
            # Add to {LOGS['failed']} on error
            echo "Failed to repair: $song - See ${LOGS['repair']} for more details" >>${LOGS['failed']};
          }
          # Restore timestamp
          touch -d "$_mtime" "$song"
          # Remove from {LOGS['bad_song']} so we dont repeatedly try to repair
          sed -i'' -e "/^$(echo "$song" |sed -e 's/[]\/$*.^[]/\\&/g')/d" ${LOGS['bad_song']}
        fi
      else
        echo "Missing: '${song}'" >>${LOGS['missing']}
      fi
    done
  done
}

#logger "Running as: $(id)"
/tokenize.sh
ezstreamer
streams=($AUTOSTREAMS)
sleep 10
_pid=$(cat ${TMPDIR}/${streams[0]}.pid)
tail --pid $_pid -f /dev/null
