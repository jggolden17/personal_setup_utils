#!/bin/bash
# New-machine setup: adds vendor apt repos, installs from Aptfile, copies
# configs from this repo's snapshot onto the machine, sets up python/poetry/
# node, and installs keyd. Safe to re-run. Mirrors macos/setup.sh's shape;
# see linux/README.md for what didn't translate 1:1 from macOS.
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

if [ "$(uname)" != "Linux" ]; then
  echo "This script only supports Linux." >&2
  exit 1
fi

if [ ! -r /etc/os-release ] || ! grep -qx 'ID=ubuntu' /etc/os-release; then
  echo "This script only supports Ubuntu." >&2
  exit 1
fi

sudo -v

# curl/gnupg are needed by add_repo below to fetch and dearmor vendor keys;
# stock Ubuntu desktop installs usually have them, server installs may not.
run sudo apt-get update
run sudo apt-get install -y curl ca-certificates gnupg

### 2. Add vendor apt repos, then install everything from the Aptfile #########

add_repo() {
  # Adds a vendor apt repo idempotently — skips if its .list/sources file
  # already exists. Exact key URLs/package names: verify at install time.
  case "$1" in
    gh)
      [ -f /etc/apt/sources.list.d/github-cli.list ] && return 0
      run bash -o pipefail -c "curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg | sudo dd of=/usr/share/keyrings/githubcli-archive-keyring.gpg"
      run bash -c "echo 'deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main' | sudo tee /etc/apt/sources.list.d/github-cli.list >/dev/null"
      ;;
    terraform)
      [ -f /etc/apt/sources.list.d/hashicorp.list ] && return 0
      run bash -o pipefail -c "curl -fsSL https://apt.releases.hashicorp.com/gpg | sudo gpg --batch --yes --dearmor -o /usr/share/keyrings/hashicorp-archive-keyring.gpg"
      run bash -c "echo 'deb [signed-by=/usr/share/keyrings/hashicorp-archive-keyring.gpg] https://apt.releases.hashicorp.com $(lsb_release -cs) main' | sudo tee /etc/apt/sources.list.d/hashicorp.list >/dev/null"
      ;;
    kubectl)
      [ -f /etc/apt/sources.list.d/kubernetes.list ] && return 0
      run bash -o pipefail -c "curl -fsSL https://pkgs.k8s.io/core:/stable:/v1.31/deb/Release.key | sudo gpg --batch --yes --dearmor -o /usr/share/keyrings/kubernetes-apt-keyring.gpg"
      run bash -c "echo 'deb [signed-by=/usr/share/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/v1.31/deb/ /' | sudo tee /etc/apt/sources.list.d/kubernetes.list >/dev/null"
      ;;
    docker-ce)
      [ -f /etc/apt/sources.list.d/docker.list ] && return 0
      run bash -o pipefail -c "curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --batch --yes --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg"
      run bash -c "echo 'deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable' | sudo tee /etc/apt/sources.list.d/docker.list >/dev/null"
      ;;
    google-cloud-cli)
      [ -f /etc/apt/sources.list.d/google-cloud-sdk.list ] && return 0
      run bash -o pipefail -c "curl -fsSL https://packages.cloud.google.com/apt/doc/apt-key.gpg | sudo gpg --batch --yes --dearmor -o /usr/share/keyrings/cloud.google.gpg"
      run bash -c "echo 'deb [signed-by=/usr/share/keyrings/cloud.google.gpg] https://packages.cloud.google.com/apt cloud-sdk main' | sudo tee /etc/apt/sources.list.d/google-cloud-sdk.list >/dev/null"
      ;;
    1password | 1password-cli)
      [ -f /etc/apt/sources.list.d/1password.list ] && return 0
      run bash -o pipefail -c "curl -fsSL https://downloads.1password.com/linux/keys/1password.asc | sudo gpg --batch --yes --dearmor -o /usr/share/keyrings/1password-archive-keyring.gpg"
      run bash -c "echo 'deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/1password-archive-keyring.gpg] https://downloads.1password.com/linux/debian/$(dpkg --print-architecture) stable main' | sudo tee /etc/apt/sources.list.d/1password.list >/dev/null"
      ;;
    mongodb-org)
      [ -f /etc/apt/sources.list.d/mongodb-org.list ] && return 0
      run bash -o pipefail -c "curl -fsSL https://pgp.mongodb.com/server-7.0.asc | sudo gpg --batch --yes --dearmor -o /usr/share/keyrings/mongodb-server-7.0.gpg"
      run bash -c "echo 'deb [signed-by=/usr/share/keyrings/mongodb-server-7.0.gpg] https://repo.mongodb.org/apt/ubuntu $(lsb_release -cs)/mongodb-org/7.0 multiverse' | sudo tee /etc/apt/sources.list.d/mongodb-org.list >/dev/null"
      ;;
    postgresql)
      [ -f /etc/apt/sources.list.d/pgdg.list ] && return 0
      run bash -o pipefail -c "curl -fsSL https://www.postgresql.org/media/keys/ACCC4CF8.asc | sudo gpg --batch --yes --dearmor -o /usr/share/keyrings/postgresql-archive-keyring.gpg"
      run bash -c "echo 'deb [signed-by=/usr/share/keyrings/postgresql-archive-keyring.gpg] https://apt.postgresql.org/pub/repos/apt $(lsb_release -cs)-pgdg main' | sudo tee /etc/apt/sources.list.d/pgdg.list >/dev/null"
      ;;
    eza)
      [ -f /etc/apt/sources.list.d/eza.list ] && return 0
      run bash -o pipefail -c "curl -fsSL https://raw.githubusercontent.com/eza-community/eza/main/deb.asc | sudo gpg --batch --yes --dearmor -o /usr/share/keyrings/eza-archive-keyring.gpg"
      run bash -c "echo 'deb [signed-by=/usr/share/keyrings/eza-archive-keyring.gpg] http://deb.gierens.de stable main' | sudo tee /etc/apt/sources.list.d/eza.list >/dev/null"
      ;;
    keyd)
      compgen -G "/etc/apt/sources.list.d/keyd-team-ubuntu-ppa*.list" >/dev/null && return 0
      run sudo add-apt-repository -y ppa:keyd-team/ppa
      ;;
    ulauncher)
      compgen -G "/etc/apt/sources.list.d/agornostal-ubuntu-ulauncher*.list" >/dev/null && return 0
      run sudo add-apt-repository -y ppa:agornostal/ulauncher
      ;;
    spotify)
      [ -f /etc/apt/sources.list.d/spotify.list ] && return 0
      run bash -o pipefail -c "curl -fsSL https://download.spotify.com/debian/pubkey_C85668DF69375001.gpg | sudo gpg --batch --yes --dearmor -o /usr/share/keyrings/spotify-archive-keyring.gpg"
      run bash -c "echo 'deb [signed-by=/usr/share/keyrings/spotify-archive-keyring.gpg] http://repository.spotify.com stable non-free' | sudo tee /etc/apt/sources.list.d/spotify.list >/dev/null"
      ;;
    firefox)
      # Mozilla's own repo, not Ubuntu 24.04's default snap-transitional
      # package — a preferences pin is required or apt keeps preferring the
      # snap-transitional package on upgrade.
      if [ ! -f /etc/apt/sources.list.d/mozilla.list ]; then
        run bash -o pipefail -c "curl -fsSL https://packages.mozilla.org/apt/repo-signing-key.gpg | sudo gpg --batch --yes --dearmor -o /usr/share/keyrings/packages.mozilla.org.gpg"
        run bash -c "echo 'deb [signed-by=/usr/share/keyrings/packages.mozilla.org.gpg] https://packages.mozilla.org/apt mozilla main' | sudo tee /etc/apt/sources.list.d/mozilla.list >/dev/null"
      fi
      if [ ! -f /etc/apt/preferences.d/mozilla ]; then
        run bash -c "printf 'Package: *\nPin: origin packages.mozilla.org\nPin-Priority: 1000\n' | sudo tee /etc/apt/preferences.d/mozilla >/dev/null"
      fi
      ;;
    *)
      echo "Unknown repo: $1" >&2; exit 1 ;;
  esac
}

