#!/usr/bin/env bash
# The optional telemetry of a Wheelhouse: one standing `ynr relay` that its seats report through.
# Nothing here runs unless ynr is installed and the human said yes; a Wheelhouse without ynr, or one
# that never ran `init`, is exactly what it was. There is no daemon: `start` runs the relay in the
# foreground (the human's own terminal, tmux or launchd), and `stop` ends it.
#
# Usage: telemetry.sh <command> [--dir <wheelhouse root>] [options]
#   init [--port N] [--spool DIR] [--key-file FILE]
#                 needs ynr on PATH, else it changes nothing and exits 4. Creates the relay's HMAC
#                 key if it is missing (32 random bytes, mode 0600, in a mode 0700 folder), refusing a
#                 key path inside the Wheelhouse repository or the spool; records the port (and a
#                 non-default spool) under "telemetry" in <dir>/wheelhouse.json, keeping every other
#                 key. The key is never printed. Prints a JSON summary.
#   start         runs `ynr relay` on 127.0.0.1:<port> in the foreground, with the key and spool.
#   stop          ends the relay `start` ran (by its recorded process id; nothing else is touched).
#   show          prints the state as JSON: opted in, port, spool, key file (present, mode), running.
#   endpoint      prints the relay's endpoint, http://127.0.0.1:<port>, for ynh run's
#                 YNH_TELEMETRY_RELAY_ENDPOINT.
#   configure-ynh [--remove]
#                 sets (or with --remove deletes) "telemetry_relay_endpoint" in $YNH_HOME/config.json,
#                 touching no other key. It is ynh's setting for the whole machine, so run it only
#                 when the human says so; the same value can instead be exported for one shell.
# The key lives in ${YNH_HOME:-~/.ynh}/telemetry/<the desk harness's name>/relay.key unless --key-file
# says otherwise. The default spool is ${XDG_STATE_HOME:-~/.local/state}/ynr/spool/local.
# Exit codes: 0 done, 1 refused (unsafe path, already running, not opted in), 2 bad usage, 4 ynr missing.
set -uo pipefail

cmd="${1:-}"; [ $# -gt 0 ] && shift
dir="." port="" spool="" keyfile="" remove=0
while [ $# -gt 0 ]; do
  case "$1" in
    --dir) dir="${2:-}"; [ $# -ge 2 ] && shift; shift ;;
    --port) port="${2:-}"; [ $# -ge 2 ] && shift; shift ;;
    --spool) spool="${2:-}"; [ $# -ge 2 ] && shift; shift ;;
    --key-file) keyfile="${2:-}"; [ $# -ge 2 ] && shift; shift ;;
    --remove) remove=1; shift ;;
    *) echo "telemetry.sh: unknown option $1" >&2; exit 2 ;;
  esac
done
case "$cmd" in init|start|stop|show|endpoint|configure-ynh) ;;
  *) sed -n '2,/^set -/p' "$0" | sed '$d;s/^# \{0,1\}//' >&2; exit 2 ;;
esac
command -v jq >/dev/null 2>&1 || { echo "telemetry.sh: jq is required" >&2; exit 2; }
[ -d "$dir" ] || { echo "telemetry.sh: no such folder: $dir" >&2; exit 2; }
dir=$(cd "$dir" && pwd -P)

ynh_home="${YNH_HOME:-$HOME/.ynh}"
wj="$dir/wheelhouse.json"
name=$(jq -r '.name // empty' "$dir/.agents/harness/plugin.json" 2>/dev/null)
[ -n "$name" ] || name=$(basename "$dir")
case "$name" in *[!A-Za-z0-9._-]*|"") name=$(printf '%s' "$name" | tr -c 'A-Za-z0-9._-' '_') ;; esac
state="$ynh_home/telemetry/$name"
pidfile="$state/relay.pid"
default_spool="${XDG_STATE_HOME:-$HOME/.local/state}/ynr/spool/local"

