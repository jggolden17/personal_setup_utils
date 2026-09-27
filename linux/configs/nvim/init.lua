-- Minimal config, no plugins. Mirrors configs/vim/vimrc.

vim.opt.hidden = true
vim.opt.number = true
vim.opt.relativenumber = true
vim.opt.incsearch = true
vim.opt.hlsearch = true

vim.opt.clipboard = "unnamedplus"
vim.opt.ignorecase = true
vim.opt.smartcase = true
vim.opt.splitright = true
vim.opt.splitbelow = true

-- ; → : (skip shift for command mode)
vim.keymap.set("n", ";", ":")

-- Disable arrow keys (normal + insert mode)
for _, mode in ipairs({ "n", "i" }) do
  for _, key in ipairs({ "<Up>", "<Down>", "<Left>", "<Right>" }) do
    vim.keymap.set(mode, key, "<Nop>")
  end
end

-- Ctrl-hjkl for window navigation
vim.keymap.set("n", "<C-h>", "<C-w>h")
vim.keymap.set("n", "<C-j>", "<C-w>j")
vim.keymap.set("n", "<C-k>", "<C-w>k")
vim.keymap.set("n", "<C-l>", "<C-w>l")

-- H/L for start/end of line (overrides default screen-jump behavior)
vim.keymap.set("n", "H", "^")
vim.keymap.set("n", "L", "$")