install_deb() {
  # One-off vendor .deb downloads (no ongoing apt repo).
  local name="$1" url tmp
  case "$name" in
    visual-studio-code) url="https://go.microsoft.com/fwlink/?LinkID=760868" ;;
    dbeaver-community) url="https://dbeaver.io/files/dbeaver-ce_latest_amd64.deb" ;;
    google-chrome) url="https://dl.google.com/linux/direct/google-chrome-stable_current_amd64.deb" ;;
    slack) url="https://downloads.slack-edge.com/desktop-releases/linux/x64/latest/slack-desktop-amd64.deb" ;;
    zoom) url="https://zoom.us/client/latest/zoom_amd64.deb" ;;
    obsidian)
      if $DRY_RUN; then
        echo "  [dry-run] resolve latest obsidian .deb release URL from GitHub API, then download + install"
        return 0
      fi
      url="$(curl -fsSL https://api.github.com/repos/obsidianmd/obsidian-releases/releases/latest | grep -oE 'https://[^"]+amd64\.deb' | head -1)"
      ;;
    todoist-app) url="https://todoist.com/linux_app?platform=deb" ;;
    *) echo "Unknown deb package: $name" >&2; exit 1 ;;
  esac
  [ -z "${url:-}" ] && return 0
  tmp="$(mktemp --suffix=.deb)"
  run curl -fsSL "$url" -o "$tmp"
  run sudo dpkg -i "$tmp" || run sudo apt-get install -yf
  run rm -f "$tmp"
}