conf() { jq -r "$1" "$wj" 2>/dev/null; }
opted_in() { [ -f "$wj" ] && [ "$(conf '.telemetry.relay_port // empty')" != "" ]; }
cfg_port() { conf '.telemetry.relay_port // empty'; }
cfg_spool() { s=$(conf '.telemetry.spool // empty'); echo "${s:-$default_spool}"; }
cfg_key() { k=$(conf '.telemetry.key_file // empty'); echo "${k:-$state/relay.key}"; }
# A path made absolute with its deepest existing folder resolved, so /tmp and /private/tmp compare alike.
abspath() {
  local p="$1" tail=""
  case "$p" in /*) ;; *) p="$PWD/$p" ;; esac
  while [ ! -d "$p" ] && [ "$p" != "/" ]; do tail="/$(basename "$p")$tail"; p=$(dirname "$p"); done
  printf '%s%s' "$(cd "$p" && pwd -P)" "$tail"
}
inside() { case "$(abspath "$1")/" in "$(abspath "$2")"/*) return 0 ;; *) return 1 ;; esac; }
mode_of() { stat -f '%Lp' "$1" 2>/dev/null || stat -c '%a' "$1" 2>/dev/null; }
alive() { [ -f "$pidfile" ] && p=$(cat "$pidfile" 2>/dev/null) && [ -n "$p" ] && kill -0 "$p" 2>/dev/null \
  && ps -p "$p" -o command= 2>/dev/null | grep -q 'ynr.* relay'; }
port_busy() { (exec 3<>"/dev/tcp/127.0.0.1/$1") 2>/dev/null; }

case "$cmd" in
  init)
    command -v ynr >/dev/null 2>&1 || { echo "ynr is not installed: telemetry not set up, nothing changed" >&2; exit 4; }
    if [ -z "$port" ]; then
      port=4318
      while port_busy "$port"; do port=$((port + 1)); done
    fi
    case "$port" in ''|*[!0-9]*) echo "telemetry.sh: --port wants a number" >&2; exit 2 ;; esac
    [ "$port" -ge 1024 ] && [ "$port" -le 65535 ] || { echo "telemetry.sh: --port wants 1024 to 65535" >&2; exit 2; }
    [ -n "$spool" ] || spool="$default_spool"
    [ -n "$keyfile" ] || keyfile="$state/relay.key"
    if inside "$keyfile" "$dir"; then echo "refused: the key file would be inside the Wheelhouse repository ($dir)" >&2; exit 1; fi
    if inside "$keyfile" "$spool" || inside "$spool" "$(dirname "$keyfile")"; then
      echo "refused: the key file and the spool must not contain one another" >&2; exit 1
    fi
    created=false
    if [ ! -f "$keyfile" ]; then
      ( umask 077; mkdir -p "$(dirname "$keyfile")" && chmod 700 "$(dirname "$keyfile")" 2>/dev/null
        head -c 32 /dev/urandom > "$keyfile" ) || { echo "telemetry.sh: could not write the key file" >&2; exit 1; }
      created=true
    fi
    chmod 600 "$keyfile"
    cur="{}"; [ -f "$wj" ] && cur=$(cat "$wj")
    jq -e 'type == "object"' >/dev/null 2>&1 <<<"$cur" || { echo "refused: $wj is not a JSON object" >&2; exit 1; }
    kf_json=null; [ "$keyfile" = "$state/relay.key" ] || kf_json=$(jq -n --arg k "$keyfile" '$k')
    sp_json=null; [ "$spool" = "$default_spool" ] || sp_json=$(jq -n --arg s "$spool" '$s')
    jq --argjson p "$port" --argjson s "$sp_json" --argjson k "$kf_json" \
      '.telemetry = ({relay_port: $p} + (if $s == null then {} else {spool: $s} end) + (if $k == null then {} else {key_file: $k} end))' \
      <<<"$cur" > "$wj.tmp" && mv "$wj.tmp" "$wj"
    jq -n --argjson port "$port" --arg spool "$spool" --arg key "$keyfile" --argjson created "$created" \
      '{optedIn: true, port: $port, endpoint: ("http://127.0.0.1:" + ($port | tostring)), spool: $spool,
        keyFile: $key, keyCreated: $created, keyPrinted: false,
        next: "telemetry.sh start runs the relay in the foreground; telemetry.sh configure-ynh points ynh run at it"}'
    ;;
  endpoint)
    opted_in || { echo "not opted in: run telemetry.sh init first" >&2; exit 1; }
    echo "http://127.0.0.1:$(cfg_port)"
    ;;
  start)
    opted_in || { echo "not opted in: run telemetry.sh init first" >&2; exit 1; }
    command -v ynr >/dev/null 2>&1 || { echo "ynr is not installed" >&2; exit 4; }
    key=$(cfg_key); sp=$(cfg_spool); pt=$(cfg_port)
    [ -f "$key" ] || { echo "refused: the key file is missing; run telemetry.sh init" >&2; exit 1; }
    [ "$(mode_of "$key")" = "600" ] || { echo "refused: the key file's mode is not 0600" >&2; exit 1; }
    alive && { echo "refused: the relay is already running (process $(cat "$pidfile"))" >&2; exit 1; }
    mkdir -p "$state" "$sp"
    echo $$ > "$pidfile"
    exec ynr relay --listen "127.0.0.1:$pt" --key-file "$key" --spool "$sp"
    ;;
  stop)
    alive || { rm -f "$pidfile"; echo "the relay is not running"; exit 0; }
    p=$(cat "$pidfile"); kill "$p" 2>/dev/null; rm -f "$pidfile"; echo "stopped the relay (process $p)"
    ;;
  show)
    if ! opted_in; then jq -n '{optedIn: false}'; exit 0; fi
    key=$(cfg_key); present=false; mode=""
    [ -f "$key" ] && { present=true; mode=$(mode_of "$key"); }
    outside=true; inside "$key" "$dir" && outside=false; inside "$key" "$(cfg_spool)" && outside=false
    running=false; alive && running=true
    jq -n --argjson port "$(cfg_port)" --arg spool "$(cfg_spool)" --arg key "$key" --argjson present "$present" \
      --arg mode "$mode" --argjson outside "$outside" --argjson running "$running" \
      '{optedIn: true, port: $port, endpoint: ("http://127.0.0.1:" + ($port | tostring)), spool: $spool,
        keyFile: {path: $key, present: $present, mode: $mode, outsideRepoAndSpool: $outside}, running: $running}'
    ;;
  configure-ynh)
    cf="$ynh_home/config.json"
    cur="{}"; [ -f "$cf" ] && cur=$(cat "$cf")
    jq -e 'type == "object"' >/dev/null 2>&1 <<<"$cur" || { echo "refused: $cf is not a JSON object" >&2; exit 1; }
    if [ "$remove" = 1 ]; then
      jq 'del(.telemetry_relay_endpoint)' <<<"$cur" > "$cf.tmp" && mv "$cf.tmp" "$cf"; echo "removed telemetry_relay_endpoint from $cf"
    else
      opted_in || { echo "not opted in: run telemetry.sh init first" >&2; exit 1; }
      mkdir -p "$ynh_home"
      jq --arg e "http://127.0.0.1:$(cfg_port)" '.telemetry_relay_endpoint = $e' <<<"$cur" > "$cf.tmp" && mv "$cf.tmp" "$cf"
      echo "set telemetry_relay_endpoint in $cf"
    fi
    ;;
esac
