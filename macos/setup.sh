#!/bin/bash
# New-machine setup: installs from Brewfile, copies configs from this repo's
# snapshot onto the machine, sets up python/poetry/node, and makes bash the
# default shell. Safe to re-run. Requires bash 3.2 (Apple's /bin/bash) for
# the first run, before `brew install bash` even happens.
set -euo pipefail

DRY_RUN=false
for arg in "$@"; do
  case "$arg" in
    --dry-run) DRY_RUN=true ;;
    *) echo "Unknown argument: $arg" >&2; exit 1 ;;
  esac
done

DOTFILES_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BACKUP_DIR="$HOME/.config_backup/$(date +%Y%m%d%H%M%S)"
NVM_VERSION="v0.40.1"

log() { echo "==> $*"; }

# Runs a state-changing command, or just prints it under --dry-run.
run() {
  if $DRY_RUN; then
    echo "  [dry-run] $*"
  else
    "$@"
  fi
}

ensure_line() {
  local file="$1" line="$2"
  if [ -f "$file" ] && grep -qxF "$line" "$file" 2>/dev/null; then
    log "skip (already present in $file): $line"
    return 0
  fi
  log "adding to $file: $line"
  if $DRY_RUN; then
    echo "  [dry-run] append to $file: $line"
  else
    echo "$line" | sudo tee -a "$file" >/dev/null
  fi
}

copy_config() {
  local src="$1" dest="$2" destdir
  destdir="$(dirname "$dest")"

  if [ -e "$dest" ] && [ ! -d "$dest" ] && cmp -s "$src" "$dest"; then
    log "skip (identical): $dest"
    return 0
  fi

  run mkdir -p "$destdir"

  if [ -e "$dest" ]; then
    log "backing up existing $dest"
    run mkdir -p "$(dirname "$BACKUP_DIR/${dest#"$HOME"/}")"
    run mv "$dest" "$BACKUP_DIR/${dest#"$HOME"/}"
  fi

  log "copying $dest"
  run cp "$src" "$dest"

  case "$(basename "$dest")" in
    *.sh) run chmod +x "$dest" ;;
  esac
}

### 1. Preflight ##############################################################

if [ "$(uname)" != "Darwin" ]; then
  echo "This script only supports macOS." >&2
  exit 1
fi

if [ -x /opt/homebrew/bin/brew ]; then
  BREW=/opt/homebrew/bin/brew
elif [ -x /usr/local/bin/brew ]; then
  BREW=/usr/local/bin/brew
else
  echo "Homebrew not found. Run setup_guide.md step 1 first." >&2
  exit 1
fi
eval "$("$BREW" shellenv)"
HOMEBREW_PREFIX="$("$BREW" --prefix)"

### 2. Install everything from the Brewfile ###################################

log "Installing packages from Brewfile"
if $DRY_RUN; then
  "$BREW" bundle check --file="$DOTFILES_DIR/Brewfile" --verbose || true
else
  "$BREW" bundle install --file="$DOTFILES_DIR/Brewfile"
fi

### 3. Copy configs from the manifest ##########################################

log "Copying configs"
while IFS='|' read -r repo_rel dest_template; do
  case "$repo_rel" in
    ''|'#'*) continue ;;
  esac
  dest="${dest_template//\$HOME/$HOME}"
  copy_config "$DOTFILES_DIR/$repo_rel" "$dest"
done < "$DOTFILES_DIR/manifest.txt"

# Claude Code's Notification/Stop/etc hooks call into iTerm's own cc-status
# binary; this repo doesn't ship a copy, it just links to the installed app.
CC_STATUS_LINK="$HOME/.config/iterm2/cc-status"
CC_STATUS_TARGET="/Applications/iTerm.app/Contents/Resources/utilities/cc-status"
if [ -e "$CC_STATUS_TARGET" ]; then
  if [ -L "$CC_STATUS_LINK" ] && [ "$(readlink "$CC_STATUS_LINK")" = "$CC_STATUS_TARGET" ]; then
    log "skip (identical): $CC_STATUS_LINK"
  else
    run mkdir -p "$(dirname "$CC_STATUS_LINK")"
    run ln -sfn "$CC_STATUS_TARGET" "$CC_STATUS_LINK"
  fi
else
  log "iTerm.app not found yet; re-run setup.sh after it's installed to link cc-status"
fi

### 3b. Node via nvm ############################################################

if [ ! -s "$HOME/.nvm/nvm.sh" ]; then
  log "Installing nvm $NVM_VERSION"
  run bash -c "curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/$NVM_VERSION/install.sh | PROFILE=/dev/null bash"
else
  log "skip (already installed): nvm"
fi

if $DRY_RUN; then
  echo "  [dry-run] nvm install --lts && nvm alias default lts/* && npm install -g <configs/npm-globals.txt>"
else
  mkdir -p "$HOME/.nvm"
  set +eu
  # shellcheck disable=SC1090,SC1091
  . "$HOME/.nvm/nvm.sh"
  nvm install --lts
  nvm alias default 'lts/*'
  npm install -g $(cat "$DOTFILES_DIR/configs/npm-globals.txt")
  set -eu
fi

### 4. Python & poetry ##########################################################

log "Installing pyenv python versions"
for v in 3.10 3.11 3.12 3.13 3.14; do
  resolved="$(pyenv latest -k "$v" 2>/dev/null || echo "$v")"
  run pyenv install -s "$resolved"
done
LATEST_314="$(pyenv latest -k 3.14 2>/dev/null || echo 3.14)"
run pyenv global "$LATEST_314"

run poetry config virtualenvs.in-project true
run poetry config keyring.enabled false

### 5. Default shell #############################################################

BASH_PATH="$HOMEBREW_PREFIX/bin/bash"
if [ -x "$BASH_PATH" ]; then
  ensure_line /etc/shells "$BASH_PATH"
  CURRENT_SHELL="$(dscl . -read "/Users/$USER" UserShell 2>/dev/null | awk '{print $2}')"
  if [ "$CURRENT_SHELL" != "$BASH_PATH" ]; then
    run sudo chsh -s "$BASH_PATH" "$USER"
  else
    log "skip (already default shell): $BASH_PATH"
  fi
else
  log "$BASH_PATH not found yet; re-run setup.sh after Brewfile install completes"
fi

### 6. Summary ####################################################################

DONE_SUFFIX=""
if $DRY_RUN; then
  DONE_SUFFIX=" (dry run, nothing was changed)"
fi

cat <<EOF

==> Done${DONE_SUFFIX}. Manual steps still required:
  1. iTerm2: import prefs (or set them manually), enable "allow clipboard access".
  2. Sign into: gh auth login, gcloud auth login, claude login, docker login.
  3. Karabiner: grant Input Monitoring + driver permissions in System Settings.
  4. Obsidian: set up sync (separate from this repo).
  5. macOS Dock / System Settings: arrange as preferred.
  6. Open a new terminal (or run 'exec bash') to pick up the new default shell.
EOF
