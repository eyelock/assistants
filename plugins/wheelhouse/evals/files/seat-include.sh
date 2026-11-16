#!/usr/bin/env bash
# seat_include_plugin <plugin.json>: give a fixture seat what an installed seat has, the plugin's
# work-graph, wake and patrol skills (so the scripts its charter names are on disk where ynh
# installs them), as a local include of the plugin under test (ynh clones the checkout's committed HEAD). A Wheelhouse keeps no copies.
seat_include_plugin() {
  local root
  root=$(git -C "$EVAL_FIXTURES" rev-parse --show-toplevel)
  jq --arg root "$root" '.includes = [{git: $root, path: "plugins/wheelhouse", pick: ["skills/work-graph", "skills/wake", "skills/patrol"]}]' "$1" > "$1.new" \
    && mv "$1.new" "$1"
}
