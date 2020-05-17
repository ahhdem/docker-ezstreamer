#!/bin/bash
TMPDIR=$(mktemp -d)


function init() {
  /tokenize.sh
  chown -R icecast /var/log/icecast
}


function run_icecast() {
  pidfile="/${TMPDIR}/icy.pid"
  while true; do
    icecast -n -c /etc/icecast/icecast.xml&
    if [ -n "$1" ]; then 
      echo $! > $pidfile
      tail --pid $(cat $pidfile) -f /dev/null
    fi
    echo "$(date) Restarting icecast"
    sleep 2; # prevent fork flood
  done
}

function run_ezstream() {
  pidfile="/${TMPDIR}/ez.pid"
  while true; do
    ezstream -c /etc/icecast/ezstream.xml&
    if [ -n "$1" ]; then 
      echo $! > $pidfile
      tail --pid $(cat $pidfile) -f /dev/null
    fi
    echo "$(date) Restarting ezstream"
    sleep 2; # prevent fork flood
  done
}

while true; do
  init
  run_icecast
  run_ezstream
  tail --pid $(cat /tmp/icy.pid) -f /dev/null
done
