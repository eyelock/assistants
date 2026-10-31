#!/usr/bin/env bash
# The humans' inbox: work and notes for the people who work with a Wheelhouse.
# Every name comes from the roster (skills/roster/assets/roster.json): its
# `humans` list, beside `seats`, holds the people, and exactly one of them is
# the default human (`"default": true`), the name for work that needs a human
# but no particular one.
#
#   assign    a bead for a human to do (a merge, a decision, a credential),
#             assigned to them, created as the seat that asked, optionally
#             blocking the bead it holds up, labelled with the repository it
#             touches. A merge or review needs --url and a repository.
#   note      an FYI for a human: a memory in ynm, namespace human/<command>,
#             tagged inbox, shown at the desk's wake until it is relayed.
#   register  add a person who names themselves at the desk to `humans`, with
#             their git email, so the desk knows them from then on.
#   show      the ready beads and notes for the human at the desk (matched by
#             git email, or $WHEELHOUSE_HUMAN_EMAIL) and for the default human.
#
# Run it from the Wheelhouse repository's root, or pass --dir.
# Output: JSON on stdout; diagnostics on stderr.
# Exit codes: 0 done, 1 bad args or refused, 2 not a Wheelhouse, 3 a tool it
# needs (jq, bd, ynm, git) is missing or failed. show exits 3 when bd or ynm
# failed, and still prints what it could read, with what failed in errors.
set -uo pipefail

usage() {
  cat <<'EOF'
Usage: inbox.sh assign --title <title> --from <seat> [--to default|<command>]
                       [--url <url>] [--blocks <bead>] [--repo <repo>]
                       [--description <text>]
                       [--kind merge|review|decision|credential|other]
       inbox.sh note --content <text> --from <seat> [--to default|<command>]
       inbox.sh register --name <Name> [--command <command>] [--pronouns <p>] [--email <email>]
       inbox.sh show [--email <email>]

Common: --dir <wheelhouse repo> (default: the current directory).

assign    Creates a bead assigned to a human (--to, default: the default human),
          as the seat that asked (--from, default: $BEADS_ACTOR). --url is kept
          as the bead's external_ref; a merge or review is refused without
          one. --kind says which it is; without --kind, a title with the word
          "merge" or "review" in it (any case, anywhere) is taken as one.
          --blocks makes the given bead wait on this one. --repo labels the
          bead repo:<repo>, the one repository it touches; without --repo it
          takes the repo: label of the --blocks bead. A merge or review must
          end up with one; other kinds go unlabelled when the work touches no
          repository.
note      Leaves an FYI in ynm, namespace human/<command>, tagged inbox.
register  Adds a person to the roster's humans: name, command (the name in
          lowercase; given or derived, a command is lowercase ASCII,
          [a-z0-9][a-z0-9-]*), pronouns (they/them unless given) and email
          (git config user.email unless given; matched ignoring case). Leaves
          the roster uncommitted.
show      Prints {you, unknown, humans: [{name, command, role: you|anyone,
          beads: [{id, title, askedBy, ref: {short, url}, unblocks}], notes:
          [{memoryId, content}]}], errors, empty, relay (what to do with it)}. The human at the desk is matched by --email,
          else $WHEELHOUSE_HUMAN_EMAIL, else git config user.email.
          If bd or ynm fails, that human's beads or notes are null, errors
          says what failed, empty is null (never true) and show exits 3,
          still printing what the other tool returned.
EOF
}

die() { echo "$2" >&2; exit "$1"; }

[ $# -gt 0 ] || { usage >&2; exit 1; }
cmd="$1"; shift
case "$cmd" in
  assign | note | register | show) ;;
  --help | -h) usage; exit 0 ;;
  *) echo "unknown command: $cmd" >&2; usage >&2; exit 1 ;;
esac

dir="."
title=""; from="${BEADS_ACTOR:-}"; to="default"; url=""; blocks=""; repo=""; description=""; kind=""
content=""; name=""; command=""; pronouns="they/them"; email=""
while [ $# -gt 0 ]; do
  case "$1" in
    --help | -h) usage; exit 0 ;;
    --dir | --title | --from | --to | --url | --blocks | --repo | --description | --kind | --content | --name | --command | --pronouns | --email)
      [ $# -ge 2 ] || { usage >&2; exit 1; }
      v="$2"
      case "$1" in
        --dir) dir="$v" ;; --title) title="$v" ;; --from) from="$v" ;; --to) to="$v" ;;
        --url) url="$v" ;; --blocks) blocks="$v" ;; --repo) repo="$v" ;; --description) description="$v" ;;
        --kind) kind="$v" ;; --content) content="$v" ;; --name) name="$v" ;;
        --command) command="$v" ;; --pronouns) pronouns="$v" ;; --email) email="$v" ;;
      esac
      shift 2 ;;
    *) echo "unknown argument: $1" >&2; usage >&2; exit 1 ;;
  esac