install_binary() {
  # Direct GitHub-release binary installs for tools with no apt package.
  local name="$1" arch
  arch="$(dpkg --print-architecture)"
  case "$name" in
    git-delta)
      command -v delta >/dev/null && { log "skip (already installed): delta"; return 0; }
      run bash -o pipefail -c "curl -fsSL \$(curl -fsSL https://api.github.com/repos/dandavison/delta/releases/latest | grep -oE 'https://[^\"]+${arch}\.deb') -o /tmp/delta.deb && sudo dpkg -i /tmp/delta.deb"
      ;;
    lazygit)
      command -v lazygit >/dev/null && { log "skip (already installed): lazygit"; return 0; }
      run bash -c "LG_VERSION=\$(curl -fsSL https://api.github.com/repos/jesseduffield/lazygit/releases/latest | grep -Po '\"tag_name\": \"v\\K[^\"]*') && curl -fsSL -o /tmp/lazygit.tar.gz \"https://github.com/jesseduffield/lazygit/releases/latest/download/lazygit_\${LG_VERSION}_Linux_x86_64.tar.gz\" && tar xf /tmp/lazygit.tar.gz -C /tmp lazygit && sudo install /tmp/lazygit /usr/local/bin"
      ;;
    yq)
      command -v yq >/dev/null && { log "skip (already installed): yq"; return 0; }
      run bash -c "sudo curl -fsSL -o /usr/local/bin/yq https://github.com/mikefarah/yq/releases/latest/download/yq_linux_amd64 && sudo chmod +x /usr/local/bin/yq"
      ;;
    websocat)
      command -v websocat >/dev/null && { log "skip (already installed): websocat"; return 0; }
      run bash -c "sudo curl -fsSL -o /usr/local/bin/websocat https://github.com/vi/websocat/releases/latest/download/websocat.x86_64-unknown-linux-musl && sudo chmod +x /usr/local/bin/websocat"
      ;;
    *) echo "Unknown binary: $name" >&2; exit 1 ;;
  esac
}

install_script() {
  local name="$1"
  case "$name" in
    starship)
      command -v starship >/dev/null && { log "skip (already installed): starship"; return 0; }
      run bash -o pipefail -c "curl -fsSL https://starship.rs/install.sh | sh -s -- -y"
      ;;
    pyenv)
      [ -d "$HOME/.pyenv" ] && { log "skip (already installed): pyenv"; return 0; }
      run bash -o pipefail -c "curl -fsSL https://pyenv.run | bash"
      ;;
    poetry)
      command -v poetry >/dev/null && { log "skip (already installed): poetry"; return 0; }
      run bash -o pipefail -c "curl -fsSL https://install.python-poetry.org | python3 -"
      ;;
    oci-cli)
      command -v oci >/dev/null && { log "skip (already installed): oci"; return 0; }
      run bash -o pipefail -c "curl -fsSL https://raw.githubusercontent.com/oracle/oci-cli/master/scripts/install/install.sh | bash -s -- --accept-all-defaults"
      ;;
    claude-code)
      command -v claude >/dev/null && { log "skip (already installed): claude"; return 0; }
      run bash -o pipefail -c "curl -fsSL https://claude.ai/install.sh | bash"
      ;;
    *) echo "Unknown script install: $name" >&2; exit 1 ;;
  esac
}

APT_PACKAGES=()
VSCODE_EXTENSIONS=()

