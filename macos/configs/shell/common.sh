# Shared between bash and zsh. Sourced by both rc files so they don't drift.
# Anything shell-specific (starship/zoxide/direnv/pyenv init, gcloud completion)
# stays in bashrc/zshrc, since their init syntax differs per shell.

HOMEBREW_PREFIX="$(brew --prefix 2>/dev/null || echo /opt/homebrew)"

export PYENV_ROOT="$HOME/.pyenv"
[[ -d "$PYENV_ROOT/bin" ]] && export PATH="$PYENV_ROOT/bin:$PATH"

export PATH="$HOME/.local/bin:$PATH"

# gcloud CLI, installed via the brew cask
export PATH="$PATH:$HOMEBREW_PREFIX/share/google-cloud-sdk/bin"

# nvm itself. Its bash_completion script runs compinit as a side effect under
# zsh, so it's sourced from bashrc/zshrc instead, after each shell's own
# completion setup, not from here.
export NVM_DIR="$HOME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"

# fzf: use a dedicated history file, not the shell's own, since this is shared
export FZF_DEFAULT_OPTS="--height 40% --border --history=$HOME/.fzf_history"
export FZF_CTRL_R_OPTS='--reverse --no-sort'
export FZF_DEFAULT_COMMAND='rg --files --hidden --follow --glob "!.git"'
export FZF_CTRL_T_COMMAND="$FZF_DEFAULT_COMMAND"

# Nicer replacements for standard tools
command -v eza >/dev/null && alias ls='eza --group-directories-first --icons=auto'
command -v bat >/dev/null && alias cat='bat --paging=never'
