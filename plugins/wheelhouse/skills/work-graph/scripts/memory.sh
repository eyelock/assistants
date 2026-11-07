#!/usr/bin/env bash
# One memory wrapper for a Wheelhouse: seat and human memory over ynm or Beads,
# chosen by wheelhouse.json at the Wheelhouse root ({"memory": "ynm" | "beads"}).
# No file, or no "memory" key, means ynm, running the ynm commands the skills have
# always given. Every script and skill reads and writes seat and human memory only
# through this, so the key layout Beads needs lives in one place.
#
#   remember  write a memory of a kind
#   recall    read memories, newest first, as JSON: [{id, kind, text, at, by, bead}]
#   forget    retire a memory by the id recall gave
#   sync      share memory (and, with Beads, the work graph, which is the same database)
#   backend   print ynm or beads
#
# Kinds: identity, birth, handoff, kudos, close-note (all of a seat: --seat),
#        note (an FYI for a human: --human), fact (shared by the Wheelhouse).
#
# Beads keys (a memory's id is its key):
#   seat/<c>/identity | birth | handoff      one key each, rewritten in place
#   seat/<c>/kudos/<UTC stamp>-<actor>
#   seat/<c>/close-note/<UTC stamp>-<bead id>
#   human/<c>/note/<UTC stamp>-<actor>
#   wheelhouse/<slug>                        shared facts
#
# Run it from the Wheelhouse repository's root, or pass --dir.
# Output: JSON on stdout (remember, forget and sync print one object, recall an
# array); diagnostics on stderr.
# Exit codes: 0 done, 1 bad args or refused, 2 not a Wheelhouse or a bad
# wheelhouse.json, 3 a tool it needs (jq, ynm, bd) is missing or failed. A failure
# is an error, never an empty answer.
set -uo pipefail

usage() {
  cat <<'EOF2'
Usage: memory.sh remember --actor <seat> --kind <kind> (--seat <c> | --human <c>) --text <text|->
                          [--bead <id>] [--slug <slug>]
       memory.sh recall   [--kind <kind>] (--seat <c> | --human <c> | --shared) [--limit <n>]
       memory.sh forget   --id <id> --reason <why>
       memory.sh sync     [--end]
       memory.sh backend
Kinds: identity, birth, handoff, kudos, close-note, note, fact.
Common: --dir <wheelhouse root>   (default: the current directory)
        --text - reads the text from stdin. close-note needs --bead; fact takes neither --seat nor --human.
EOF2
}
die() { local c=$1; shift; echo "memory.sh: $*" >&2; exit "$c"; }
need() { command -v "$1" >/dev/null 2>&1 || die 3 "$1 is not installed"; }

cmd="${1:-}"
case "$cmd" in
  remember | recall | forget | sync | backend) shift ;;
  -h | --help | "") usage; [ -n "$cmd" ] && exit 0; exit 1 ;;
  *) usage >&2; die 1 "unknown command: $cmd" ;;
esac

dir="" actor="" kind="" seat="" human="" shared=0 text="" id="" reason="" bead="" slug="" limit=20 end=0 havetext=0
while [ $# -gt 0 ]; do
  case "$1" in
    --dir) dir="${2-}"; shift 2 || die 1 "--dir needs a value" ;;
    --actor) actor="${2-}"; shift 2 || die 1 "--actor needs a value" ;;
    --kind) kind="${2-}"; shift 2 || die 1 "--kind needs a value" ;;
    --seat) seat="${2-}"; shift 2 || die 1 "--seat needs a value" ;;
    --human) human="${2-}"; shift 2 || die 1 "--human needs a value" ;;
    --shared) shared=1; shift ;;
    --text) [ $# -ge 2 ] || die 1 "--text needs a value"; text="$2"; havetext=1; shift 2 ;;
    --id) id="${2-}"; shift 2 || die 1 "--id needs a value" ;;
    --reason) reason="${2-}"; shift 2 || die 1 "--reason needs a value" ;;
    --bead) bead="${2-}"; shift 2 || die 1 "--bead needs a value" ;;
    --slug) slug="${2-}"; shift 2 || die 1 "--slug needs a value" ;;
    --limit) limit="${2-}"; shift 2 || die 1 "--limit needs a value" ;;
    --end) end=1; shift ;;
    --json) shift ;;
    -h | --help) usage; exit 0 ;;
    *) usage >&2; die 1 "unknown argument: $1" ;;
  esac
done

need jq
[ -z "$dir" ] || cd "$dir" 2>/dev/null || die 2 "no such directory: $dir"