done

command -v jq >/dev/null 2>&1 || die 3 "jq is required"
roster="$dir/skills/roster/assets/roster.json"
[ -f "$roster" ] || die 2 "not a Wheelhouse (no $roster)"
cd "$dir" || exit 2
roster=skills/roster/assets/roster.json

# Beads' --json output is an array or object, or {"data": ...} with
# BD_JSON_ENVELOPE=1; (.data? // .) reads either.
need() { command -v "$1" >/dev/null 2>&1 || die 3 "$1 is required"; }

# The default human's command; there must be exactly one.
default_human() {
  local n
  n=$(jq '[(.humans // [])[] | select(.default == true)] | length' "$roster")
  [ "$n" = 1 ] || die 1 "the roster must have exactly one default human (\"default\": true in humans); it has $n"
  jq -r '[.humans[] | select(.default == true)][0].command' "$roster"
}

# Resolves --to (default, or a human's command) to a human in the roster.
resolve_to() {
  if [ "$1" = default ]; then default_human; return; fi
  jq -e --arg c "$1" '(.humans // []) | any(.command == $c)' "$roster" >/dev/null ||
    die 1 "$1 is not a human in the roster: use --to default, or one of: $(jq -r '[(.humans // [])[].command] | join(", ")' "$roster")"
  printf '%s\n' "$1"
}

# The seat that asked must be a seat in the roster.
check_from() {
  [ -n "$from" ] || die 1 "say which seat is asking: --from <seat>, or set BEADS_ACTOR"
  jq -e --arg c "$from" '.seats | any(.command == $c)' "$roster" >/dev/null ||
    die 1 "$from is not a seat in the roster"
}

