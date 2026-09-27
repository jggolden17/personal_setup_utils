# Personal setup utils

Personal machine setup: package lists, dotfiles, and a script that snapshots
a fresh install into the shape I'm used to. Two independent, self-contained
trees, one per OS — each has its own package manager, config layout, and
`setup.sh`, so neither has to accommodate the other's paths or tooling:

- **[`macos/`](./macos)** — Homebrew-based, for macOS laptops.
- **[`linux/`](./linux)** — apt-based, for Ubuntu 24.04 LTS laptops. See
  [`linux/README.md`](./linux/README.md) for what doesn't have a direct
  macOS-tool equivalent and what was substituted instead.

Each tree follows the same layout (`setup.sh`, `manifest.txt`, `configs/`,
`setup_guide.md`) and the same model: this repo deliberately holds a point-in-time
**snapshot** of dotfiles/configs, not a live master with symlinks back to
it. `setup.sh` copies the snapshot onto a fresh machine; `snapshot.sh`
(macOS only, for now) pulls local changes back into the repo for review.

Start with the `setup_guide.md` in whichever tree matches the machine ([MacOS](./macos/setup_guide.md), [Linux](./linux/setup_guide.md)).