# The backend: wheelhouse.json's "memory", ynm when there is no file or no key.
backend=ynm
if [ -f wheelhouse.json ]; then
  jq -e 'type == "object"' wheelhouse.json >/dev/null 2>&1 || die 2 "wheelhouse.json is not a JSON object"
  backend=$(jq -r '.memory // "ynm"' wheelhouse.json)
  case "$backend" in ynm | beads) ;; *) die 2 "wheelhouse.json: memory must be \"ynm\" or \"beads\", not \"$backend\"" ;; esac
fi

if [ "$cmd" = backend ]; then echo "$backend"; exit 0; fi

# A name that goes into a namespace or a key: lowercase letters, digits, dot, dash, underscore.
valid_name() { [[ "$1" =~ ^[a-z0-9][a-z0-9._-]*$ ]]; }
valid_kind() { case "$1" in identity | birth | handoff | kudos | close-note | note | fact) return 0 ;; *) return 1 ;; esac; }
seat_kind() { case "$1" in identity | birth | handoff | kudos | close-note) return 0 ;; *) return 1 ;; esac; }

limited() {
  local secs="$1"; shift
  if command -v perl >/dev/null 2>&1; then perl -e 'alarm shift; exec @ARGV' -- "$secs" "$@"; else "$@"; fi
}
hasgitremote() { git remote 2>/dev/null | grep -q .; }
hasdoltremote() { bd dolt remote list --json 2>/dev/null | jq -e '(.data? // .) | length > 0' >/dev/null 2>&1; }

errfile=$(mktemp "${TMPDIR:-/tmp}/memory.XXXXXX") || die 3 "cannot make a temp file"
trap 'rm -f "$errfile"' EXIT

# ---------------------------------------------------------------- sync
if [ "$cmd" = sync ]; then
  mem=skipped work=skipped
  done_word=synced; secs=60
  if [ "$end" = 1 ]; then done_word=pushed; secs=12; fi
  if [ "$backend" = ynm ]; then
    need ynm
    if hasgitremote; then
      if limited "$secs" ynm sync --quiet >/dev/null 2>&1; then mem=$done_word; else mem=failed; fi
    fi
  else
    need bd
    # Memory and work share one Dolt database: one sync, one result for both.
    if hasdoltremote; then
      if limited "$secs" bd sync >/dev/null 2>&1; then mem=$done_word; else mem=failed; fi
      work=$mem
    fi
  fi
  jq -nc --arg b "$backend" --arg m "$mem" --arg w "$work" '{backend: $b, memory: $m, work: $w}'
  exit 0
fi

# ---------------------------------------------------------------- scope checks
scope_args() { # validates --seat/--human/--shared against the kind; sets scope
  if [ -n "$kind" ]; then
    valid_kind "$kind" || die 1 "unknown kind: $kind (identity, birth, handoff, kudos, close-note, note, fact)"
  fi
  [ -z "$seat" ] || valid_name "$seat" || die 1 "--seat must be a command name (lowercase letters, digits, . _ -)"
  [ -z "$human" ] || valid_name "$human" || die 1 "--human must be a command name (lowercase letters, digits, . _ -)"
  local n=0
  [ -z "$seat" ] || n=$((n + 1)); [ -z "$human" ] || n=$((n + 1)); [ "$shared" = 0 ] || n=$((n + 1))
  [ "$n" -le 1 ] || die 1 "give one of --seat, --human, --shared"
  if [ -n "$kind" ]; then
    if seat_kind "$kind"; then
      [ -n "$seat" ] || die 1 "$kind needs --seat <command>"
      [ -z "$human" ] && [ "$shared" = 0 ] || die 1 "$kind is a seat's: use --seat"
    elif [ "$kind" = note ]; then
      [ -n "$human" ] || die 1 "note needs --human <command>"
      [ -z "$seat" ] && [ "$shared" = 0 ] || die 1 "note is a human's: use --human"
    else
      [ -z "$seat" ] && [ -z "$human" ] || die 1 "fact is shared: give neither --seat nor --human"
    fi
  fi
}

# A UTC stamp for a key, $1 seconds from now (BSD and GNU date differ in how they take an epoch).
stamp() {
  local t=$(($(date +%s) + ${1:-0}))
  date -u -r "$t" +%Y%m%dT%H%M%SZ 2>/dev/null || date -u -d "@$t" +%Y%m%dT%H%M%SZ
}
# A stamped key that is free: two memories in the same second would otherwise overwrite one another.
free_key() { # free_key <prefix> <suffix>
  local existing i k
  existing=$(bd --readonly memories --json 2>/dev/null | jq -r 'keys[]' 2>/dev/null) || existing=""
  for i in 0 1 2 3 4 5 6 7 8 9 10 11 12 13 14 15 16 17 18 19; do
    k="$1$(stamp "$i")-$2"
    grep -qxF -- "$k" <<<"$existing" || { printf '%s' "$k"; return; }
  done
  printf '%s' "$k"
}
safe() { printf '%s' "$1" | tr -c 'A-Za-z0-9._-' '-'; }

