DEBUG=${DEBUG:-true}
TMPDIR=$(mktemp -d)

function cleanup() {
  rm -rf $TMPDIR
  rm -rf /tmp/pids/
  [ "$(type -t local_cleanup)" == 'function' ] && local_cleanup
}

trap cleanup EXIT

function indexOf() {
  local _key=$1
  shift
  local _arr=($@)
  local _i=0
  
  while [[ "${_arr[$_i]}" != "${_key}" ]]; do
    ((_i++))
  done

  echo $_i
}

#@idempotent
function initLogger() {
  LOG_ROOT=${LOG_ROOT:-/var/log/ezstreamer}
  LOGLEVEL=${LOGLEVEL:-info}
  # TODO: Make LOGLEVELS overrideable
  LOGLEVELS=("debug" "info" "warn" "error")
  LOGFIFO="${LOGFIFO:-${TMPDIR}/init-logger.fifo}"
  [ -e $LOG_ROOT ] || mkdir -p ${LOG_ROOT}
  [ -e $LOGFIFO ] || mkfifo ${LOGFIFO}
}

function getLoglevelIndex() {
  local _level=$1

  echo $(indexOf $_level "${LOGLEVELS[@]}")
}

# returns true for valid loglevels
function loggingAt() {
  local _level=$1

  [ $(getLoglevelIndex $_level) -ge $(getLoglevelIndex $LOGLEVEL) ]
  return $?
}

function logger() {
  local _msg="$1"
  local _sev="${2:-DEBUG}"
  local _facility="${3:-${FUNCNAME[1]}}"

  $(loggingAt ${_sev}) && echo -e "[${_sev}] ${_facility}: ${_msg}"
}

function logStream(){
  local _facility="${1:-${FUNCNAME[1]}}"
  local _sev=${2:-${LOGLEVEL}}
  while read logMsg; do
      logger "$logMsg" "$_sev" "$_facility"
  done
}

# supervise <unitname> your command string 
function supervise() {
  SUPERVISE_RESPAWN_INTERVAL=${SUPERVISE_RESPAWN_INTERVAL:-2}
  local _unit=$1
  shift
  local _cmd=$@
  local _loglevel='info'
  local _
  logger "Starting ${_unit} with ${_cmd}" info
  while sleep ${SUPERVISE_RESPAWN_INTERVAL}; do
    logger "Supervising ${_unit}" info
    # run command
    exec ${_cmd}&
    local _pid=$!
    # Drop pid to manage process
    echo $_pid > ${TMPDIR}/${_unit}.pid
    # Resume waiting for process
    tail --pid $_pid -f /dev/null
    logger "Restarting ${_unit}.." info
  done
  logger "Done"
}