log "Adding vendor apt repos and running installer scripts"
while read -r kind name rest; do
  case "$kind" in
    ''|'#'*) continue ;;
    apt) APT_PACKAGES+=("$name") ;;
    repo) add_repo "$name" ;;
    deb) : ;; # installed after `apt-get update` below, once repos are registered
    binary) : ;;
    script) : ;;
    vscode) VSCODE_EXTENSIONS+=("$name") ;;
    *) echo "Unknown Aptfile line kind: $kind $name $rest" >&2; exit 1 ;;
  esac
done < "$DOTFILES_DIR/Aptfile"

log "apt-get update"
run sudo apt-get update

log "Installing apt packages: ${APT_PACKAGES[*]}"
if $DRY_RUN; then
  echo "  [dry-run] sudo apt-get install -y ${APT_PACKAGES[*]}"
else
  sudo apt-get install -y "${APT_PACKAGES[@]}"
fi

log "Installing vendor .deb packages, GitHub-release binaries, and install scripts"
while read -r kind name rest; do
  case "$kind" in
    deb) install_deb "$name" ;;
    binary) install_binary "$name" ;;
    script) install_script "$name" ;;
    *) continue ;;
  esac
done < "$DOTFILES_DIR/Aptfile"

log "Installing VS Code extensions"
for ext in "${VSCODE_EXTENSIONS[@]}"; do
  run code --install-extension "$ext"
done

### 3. Copy configs from the manifest ##########################################

log "Copying configs"
while IFS='|' read -r repo_rel dest_template; do
  case "$repo_rel" in
    ''|'#'*) continue ;;
  esac
  dest="${dest_template//\$HOME/$HOME}"
  copy_config "$DOTFILES_DIR/$repo_rel" "$dest"
done < "$DOTFILES_DIR/manifest.txt"

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

# pyenv/poetry are curl-installed scripts (install_script above), not apt
# packages, so nothing has put them on this script's own PATH yet — unlike
# macos/setup.sh, where brew shellenv already symlinks both into PATH.
export PYENV_ROOT="$HOME/.pyenv"
export PATH="$PYENV_ROOT/bin:$HOME/.local/bin:$PATH"

log "Installing pyenv python versions"
for v in 3.10 3.11 3.12 3.13 3.14; do
  resolved="$(pyenv latest -k "$v" 2>/dev/null || echo "$v")"
  run pyenv install -s "$resolved"
done
LATEST_314="$(pyenv latest -k 3.14 2>/dev/null || echo 3.14)"
run pyenv global "$LATEST_314"

run poetry config virtualenvs.in-project true
run poetry config keyring.enabled false

### 4b. Docker group #############################################################

# Without this, every docker command (including `docker login` below) needs
# sudo. Takes effect on next login, not this shell.
if id -nG "$USER" 2>/dev/null | grep -qw docker; then
  log "skip (already in docker group): $USER"
else
  run sudo usermod -aG docker "$USER"
fi

### 5. keyd ########################################################################

log "Installing keyd config"
run sudo mkdir -p /etc/keyd
run sudo cp "$DOTFILES_DIR/configs/keyd/default.conf" /etc/keyd/default.conf
run sudo systemctl enable keyd
run sudo systemctl restart keyd

### 6. Summary ####################################################################
# No chsh/default-shell step: Ubuntu's default new-user login shell is already
# /bin/bash, unlike macOS's ancient system bash — see macos/setup.sh step 5.

DONE_SUFFIX=""
if $DRY_RUN; then
  DONE_SUFFIX=" (dry run, nothing was changed)"
fi

cat <<EOF

==> Done${DONE_SUFFIX}. Manual steps still required:
  1. GitHub SSH key: generate it and add it to ssh-agent (eval \$(ssh-agent)),
     no Keychain equivalent on Linux — see linux/setup_guide.md.
  2. Sign into: gh auth login, gcloud auth login, claude login, docker login.
  3. Install the "Tiling Assistant" GNOME Shell extension via Extension
     Manager for Rectangle-style quarter-tiling.
  4. keyd: caps-lock -> escape is active; the fn/cmd swap from Karabiner does
     not translate to PC keyboards (fn is intercepted in firmware) — see
     linux/README.md.
  5. Obsidian: set up sync (separate from this repo).
  6. GNOME Settings: background, extensions, favorites/dock as preferred.
  7. Open a new terminal (or run 'exec bash') to pick up shell config changes.
  8. Log out and back in (or 'newgrp docker') to pick up docker group
     membership — 'docker' commands need sudo until then.
EOF