# ---------------------------------------------------------------- forget
if [ "$cmd" = forget ]; then
  [ -n "$id" ] || die 1 "forget needs --id"
  [ -n "$reason" ] || die 1 "forget needs --reason"
  if [ "$backend" = ynm ]; then
    need ynm
    ynm forget --memory-id "$id" --reason "$reason" >/dev/null 2>"$errfile" || die 3 "ynm forget failed: $(head -c 300 "$errfile")"
  else
    need bd
    bd forget -- "$id" >/dev/null 2>"$errfile" || die 3 "bd forget failed: $(head -c 300 "$errfile")"
  fi
  jq -nc --arg id "$id" --arg b "$backend" '{forgotten: $id, backend: $b}'
  exit 0
fi

# ---------------------------------------------------------------- remember
if [ "$cmd" = remember ]; then
  [ -n "$actor" ] || die 1 "remember needs --actor"
  [ -n "$kind" ] || die 1 "remember needs --kind"
  valid_name "$actor" || die 1 "--actor must be a command name (lowercase letters, digits, . _ -)"
  [ "$havetext" = 1 ] || die 1 "remember needs --text"
  [ "$text" != - ] || text=$(cat)
  [ -n "$text" ] || die 1 "remember needs non-empty text"
  scope_args
  [ "$kind" != close-note ] || [ -n "$bead" ] || die 1 "close-note needs --bead <id>"
  if [ "$kind" = fact ]; then
    [ -n "$slug" ] || slug=$(printf '%s' "$text" | head -1 | tr 'A-Z' 'a-z' | tr -c 'a-z0-9' '-' | sed 's/--*/-/g; s/^-//; s/-$//' | cut -c1-40 | sed 's/-$//')
    [ -n "$slug" ] || die 1 "fact needs --slug"
    valid_name "$slug" || die 1 "--slug must be lowercase letters, digits, . _ -"
  fi

  if [ "$backend" = ynm ]; then
    need ynm
    ns="" subj="" tag="$kind" type=episodic level=distributed
    case "$kind" in
      identity) ns="seat/$seat" subj="seat:$seat" type=semantic ;;
      birth | handoff | kudos) ns="seat/$seat" subj="seat:$seat" ;;
      close-note) ns="seat/$seat" subj="$bead" type=reflective ;;
      note) ns="human/$human" subj="human:$human" tag=inbox; text="From $actor: $text" ;;
      fact) type=semantic; subj="${slug}" ;;
    esac
    data=$(jq -nc --arg k "$kind" --arg by "$actor" --arg bead "$bead" '{kind: $k, by: $by} + (if $bead == "" then {} else {bead: $bead} end)')
    args=(--type "$type" --level "$level" --subject "$subj" --tags "$tag" --data "$data" --json)
    [ -z "$ns" ] || args+=(--namespace "$ns")
    out=""
    if [ "$kind" = identity ]; then
      # Rewritten by superseding the identity already there, then pinned so it is always in front of the seat.
      old=$(ynm recall --namespace "$ns" --subject "$subj" --tags identity --limit 1 --json 2>/dev/null | jq -r '.[0].memoryId // empty' 2>/dev/null)
      if [ -n "$old" ]; then
        out=$(ynm supersede --memory-id "$old" --content "$text" --subject "$subj" --tags identity --data "$data" --json 2>"$errfile") ||
          die 3 "ynm supersede failed: $(head -c 300 "$errfile")"
      fi
    fi
    if [ -z "$out" ]; then
      out=$(ynm remember "${args[@]}" --content "$text" 2>"$errfile") || die 3 "ynm remember failed: $(head -c 300 "$errfile")"
    fi
    memid=$(jq -r '.memoryId // .id // empty' <<<"$out" 2>/dev/null)
    [ -n "$memid" ] || memid=$(grep -oE '[0-9A-Z]{26}' <<<"$out" | head -1)
    [ -n "$memid" ] || die 3 "ynm remember printed no memory id: $(head -c 300 <<<"$out")"
    if [ "$kind" = identity ]; then
      ynm pin "$memid" >/dev/null 2>"$errfile" || die 3 "ynm pin failed: $(head -c 300 "$errfile")"
    fi
  else
    need bd
    case "$kind" in
      identity | birth | handoff) key="seat/$seat/$kind" ;;
      kudos) key=$(free_key "seat/$seat/kudos/" "$(safe "$actor")") ;;
      close-note) key=$(free_key "seat/$seat/close-note/" "$(safe "$bead")") ;;
      note) key=$(free_key "human/$human/note/" "$(safe "$actor")") ;;
      fact) key="wheelhouse/$slug" ;;
    esac
    BEADS_ACTOR="$actor" bd remember --actor "$actor" --key "$key" -- "$text" >/dev/null 2>"$errfile" ||
      die 3 "bd remember failed: $(head -c 300 "$errfile")"
    memid="$key"
  fi
  jq -nc --arg id "$memid" --arg kind "$kind" --arg b "$backend" '{id: $id, kind: $kind, backend: $b}'
  exit 0
