# Shared between bash and any other POSIX-ish shell. Sourced by bashrc so
# shell-agnostic setup doesn't drift from bash-specific setup.

export PYENV_ROOT="$HOME/.pyenv"
[[ -d "$PYENV_ROOT/bin" ]] && export PATH="$PYENV_ROOT/bin:$PATH"

export PATH="$HOME/.local/bin:$PATH"

# gcloud CLI: the google-cloud-cli apt package symlinks its binaries straight
# into /usr/bin, unlike the macOS cask, so no PATH export is needed here.

# nvm itself. Its bash_completion script runs compinit as a side effect under
# zsh; this repo is bash-only on Linux, so that's moot, but it's still sourced
# from bashrc (after bash's own completion setup) to match the macOS layout.
export NVM_DIR="$HOME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"

# fzf: use a dedicated history file, not the shell's own, since this is shared
export FZF_DEFAULT_OPTS="--height 40% --border --history=$HOME/.fzf_history"
export FZF_CTRL_R_OPTS='--reverse --no-sort'
export FZF_DEFAULT_COMMAND='rg --files --hidden --follow --glob "!.git"'
export FZF_CTRL_T_COMMAND="$FZF_DEFAULT_COMMAND"

# Nicer replacements for standard tools. Debian/Ubuntu ship fd and bat under
# renamed binaries (fdfind, batcat) to avoid clashing with unrelated packages
# already using those names.
command -v eza >/dev/null && alias ls='eza --group-directories-first --icons=auto'
command -v batcat >/dev/null && alias cat='batcat --paging=never'
command -v fdfind >/dev/null && alias fd='fdfind'
