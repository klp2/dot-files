# Zellij

Installed by mise on personal machines (see `config/mise/mise.personal.toml`).
Used as the local multiplexer; tmux remains the
remote/SSH multiplexer (see `tmux/`).

**No config by design.** We run pure upstream Zellij defaults to lean on its
on-screen keybinding hints and its clean copy/scroll behavior. If a config is
ever added, put it at `~/.config/zellij/config.kdl` and symlink it from here.
