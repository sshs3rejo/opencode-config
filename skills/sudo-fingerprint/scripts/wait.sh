#!/bin/sh
# wait.sh - wait for the rc file written by sudo-run.sh.
#
# This script is POSIX sh on purpose: the agent's shell tool may be bash, fish,
# or zsh depending on OpenCode's `shell` setting. Invoke it as:
#
#   sh wait.sh <run-id> [timeout-seconds]
#
# It prints "done exit=<status> after=<seconds>" when the command finishes, or
# "timeout after=<seconds>" if it is still running or waiting for the sensor.
set -u

if [ "$#" -lt 1 ]; then
  echo "usage: wait.sh <run-id> [timeout-seconds]" >&2
  exit 2
fi

rid=$1
timeout=${2:-60}

case $rid in
  ''|*[!A-Za-z0-9._-]*)
    echo "invalid run id: $rid" >&2
    exit 2
    ;;
esac

case $timeout in
  ''|*[!0-9]*)
    echo "invalid timeout: $timeout" >&2
    exit 2
    ;;
esac

rc="/tmp/opencode/sudo-${rid}.rc"
i=0
while [ "$i" -lt "$timeout" ]; do
  if [ -f "$rc" ]; then
    printf 'done exit=%s after=%ss\n' "$(cat "$rc")" "$i"
    exit 0
  fi
  sleep 1
  i=$((i + 1))
done

printf 'timeout after=%ss\n' "$timeout"
exit 1
