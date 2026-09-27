#!/bin/bash
# Refreshes configs/ from the live files on this machine, so changes can be
# reviewed with `git diff` before committing. Uses the same manifest as
# setup.sh, so anything not in the manifest (never-commit files) can't be
# captured by accident.
set -euo pipefail

DRY_RUN=false
for arg in "$@"; do
  case "$arg" in
    --dry-run) DRY_RUN=true ;;
    *) echo "Unknown argument: $arg" >&2; exit 1 ;;
  esac
done

DOTFILES_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

log() { echo "==> $*"; }

while IFS='|' read -r repo_rel dest_template; do
  case "$repo_rel" in
    ''|'#'*) continue ;;
  esac
  dest="${dest_template//\$HOME/$HOME}"
  repo_path="$DOTFILES_DIR/$repo_rel"

  if [ ! -e "$dest" ]; then
    log "skip (missing on this machine): $dest"
    continue
  fi

  if [ -e "$repo_path" ] && cmp -s "$dest" "$repo_path"; then
    log "skip (identical): $repo_rel"
    continue
  fi

  if $DRY_RUN; then
    echo "==> would update $repo_rel"
    diff -u "$repo_path" "$dest" 2>/dev/null || true
  else
    log "updating $repo_rel"
    mkdir -p "$(dirname "$repo_path")"
    cp "$dest" "$repo_path"
  fi
done < "$DOTFILES_DIR/manifest.txt"
