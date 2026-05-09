# tmux-session-bg

`tmux-session-bg` is a TPM plugin that changes the terminal background color
based on the current tmux session name.

It uses OSC 11 and writes directly to the tmux client TTY, so the background
change applies to the terminal window itself instead of only tmux UI elements.

This plugin assumes that you use
[TPM](https://github.com/tmux-plugins/tpm), the Tmux Plugin Manager.

## Requirements

- `tmux`
- [TPM](https://github.com/tmux-plugins/tpm)
- `bash`
- `awk`
- a terminal emulator that supports OSC 11 background color changes

## Session Name Format

Session names are interpreted with this pattern:

```text
<letter>-<index>-<name>
```

Examples:

```text
p-0-foo
p-1-bar
w-0-work
c-2-client
```

Invalid examples:

```text
foo
pp-0-bar
p-x-bar
p-0-
```

If the session name does not match, the plugin falls back to the default
background color.

## Color Rules

Currently these letters have explicit base colors:

- `p`: `56, 67, 25`
- `w`: `27, 50, 66`
- `c`: `72, 50, 30`

The default fallback color is:

- `#303030`

`index=0` uses the base color. Larger indexes darken the same color family.

Example:

- `p-0-*` is lighter than `p-1-*`
- `p-1-*` is lighter than `p-2-*`

## Installation

This plugin is intended to be installed and loaded through TPM.

Add this to `~/.tmux.conf`:

```tmux
set -g @plugin 'tmux-plugins/tpm'
set -g @plugin 'ymajima/tmux-session-bg'

run '~/.tmux/plugins/tpm/tpm'
```

If tmux is already running:

```sh
tmux source-file ~/.tmux.conf
```

Then install the plugin with `prefix + I`.

## Optional tmux Options

You can override the script path if needed:

```tmux
set -g @session_bg_script "$HOME/.tmux/plugins/tmux-session-bg/scripts/.session-bg.sh"
```

You can disable resetting to the default background on detach:

```tmux
set -g @session_bg_reset_on_detach "0"
```

By default, detach reset is enabled.

## Hooks and Binding

The plugin updates the background on:

- `client-attached`
- `client-session-changed`
- `session-renamed`
- `session-created`
- `client-detached`

It also binds:

- `prefix + B`: re-apply background for all attached clients

## Manual Script Usage

The actual color logic lives in:

```text
scripts/.session-bg.sh
```

Useful commands:

```sh
./scripts/.session-bg.sh color p-0-foo
./scripts/.session-bg.sh color w-1-bar
./scripts/.session-bg.sh apply-all
./scripts/.session-bg.sh reset-client "$(tty)"
```

Supported commands:

```text
apply-client <tty> <session_name>
apply-all
reset-client <tty>
color <session_name>
```

## Development

For local TPM-style development without cloning from GitHub:

```sh
ln -sfn /path/to/this/repo ~/.tmux/plugins/tmux-session-bg
```

Then use this in `~/.tmux.conf`:

```tmux
set -g @plugin 'local/tmux-session-bg'
run '~/.tmux/plugins/tpm/tpm'
```

## Limitations

- The plugin changes the terminal default background, not pane-specific colors.
- Applications that draw their own background, such as Vim, Neovim, `less`,
  `fzf`, or `htop`, may hide the terminal default background.
- Nested tmux setups may not propagate OSC 11 all the way to the outermost
  terminal.
- If the terminal does not support OSC 11, tmux still works but the background
  will not change.

## Repository Layout

```text
session-bg.tmux
scripts/.session-bg.sh
tmux.conf
README.md
```

- `session-bg.tmux`: TPM entrypoint that registers hooks and bindings
- `scripts/.session-bg.sh`: color calculation and OSC writer
- `tmux.conf`: example TPM configuration
