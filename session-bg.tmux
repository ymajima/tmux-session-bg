#!/usr/bin/env bash

CURRENT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DEFAULT_SCRIPT_PATH="$CURRENT_DIR/scripts/.session-bg.sh"

script_path="$(tmux show-option -gqv @session_bg_script)"
if [ -z "$script_path" ]; then
  script_path="$DEFAULT_SCRIPT_PATH"
  tmux set-option -gq @session_bg_script "$script_path"
fi

if [ -z "$(tmux show-option -gqv @session_bg_reset_on_detach)" ]; then
  tmux set-option -gq @session_bg_reset_on_detach "1"
fi

tmux set-hook -g client-attached "run-shell -b '\"$script_path\" apply-client #{q:client_tty} #{q:client_session}'"
tmux set-hook -g client-session-changed "run-shell -b '\"$script_path\" apply-client #{q:client_tty} #{q:client_session}'"
tmux set-hook -g session-renamed "run-shell -b '\"$script_path\" apply-all'"
tmux set-hook -g session-created "run-shell -b '\"$script_path\" apply-all'"
tmux set-hook -g client-detached "run-shell -b 'if [ \"#{@session_bg_reset_on_detach}\" = \"1\" ]; then \"$script_path\" reset-client #{q:client_tty}; fi'"

tmux bind-key B run-shell -b "\"$script_path\" apply-all"
