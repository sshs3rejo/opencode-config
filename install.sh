#!/usr/bin/env bash
set -euo pipefail

REPO_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/opencode"
STAMP="$(date +%Y%m%d-%H%M%S)-$$"
BACKUP_DIR="$CONFIG_DIR/backup-$STAMP"
DRY_RUN=0

usage() {
  printf 'Uso: %s [--dry-run]\n' "${0##*/}"
}

log() { printf '[opencode-config] %s\n' "$*"; }

run() {
  if [ "$DRY_RUN" -eq 1 ]; then
    printf '[dry-run] %s\n' "$*"
  else
    "$@"
  fi
}

backup_path() {
  local path="$1" name="$2"
  if [ -L "$path" ]; then
    run rm -f -- "$path"
    return
  fi
  if [ -e "$path" ]; then
    run mkdir -p -- "$BACKUP_DIR"
    run mv -- "$path" "$BACKUP_DIR/$name"
    log "backup: $name -> $BACKUP_DIR/$name"
  fi
}

for arg in "$@"; do
  case "$arg" in
    --dry-run) DRY_RUN=1 ;;
    -h|--help) usage; exit 0 ;;
    *) printf 'Argumento desconhecido: %s\n' "$arg" >&2; usage >&2; exit 2 ;;
  esac
done

run mkdir -p -- "$CONFIG_DIR"

for f in opencode.json cli.json opencode-mem.jsonc; do
  backup_path "$CONFIG_DIR/$f" "$f"
  run ln -s -- "$REPO_DIR/config/$f" "$CONFIG_DIR/$f"
done

backup_path "$CONFIG_DIR/skills" "skills"
run ln -s -- "$REPO_DIR/skills" "$CONFIG_DIR/skills"

if [ "$DRY_RUN" -eq 1 ]; then
  log "dry-run concluído; nada foi alterado"
  exit 0
fi

mkdir -p -- "$CONFIG_DIR/secrets"
chmod 700 -- "$CONFIG_DIR/secrets"
if [ ! -f "$CONFIG_DIR/secrets/github-pat" ]; then
  log "AVISO: crie $CONFIG_DIR/secrets/github-pat com seu PAT do GitHub (chmod 600)."
fi

log "instalado; config em $CONFIG_DIR"
if [ -d "$BACKUP_DIR" ]; then
  log "backup em $BACKUP_DIR"
fi
