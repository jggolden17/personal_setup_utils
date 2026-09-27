# Setup guide

This is a reminder to myself of steps to get setup on a new machine.

## 1. Install homebrew

```sh
/bin/bash -c "$(
  curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh
)"
```

## 2. Configure github

### 2.1 Log into github

First, install chrome:

```sh
brew install --cask google-chrome
```

Set up perosnal profile. Log into github on this machine.

### 2.2 Configure git & clone this repo

Get latest versions (apple default git technically installed with homebrew, but not necessarily latest):

```sh
brew install git
git --version
```

Generate a new SSH key for this machine, with some identifier for this key locally and on GitHub:

```sh
KEY_LABEL="your_key_label"
ssh-keygen -t ed25519 -C "$KEY_LABEL"
```

- when prompted, save the key file to default location (`~/.ssh/id_ed25519`)
- when prompted set pw on this machine for added security

Configure SSH to load the key automatically and save its passphrase in the macOS Keychain:

```sh
mkdir -p ~/.ssh

cat >> ~/.ssh/config <<'EOF'
Host github.com
  AddKeysToAgent yes
  UseKeychain yes
  IdentityFile ~/.ssh/id_ed25519
EOF

chmod 600 ~/.ssh/config
```

Add the private key to the SSH agent and macOS Keychain:

```sh
/usr/bin/ssh-add --apple-use-keychain ~/.ssh/id_ed25519
```

Copy the **public** key, then add it to GitHub under [SSH and GPG keys](https://github.com/settings/keys):

```sh
pbcopy < ~/.ssh/id_ed25519.pub
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

The repo contains a script that sets most things up. This is done automatically, but the steps are explained below.

### 3.1 Install everything

First, installs from [Brewfile](./Brewfile):

- Apps
  - editors (vim, vs code, etc.)
  - programming (git, github, docker, etc.)
  - ai (claude)
  - browsers & google
  - other apps (slack, zoom, etc.)
- Terminal
- python
- VS code extensions

Node itself isn't installed here — it comes from nvm, which `setup.sh` installs
directly after copying configs in step 3.2 (Homebrew's node install is unsupported
by nvm). It installs the current Node LTS and the global npm packages listed in
`configs/npm-globals.txt`.

### 3.2 Copy configs onto this machine

This repo holds a point-in-time **snapshot** of dotfiles and configs, not the live
master — there are no symlinks back to it. `setup.sh` copies each snapshot file to
its destination on this machine; after that, the machine's own files are what
matter, and this repo is just where the next machine's snapshot starts from.

It copies configs for:

- settings and configs
  - claude
  - vs code
  - poetry
  - starship, karabiner
- dotfiles
  - bash, zsh
  - vim and neovim
  - git
  - tmux

Note: obsidian settings come from a different sync process, not this repo.

### 3.3 Set up python & poetry

It installs various python versions (3.10 to 3.14), sets global (3.14), configures poetry, etc.

### 3.4 Make BASH default

macOS ships an older bash (3.2, for licensing reasons) as `/bin/bash` and defaults
new shells to zsh; I prefer a current bash as my login shell, so this step registers
the Homebrew-installed bash and switches to it. Done by `setup.sh`.

### Remap keys with karabiner-elements

`setup.sh` copies `configs/karabiner/karabiner.json`, which maps caps-lock to
escape and swaps fn/cmd on the built-in keyboard. The one manual step: grant
Karabiner its Input Monitoring and driver permissions in System Settings when
prompted, since that can't be scripted.

## Set up clouds

### GCP

### Oracle

## Configure iTerm2

- theme
- allow reading from clipboard

## 9. System preferences

- background colour I like
- Download journal app
- what do I keep in doc / quick access:
  - Chrome
  - VS code
  - Slack
  - Obsidian
  - Claude
  - Journal

## 10. Set up Obsidian with sync

## Finally: verify

Verify that everything is set up as expected.

- claude working in vs code

---