fi

# ---------------------------------------------------------------- recall
scope_args
[ "$shared" = 1 ] || [ -n "$seat$human" ] || die 1 "recall needs --seat, --human or --shared"
[[ "$limit" =~ ^[0-9]+$ ]] || die 1 "--limit must be a number"
if [ -n "$kind" ]; then
  if [ "$shared" = 1 ] && [ "$kind" != fact ]; then die 1 "--shared reads facts only"; fi
  if [ -n "$seat" ] && ! seat_kind "$kind"; then die 1 "$kind is not a seat's: use --human or --shared"; fi
  if [ -n "$human" ] && [ "$kind" != note ]; then die 1 "$kind is not a human's: use --seat or --shared"; fi
fi

# jq: ynm hits to the common shape.
ynm_shape='[ .[] | (.tags // []) as $t
  | (if ($t | index("inbox")) then "note"
     else ([$t[] | select(. == "identity" or . == "birth" or . == "handoff" or . == "kudos" or . == "close-note" or . == "fact")][0] // null) end) as $k
  | (.content // "") as $c
  | (if $k == "note" then ($c | capture("^From (?<by>[^:]+): (?<rest>.*)$"; "s") // null) else null end) as $n
  | {id: .memoryId, kind: $k,
     text: (if $n then $n.rest else $c end),
     at: .updatedAt,
     by: (.data.by // (if $n then $n.by else null end)),
     bead: (.data.bead // (if $k == "close-note" then .subject else null end))} ]'

if [ "$backend" = ynm ]; then
  need ynm
  args=(--limit 200 --json)
  case "$kind" in
    "") ;;
    note) args+=(--tags inbox) ;;
    *) args+=(--tags "$kind") ;;
  esac
  if [ -n "$seat" ]; then args+=(--namespace "seat/$seat")
  elif [ -n "$human" ]; then args+=(--namespace "human/$human")
  else [ -n "$kind" ] || args+=(--tags fact); args+=(--level distributed); fi
  out=$(ynm recall "${args[@]}" 2>"$errfile") || die 3 "ynm recall failed: $(head -c 300 "$errfile")"
  jq -e 'type == "array"' <<<"$out" >/dev/null 2>&1 || die 3 "ynm recall printed no readable list: $(head -c 300 <<<"$out")"
  # Each hit is kept only if its kind fits the scope (a shared fact search must not return seat memories).
  jq -c --argjson n "$limit" --arg scope "$([ "$shared" = 1 ] && echo shared || echo own)" \
    "$ynm_shape | map(select(.kind != null and (\$scope != \"shared\" or .kind == \"fact\"))) | sort_by(.at // \"\") | reverse | .[:\$n]" <<<"$out" ||
    die 3 "ynm recall output could not be read"
else
  need bd
  out=$(bd --readonly memories --json 2>"$errfile") || die 3 "bd memories failed: $(head -c 300 "$errfile")"
  if [ -n "$seat" ]; then prefix="seat/$seat/"; elif [ -n "$human" ]; then prefix="human/$human/"; else prefix="wheelhouse/"; fi
  jq -c --arg prefix "$prefix" --arg kind "$kind" --argjson n "$limit" '
    def stampiso: "\(.[0:4])-\(.[4:6])-\(.[6:8])T\(.[9:11]):\(.[11:13]):\(.[13:15])Z";
    if type != "object" then error("bd memories printed no memory map") else . end
    | to_entries
    | map(select(.key != "schema_version" and (.key | startswith($prefix)) and (.value | type == "string")))
    | map(
        (.key | ltrimstr($prefix)) as $rest
        | (if $prefix | startswith("wheelhouse/") then {kind: "fact", tail: ""}
           else ($rest | split("/")) as $p | {kind: $p[0], tail: ($p[1:] | join("/"))} end) as $k
        | ($k.tail | capture("^(?<st>[0-9]{8}T[0-9]{6}Z)-(?<who>.*)$")? // null) as $m
        | {id: .key, kind: $k.kind, text: .value,
           at: ($m | if . then .st | stampiso else null end),
           by: (if $k.kind == "kudos" or $k.kind == "note" then ($m.who // null)
                elif $k.kind == "fact" then null
                else ($prefix | ltrimstr("seat/") | rtrimstr("/")) end),
           bead: (if $k.kind == "close-note" then ($m.who // null) else null end)})
    | map(select($kind == "" or .kind == $kind))
    | sort_by(.at // "") | reverse | .[:$n]' <<<"$out" || die 3 "bd memories output could not be read"
fi
