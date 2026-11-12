#!/usr/bin/env bash
# sudo-run.sh - run a privileged command in the interactive OpenCode TUI terminal.
#
# Invoke it with bash explicitly (`bash sudo-run.sh ...`) so it works from fish,
# zsh, or any other terminal shell. The script itself relies on bash.
#
# The agent's shell has no TTY, so sudo cannot prompt for a fingerprint there.
# This script runs the command in the user's TUI terminal (a real PTY), captures
# stdout/stderr to a log, and writes the exit status to a .rc file the agent can
# poll. The sudo prompt itself is written to /dev/tty and stays visible.
#
# Usage:
#   sudo-run.sh <run-id> -- <command> [args...]
#   sudo-run.sh <run-id> -- bash -c '<shell pipeline>'
#
# Files:
#   /tmp/opencode/sudo-<run-id>.log
#   /tmp/opencode/sudo-<run-id>.rc
#
# The .rc file is authoritative for the command's exit status. The script's own
# exit status follows the pipeline, not necessarily the command.
set -uo pipefail

usage() {
  printf 'usage: %s <run-id> -- <command> [args...]\n' "${0##*/}" >&2
}

if [ "$#" -lt 3 ] || [ "$2" != "--" ]; then
  usage
  exit 2
fi

rid=$1
shift 2

case $rid in
  ''|*[!A-Za-z0-9._-]*)
    printf 'invalid run id: %s\n' "$rid" >&2
    exit 2
    ;;
esac

umask 077
base="/tmp/opencode/sudo-${rid}"
mkdir -p /tmp/opencode

# Remove stale results so the agent cannot read a previous run.
: > "${base}.log"
rm -f "${base}.rc"

{
  sudo "$@"
  status=$?
  printf '%s\n' "$status" > "${base}.rc"
  exit "$status"
} 2>&1 | tee "${base}.log"
