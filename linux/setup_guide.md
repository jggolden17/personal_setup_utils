# Setup guide (Linux / Ubuntu 24.04)

This is a reminder to myself of steps to get set up on a new Ubuntu laptop.
Mirrors `macos/setup_guide.md`; see `linux/README.md` for everything that
doesn't translate 1:1 from the macOS version.

## 1. apt is already there

Unlike macOS, there's no package manager to bootstrap — apt ships with
Ubuntu. `linux/setup.sh` adds the vendor apt repos it needs (GitHub CLI,
Docker, HashiCorp, Kubernetes, Google Cloud, 1Password, MongoDB, PGDG, eza,
keyd, Ulauncher, Spotify, Mozilla) itself, idempotently, before installing
anything.

## 2. Configure github

### 2.1 Log into github

First, install Chrome (or use Firefox, already installed via
`linux/Aptfile`):

```sh
curl -fsSL https://dl.google.com/linux/direct/google-chrome-stable_current_amd64.deb -o /tmp/chrome.deb
sudo dpkg -i /tmp/chrome.deb || sudo apt-get install -yf
```

Set up personal profile. Log into github on this machine.

### 2.2 Configure git & clone this repo

Ubuntu's `git` package is current enough; no separate install step needed
beyond what `linux/Aptfile` installs.

Generate a new SSH key for this machine:

```sh
KEY_LABEL="your-email@example.com"  # replace with the email you want on the key
ssh-keygen -t ed25519 -C "$KEY_LABEL"
```

- when prompted, save the key file to default location (`~/.ssh/id_ed25519`)
- when prompted set pw on this machine for added security

Configure SSH to load the key automatically. Linux has no Keychain
equivalent — `UseKeychain`/`--apple-use-keychain` are Apple-only OpenSSH
extensions — so the key is added to a plain `ssh-agent` instead, started
once per login session:

```sh
mkdir -p ~/.ssh

cat >> ~/.ssh/config <<'EOF'
Host github.com
  AddKeysToAgent yes
  IdentityFile ~/.ssh/id_ed25519
EOF

chmod 600 ~/.ssh/config
```

Start the agent and add the key (see `linux/README.md` for the caveat that
this doesn't persist across reboots the way macOS Keychain does):

```sh
eval "$(ssh-agent -s)"
ssh-add ~/.ssh/id_ed25519
```

Copy the **public** key, then add it to GitHub under [SSH and GPG keys](https://github.com/settings/keys):

```sh
xclip -selection clipboard < ~/.ssh/id_ed25519.pub
```

Test the connection:

```sh
ssh -T git@github.com
```

Configure Git to rewrite GitHub HTTPS URLs as SSH URLs:

```sh
git config --global url."git@github.com:".insteadOf "https://github.com/"
```

Clone the repository:

```sh
USERNAME="your_username"
mkdir -p ~/Documents/00_repos/{00_s,01_p,02_w}
cd ~/Documents/00_repos/01_p/
git clone "git@github.com:${USERNAME}/personal_setup_utils.git"
cd personal_setup_utils
```

## 3. Run script to install & config

The repo contains a script that sets most things up. This is done
automatically, but the steps are explained below.

### 3.1 Install everything

First, adds vendor apt repos and installs from [Aptfile](./Aptfile):

- Apps
  - editors (vim, vs code, etc.)
  - programming (git, docker engine, etc.)
  - ai (claude-code CLI)
  - browsers & google
  - other apps (slack, zoom, etc.)
- Terminal
- python
- VS code extensions

Node itself isn't installed here — it comes from nvm, which `setup.sh`
installs directly after copying configs in step 3.2 (Homebrew's/apt's node
install is unsupported by nvm, same reasoning as macOS). It installs the
current Node LTS and the global npm packages listed in
`configs/npm-globals.txt`.

### 3.2 Copy configs onto this machine

Same model as macOS: this repo holds a point-in-time **snapshot** of
dotfiles and configs, not the live master — no symlinks back to it.
`setup.sh` copies each snapshot file to its destination on this machine;
after that, the machine's own files are what matter.

It copies configs for:

- settings and configs
  - claude
  - vs code
  - starship
- dotfiles
  - bash (only — no zsh port on Linux, see below)
  - vim and neovim
  - git
  - tmux

Note: obsidian settings come from a different sync process, not this repo.

### 3.3 Set up python & poetry

Same as macOS: installs various python versions (3.10 to 3.14), sets global
(3.14), configures poetry, etc. `linux/Aptfile` includes the apt build deps
pyenv needs to compile Python with lzma/tkinter/ssl support.

### 3.4 Default shell

No step needed here — Ubuntu's default new-user login shell is already
`/bin/bash`, and it's already current, unlike macOS's ancient system bash.
This setup is bash-only on Linux; the zsh dotfiles are not ported (decided
up front — see the plan this tree was built from).

### Remap keys with keyd

`setup.sh` installs `configs/keyd/default.conf` to `/etc/keyd/default.conf`
and enables the `keyd` systemd service. It only maps caps-lock to escape —
the fn/cmd swap from Karabiner doesn't translate to PC keyboards (see
`linux/README.md`). No manual permission-granting step needed (unlike
Karabiner on macOS) — `keyd` runs as a system service via evdev, no consent
prompt.

## Set up clouds

### GCP

### Oracle

## Configure GNOME Terminal

Zero config needed — tmux/starship already own multiplexing and prompt
styling (see `linux/README.md` for why iTerm2 wasn't ported).

## 9. System preferences

- GNOME background/theme I like
- Install the "Tiling Assistant" GNOME Shell extension via Extension
  Manager (`gnome-shell-extension-manager`, installed by `setup.sh`) for
  Rectangle-style quarter-tiling
- Favorites/dock: Chrome, VS Code, Slack, Obsidian, Ulauncher

## 10. Set up Obsidian with sync

## Finally: verify

Verify that everything is set up as expected — see `Verification` in the
plan this tree was built from for the full checklist (bash default shell,
tmux copy-mode clipboard, nvim `unnamedplus`, starship prompt, VS Code
settings/extensions, delta-formatted git diffs, Claude Code statusline and
`notify-send` permission-prompt alerts).

---
