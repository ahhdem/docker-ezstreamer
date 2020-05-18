#!/bin/bash
[ -z "${CHUNEBOT_TOKEN}" ] && { echo "CHUNEBOT_TOKEN is missing"; exit 1; }
TMPDIR=$(mktemp -d)

function cleanup() {
  rm -rf $TMPDIR
}

trap cleanup EXIT

function tokenizeConfigForStream() {
  local _stream=$(echo $1|tr '[:lower:]' '[:upper:]')
  local _config="ezstream-${stream}.xml"

  # Define ICECAST_$key variables from stream vars
  for _key in HOST PASSWORD MOUNT NAME URL; do
    local _src="ICECAST_${_stream}_${_key}"
    local _dst="ICECAST_${_key}"
    # Copy _src var contents to _dst var
    # Fallback to _src (ICECAST_${_key}) if no stream-specific entry is present 
    declare "ICECAST_${_key}=${!_src:-${!_dst}}"
    [ -z "${!_dst}" ] && { echo "${_dst} variable undefined for $_stream"; exit 1; }
  done
  
  # Tokenize config
  sed -i'' \
    -e "s/ICECAST_HOST/${ICECAST_HOST}/g" \
    -e "s/ICECAST_PASSWORD/${ICECAST_PASSWORD}/g" \
    -e "s/ICECAST_MOUNT/${ICECAST_MOUNT}/g" \
    -e "s|ICECAST_URL|${ICECAST_URL}|g" \
    -e "s/ICECAST_NAME/${ICECAST_MOUNT}/g" \
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
      cp /etc/ezstream.xml ${TMPDIR}/${_config}
      tokenizeConfigForStream $_stream
      # Copy config to user volume location
      cp ${TMPDIR}/${_config} /config
      chmod 600 /config/${_config}
    ;;
  chunebot)
    sed -i'' -e "s/CHUNEBOT_TOKEN/${CHUNEBOT_TOKEN}/g" /chunebot.py
  esac
}

for stream in ${AUTOSTREAMS}; do
  initConfig ezstream-${stream}
done
initConfig chunebot
