# linux/ — what didn't translate 1:1 from macos/

This tree mirrors `macos/`'s layout and covers the same machine setup on
Ubuntu 24.04 LTS, but a few things either have no Linux equivalent, needed a
substitution, or are worth flagging before you rely on them. Nothing below
was silently dropped or silently swapped — see `Aptfile`/`setup.sh` for
exactly where each of these is handled.

## No good translation — dropped

- **GitHub Desktop** (`github` cask) — no maintained official Linux build.
  `gh` CLI + `lazygit` (already in both setups) cover the same ground from
  the terminal.
- **Claude desktop app** (`claude` cask) — no official Linux desktop build.
  Use claude.ai in the browser; the `claude-code` CLI is unaffected and
  installs via its own official installer.
- **Google Drive** — no official Linux sync client. `rclone mount` is an
  option for filesystem-level access, left as a manual/optional step rather
  than installing a third-party sync client unasked.
- **WhatsApp** — no official Linux desktop client. Use web.whatsapp.com.
- **Spotify and MongoDB apt repos** — dropped, not for lack of a Linux build,
  but because both repeatedly broke setup: Spotify rotates its signing key
  without notice (`NO_PUBKEY` failures), and MongoDB's repo lags Ubuntu LTS
  support (e.g. 7.0 has no `noble` build). Use Spotify's web player or a
  flatpak/snap, and install MongoDB manually if/when needed.
- **Karabiner's fn/cmd swap** — `keyd` covers the caps-lock → escape mapping,
  but PC keyboards don't expose `fn` as an OS-visible key at all (it's
  intercepted in firmware before the OS ever sees it), so there's nothing for
  `keyd`, or any other Linux remapper, to remap even in principle. This isn't
  a "wrong tool" problem — it's not scriptable on this hardware class.

## Substituted, not a 1:1 port

- **Docker Desktop → Docker Engine + Compose plugin.** Linux already has the
  kernel Docker needs; Docker Desktop's VM/GUI layer exists on macOS
  specifically because macOS doesn't have a Linux kernel to share.
- **iTerm2 → GNOME Terminal.** tmux/starship already own multiplexing and
  prompt styling; a fancier terminal buys little here. iTerm2's Claude Code
  integration (`cc-status`) has no Linux counterpart — Claude Code's
  `Notification` hook is wired to `notify-send` instead (GNOME ships
  `libnotify` by default), which is a narrower but zero-dependency stand-in.
- **Karabiner-Elements → keyd.** Evdev-level remapping, works under X11 and
  Wayland, actively maintained. Only covers caps-lock → escape (see above).
- **Rectangle → GNOME's built-in tiling + "Tiling Assistant" extension.**
  GNOME 24.04 ships basic Super+Left/Right tiling; the Tiling Assistant
  GNOME Shell extension adds Rectangle-style quarter-tiling. Installed via
  the Extension Manager app — GNOME extensions aren't a normal apt/deb
  install, so this is a manual step (see `setup_guide.md`).
- **Raycast → Ulauncher.** Closest match: extensible launcher, plugin
  ecosystem, active development, has its own apt-installable PPA.

## One-off flags

- **`npm-globals.txt` line 5** (`wscatverbose`) — this reads literally as one
  word with no space, in both `macos/configs/npm-globals.txt` and this
  Linux copy. Looks like a pre-existing typo unrelated to this migration;
  left as-is rather than silently "fixed" in a Linux-only file.
- **`yq` apt-name collision** — Ubuntu/Debian's `yq` apt package is the
  unrelated Python `kislyuk/yq` wrapper, not the Go `mikefarah/yq` this setup
  wants. `setup.sh` installs the Go binary release directly and skips apt
  for this one entirely.
- **SSH agent** — macOS's `ssh-add --apple-use-keychain` and
  `UseKeychain yes` are Apple-only OpenSSH extensions. The Linux setup guide
  uses plain `ssh-agent`/`eval $(ssh-agent)` instead, which doesn't persist
  the passphrase across reboots the way Keychain does — re-run `ssh-add`
  after a reboot, or look into `gnome-keyring`'s ssh-agent integration if
  that's worth automating later.
- **Package names/repo URLs in `Aptfile`/`setup.sh` are unverified** — this
  was written without a Linux box to test against. The apt package names,
  PPA names, and GPG-key URLs for the vendor repos (Docker, gh, HashiCorp,
  Kubernetes, Google Cloud, 1Password, PGDG, eza, keyd, Ulauncher, Mozilla)
  and the direct `.deb`/binary URLs (VS Code, Chrome,
  Slack, Zoom, Obsidian, DBeaver, Todoist, lazygit, git-delta, yq, websocat)
  are correct as of when this was written, but package versions and URLs
  drift — expect to fix a handful of these on first real run.
  `postgresql-18`'s exact package name in particular depends on PGDG's
  current major version at install time, and Todoist's `.deb` install URL
  in particular hasn't been checked to actually serve a `.deb` (Todoist's
  Linux distribution has moved around between formats historically) — if
  it 404s, `set -e` stops the whole run right there, before configs/nvm/
  keyd; re-run after fixing the URL, `copy_config`/`add_repo`/etc. are all
  idempotent so nothing already done gets redone.
- **`--dry-run` was tested by stubbing out the Ubuntu-only parts** (`dpkg`,
  `lsb_release`, `apt-get`, `code`) on macOS, not by running it on a real
  Ubuntu box — full end-to-end correctness (package availability, actual
  apt resolution, keyd/systemd behavior) is still unverified until step 3
  of Verification below.
- **Docker needs `newgrp docker` or a re-login** after `setup.sh` adds
  `$USER` to the `docker` group — the running shell doesn't pick up new
  group membership automatically, so `docker` commands (including the
  `docker login` in the summary) still need `sudo` until then.
