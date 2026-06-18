#!/usr/bin/env bash
# Fuzzy tab switcher for kitty using fzf
# Based on: https://github.com/kovidgoyal/kitty/issues/1303

all_tabs="$(
  kitty @ ls | jq -r '
    .[]
    | select(.is_active)
    | .tabs[]
    | select(.is_focused == false)
    | [.title, "id:\(.id)"]
    | @tsv
  ' | column -ts $'\t'
)"

if [ -z "$all_tabs" ]; then
  echo "No other tabs to switch to"
  sleep 1
  exit 0
fi

new_tab_id="$(fzf --reverse --prompt="Switch to tab: " <<< "${all_tabs}" | awk '{ print $NF }')"

if [ -n "$new_tab_id" ]; then
  kitty @ focus-tab -m "${new_tab_id}"
fi
