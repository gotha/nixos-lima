#!/usr/bin/env bash
set -euo pipefail

VERBOSE=${VERBOSE:-1}
SSH_ARGS_WITH_TARGET=("$@")
# arguments like: -F ~/.lima/mynixos/ssh.config lima-mynixos

function debug() {
  LEVEL=$1; shift
  if [ "$LEVEL" -lt "$VERBOSE" ]; then
    echo "${@}"
  fi
}

function active_ports() {
  docker container ls --format '{{.Ports}}' \
    | sed -e 's/, /\n/g;s/->[^[:space:]]*//g' \
    | sort | uniq \
    | ignore_privileged_ports
}

function ignore_privileged_ports() {
  # priveliged ports require root to bind to localhost interface
  # lima hostagend does bind to any and filter to to localhost incoming connections
  # use this accellerated portforwarding only for non-priveliged ports
  sed -E -e '/:.{1,3}$/d;/:10[01]$/d;/102[01234]$/d'
}

function port_to_ssh_portmapping() {
  # translate to localhost binding IPv4 0.0.0.0 => 127.0.0.1 and IPv6 [::] => [::1]
  sed -e 's/\(.*\)/\1:\1/;s/0.0.0.0/127.0.0.1/;s/\[::\]/[::1]/'
}

function ssh_all_ports() {
  # shellcheck disable=SC2153
  echo "$PORTS" | while read -r PORT; do
    if [ -n "$PORT" ]; then
      MAPPING=$(echo "$PORT" | port_to_ssh_portmapping)
      ssh "${SSH_ARGS_WITH_TARGET[@]}" -O "$MODE" -L "$MAPPING" || echo "failed ssh $MODE $MAPPING"
    fi
  done
}

function watch_expose_ports() {
  debug 0 "Starting partmapperd"
  debug 1 "  env: DOCKER_HOST $DOCKER_HOST"
  debug 1 "  env: CONTAINER_HOST $CONTAINER_HOST"
  LAST=
  (echo; docker events) | while read -r; do

    NEW=$(active_ports)
    if [ "$LAST" = "$NEW" ]; then
      debug 2 "skip"
      continue
    fi
    trap 'PORTS=$NEW MODE=cancel ssh_all_ports' EXIT

    ADD=$(comm -1 -3 <(echo "$LAST") <(echo "$NEW"))
    REMOVE=$(comm -2 -3 <(echo "$LAST") <(echo "$NEW"))
    debug 1 "adding '$ADD'  removing '$REMOVE'"
    PORTS=$ADD MODE=forward ssh_all_ports
    PORTS=$REMOVE MODE=cancel ssh_all_ports

    LAST="$NEW"
  done
}

watch_expose_ports