case "$cmd" in
  assign)
    need bd
    [ -n "$title" ] || die 1 "assign needs --title"
    check_from
    human=$(resolve_to "$to") || exit $?
    case "$kind" in "" | merge | review | decision | credential | other) ;; *) die 1 "--kind must be merge, review, decision, credential or other" ;; esac
    # Without --kind, the first whole word "merge" or "review" in the title
    # (any case, anywhere: "Merge: widget #13", "Please review ...") makes it one.
    if [ -z "$kind" ]; then
      kind=$(tr '[:upper:]' '[:lower:]' <<<"$title" | grep -oE '(^|[^a-z0-9])(merge|review)([^a-z0-9]|$)' | head -1 | tr -cd 'a-z')
    fi
    if [ -z "$url" ] && { [ "$kind" = merge ] || [ "$kind" = review ]; }; then
      die 1 "a $kind needs --url: the pull request it is about, so the human can open it"
    fi
    # The repository: --repo (with or without its repo: prefix), else the
    # repo: label of the bead this one blocks. One name, never a list: bd
    # reads commas in --labels as more labels.
    repo="${repo#repo:}"
    if [ -n "$repo" ] && ! [[ "$repo" =~ ^[A-Za-z0-9][A-Za-z0-9._-]*$ ]]; then
      die 1 "$repo is not a repository name: one name, of letters, digits, '.', '_' and '-'"
    fi
    if [ -n "$blocks" ]; then
      out=$(bd show "$blocks" --json 2>/dev/null) || die 1 "no bead $blocks to block"
      [ -n "$repo" ] || repo=$(jq -r '(.data? // .) | if type == "array" then .[0] else . end
        | [(.labels // [])[] | select(startswith("repo:"))][0] // "" | ltrimstr("repo:")' <<<"$out" 2>/dev/null)
    fi
    if [ -z "$repo" ] && { [ "$kind" = merge ] || [ "$kind" = review ]; }; then
      die 1 "a $kind needs --repo: the repository its pull request is in (or --blocks a bead with a repo: label)"
    fi
    # --title, never positional, so a title starting with "-" is not a flag.
    args=(create --title "$title" --actor "$from" --assignee "$human" --labels inbox)
    [ -n "$kind" ] && args+=(--labels "inbox:$kind")
    [ -n "$repo" ] && args+=(--labels "repo:$repo")
    [ -n "$description" ] && args+=(--description "$description")
    [ -n "$url" ] && args+=(--external-ref "$url")
    [ -n "$blocks" ] && args+=(--deps "blocks:$blocks")
    out=$(bd "${args[@]}" --json 2>&1) || die 3 "bd create failed: $out"
    id=$(jq -r '(.data? // .) | if type == "array" then .[0] else . end | .id' <<<"$out")
    jq -n --arg id "$id" --arg to "$human" --arg from "$from" --arg url "$url" --arg blocks "$blocks" --arg kind "$kind" --arg repo "$repo" \
      '{id: $id, to: $to, askedBy: $from, kind: (if $kind == "" then null else $kind end),
        repo: (if $repo == "" then null else $repo end),
        url: (if $url == "" then null else $url end), blocks: (if $blocks == "" then null else $blocks end)}'
    ;;

  note)
    need ynm
    [ -n "$content" ] || die 1 "note needs --content"
    check_from
    human=$(resolve_to "$to") || exit $?
    out=$(ynm remember --type episodic --level distributed --namespace "human/$human" \
      --subject "human:$human" --tags inbox --content "From $from: $content" --json 2>&1) ||
      die 3 "ynm remember failed: $out"
    memid=$(jq -r '.memoryId // .id // empty' <<<"$out" 2>/dev/null)
    [ -n "$memid" ] || memid=$(grep -oE '[0-9A-Z]{26}' <<<"$out" | head -1)
    jq -n --arg to "$human" --arg from "$from" --arg id "$memid" \
      '{to: $to, from: $from, namespace: "human/\($to)", memoryId: (if $id == "" then null else $id end)}'
    ;;

  register)
    [ -n "$name" ] || die 1 "register needs --name"
    [ -n "$command" ] || command=$(printf '%s' "$name" | tr '[:upper:]' '[:lower:]' | tr -cd 'a-z0-9-')
    [ -n "$command" ] || die 1 "can't make a command from $name: pass --command"
    # The roster's rule: lowercase ASCII, starting with a letter or digit. The
    # command names an ynm namespace (human/<command>), so nothing else gets in.
    [[ "$command" =~ ^[a-z0-9][a-z0-9-]*$ ]] ||
      die 1 "$command is not a command: use lowercase ASCII letters, digits and '-', starting with a letter or digit (pass --command)"
    if [ -z "$email" ]; then
      need git
      email=$(git config user.email 2>/dev/null || true)
    fi
    [ -n "$email" ] || die 1 "no email: pass --email, or set git config user.email"
    if jq -e --arg c "$command" '.seats | any(.command == $c)' "$roster" >/dev/null; then
      die 1 "$command is a seat, not a human: pass another --command"
    fi
    existing=$(jq -c --arg c "$command" '[(.humans // [])[] | select(.command == $c)][0] // empty' "$roster")
    if [ -n "$existing" ]; then
      [ "$(jq -r '.default // false' <<<"$existing")" != true ] || die 1 "$command is the default human: a person registers under their own name"
      jq -e --arg e "$email" '(.email // "" | ascii_downcase) == ($e | ascii_downcase)' <<<"$existing" >/dev/null || die 1 "$command is already a human in the roster, with another email"
      jq -c '{registered: false, already: true, human: .}' <<<"$existing"
      exit 0
    fi
    other=$(jq -r --arg e "$email" '[(.humans // [])[] | select(.email != null and (.email | ascii_downcase) == ($e | ascii_downcase))][0].command // empty' "$roster")
    [ -z "$other" ] || die 1 "$email is already registered, as $other"
    human=$(jq -nc --arg n "$name" --arg c "$command" --arg e "$email" --arg p "$pronouns" \
      '{name: $n, command: $c, email: $e, pronouns: $p}')
    if ! jq --argjson h "$human" '.humans = ((.humans // []) + [$h])' "$roster" > "$roster.new" || ! mv "$roster.new" "$roster"; then
      die 3 "could not write $roster"
    fi
    jq -c '{registered: true, already: false, human: ., roster: "skills/roster/assets/roster.json", committed: false}' <<<"$human"
    ;;

  show)
    need bd; need ynm
    if [ -z "$email" ]; then email="${WHEELHOUSE_HUMAN_EMAIL:-}"; fi
    if [ -z "$email" ] && command -v git >/dev/null 2>&1; then email=$(git config user.email 2>/dev/null || true); fi
    dflt=$(default_human) || exit $?
    you=""
    [ -n "$email" ] && you=$(jq -r --arg e "$email" '[(.humans // [])[] | select(.default != true and .email != null and (.email | ascii_downcase) == ($e | ascii_downcase))][0].command // empty' "$roster")

    # A web URL's short form, for a Markdown link: <repo> #<n> for a GitHub pull
    # request or issue, <repo> run <id> for a CI run, <repo> <sha> for a commit.
    short='def short: if . == null or . == "" then null
      else (capture("^https?://github\\.com/[^/]+/(?<repo>[^/]+)/(?<kind>pull|issues|actions/runs|commit)/(?<n>[0-9A-Za-z]+)") // null) as $m
      | if $m == null then null
        elif $m.kind == "actions/runs" then "\($m.repo) run \($m.n)"
        elif $m.kind == "commit" then "\($m.repo) \($m.n[0:7])"
        else "\($m.repo) #\($m.n)" end end;'
    # A read that fails is never an empty list: its beads or notes are null,
    # and what failed goes in errors, so nobody is told nothing is waiting
    # when nobody could look. What the other tool returned is still shown.
    # Run each read without a temp file (a sandboxed seat may not write one);
    # on failure, run it again for the first line of what it said.
    errors='[]'
    failed() { errors=$(jq -c --arg e "$1" 'if index($e) then . else . + [$e] end' <<<"$errors"); }
    inbox_of() {
      local c="$1" role="$2" out beads notes msg
      if out=$(bd ready --assignee "$c" --json 2>/dev/null) && beads=$(jq -c "$short"'
        (.data? // .) | map(select(.issue_type != "epic")) | sort_by(.priority)
        | map({id, title, askedBy: (.created_by // null), priority,
               ref: (if (.external_ref // "") == "" then null else {short: (.external_ref | short), url: .external_ref} end),
               unblocks: (.dependent_count // 0)})' <<<"$out" 2>/dev/null) && [ -n "$beads" ]; then :; else
        msg=$(bd ready --assignee "$c" --json 2>&1 | head -1)
        failed "bd ready failed: ${msg:-no readable output}"
        beads=null
      fi
      if out=$(ynm recall --namespace "human/$c" --subject "human:$c" --tags inbox --limit 20 --json 2>/dev/null) &&
        notes=$(jq -c --arg ns "human/$c" 'map(select((.namespace // $ns) == $ns and ((.tags // ["inbox"]) | index("inbox")))) | map({memoryId, content})' <<<"$out" 2>/dev/null) &&
        [ -n "$notes" ]; then :; else
        msg=$(ynm recall --namespace "human/$c" --subject "human:$c" --tags inbox --limit 20 --json 2>&1 | head -1)
        failed "ynm recall failed: ${msg:-no readable output}"
        notes=null
      fi
      humans=$(jq -c --arg c "$c" --arg role "$role" --argjson beads "$beads" --argjson notes "$notes" --argjson hs "$humans" \
        '$hs + [[.humans[] | select(.command == $c)][0] | {name, command, role: $role, beads: $beads, notes: $notes}]' "$roster")
    }
    humans='[]'
    [ -n "$you" ] && inbox_of "$you" you
    inbox_of "$dflt" anyone
    yours='null'
    [ -n "$you" ] && yours=$(jq -c --arg c "$you" '[.humans[] | select(.command == $c)][0] | {name, command}' "$roster")
    # One line, so a reader that keeps only the head of the output keeps it all.
    # empty is true only when everything was read and nothing waits; with
    # errors it is null, never "nothing waiting".
    jq -nc --argjson you "$yours" --argjson humans "$humans" --arg email "$email" --argjson errors "$errors" \
      '{you: $you, unknown: ($you == null), email: (if $email == "" then null else $email end), humans: $humans,
        errors: $errors,
        empty: (if ($errors | length) > 0 then null
                else ($humans | all((.beads | length) == 0 and (.notes | length) == 0)) end),
        relay: "Relay this to the human first. Retire each note you relay, in the same turn: ynm forget --memory-id <its memoryId> --reason relayed. Leave the beads to the human."}'
    if [ "$errors" != '[]' ]; then
      jq -r '.[]' <<<"$errors" >&2
      exit 3
    fi
    ;;
esac
