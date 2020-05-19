#!/bin/bash
[ -z "${CHUNEBOT_TOKEN}" ] && { echo "CHUNEBOT_TOKEN is missing"; exit 1; }
TMPDIR=$(mktemp -d)
OVERWRITE_CONFIG=${OVERWRITE_CONFIG:-false}

function cleanup() {
  rm -rf $TMPDIR
}

trap cleanup EXIT

function tokenizeConfigForStream() {
  local _stream=$(echo $1|tr '[:lower:]' '[:upper:]')
  local _config="ezstream-${stream}.xml"

  # Define STREAM_$key variables from stream vars
  for _key in HOST PASSWORD MOUNT NAME URL GENRE DESCRIPTION PLAYLISTS; do
    local _src="STREAM_${_stream}_${_key}"
    local _dst="STREAM_${_key}"
    # Copy _src var contents to _dst var
    # Fallback to _src (STREAM_${_key}) if no stream-specific entry is present
    declare "STREAM_${_key}=${!_src:-${!_dst}}"
    [ -z "${!_dst}" ] && { echo "${_dst} variable undefined for $_stream"; exit 1; }
  done
 
  # Tokenize config
  sed -i'' \
    -e "s/STREAM_HOST/${STREAM_HOST}/g" \
    -e "s/STREAM_PORT/${STREAM_PORT}/g" \
    -e "s/STREAM_PASSWORD/${STREAM_PASSWORD}/g" \
    -e "s/STREAM_MOUNT/${STREAM_MOUNT}/g" \
    -e "s|STREAM_URL|${STREAM_URL}|g" \
    -e "s/STREAM_NAME/${STREAM_NAME}/g" \
    -e "s/STREAM_GENRE/${STREAM_GENRE}/g" \
    -e "s/STREAM_DESCRIPTION/${STREAM_DESCRIPTION}/g" \
    -e "s/STREAM_PLAYLISTS/${STREAM_PLAYLISTS}/g" \
    ${TMPDIR}/${_config}
}

function initConfig() {
  local _config=$1

  # Provide config-specific pre-tokenization manipulation
  case $_config in
    ezstream*)
      # strip 'ezstream-'
      _stream=${_config:9}
      _config="${_config}.xml"
      # dont overwrite an existing user config (remove it manually first)
      [ -f /config/${_config} ] && return
      # Copy untokenized configs from protected area
      cp /etc/ezstream/ezstream.xml ${TMPDIR}/${_config}
      tokenizeConfigForStream $_stream
      # Copy config to user volume location
      cp ${TMPDIR}/${_config} /config
      chmod 600 /config/${_config}
    ;;
  chunebot)
    sed -i \
      -e "s/CHUNEBOT_TOKEN/${CHUNEBOT_TOKEN}/g" \
      -e "s/STREAM_HOST/${STREAM_HOST}/g" \
      -e "s/STREAM_PORT/${STREAM_PORT}/g" \
      -e "s|STREAM_URL|${STREAM_URL}|g" \
      /chunebot/chunebot.py
  esac
}

for stream in ${AUTOSTREAMS}; do
  initConfig ezstream-${stream}
done
initConfig chunebot
