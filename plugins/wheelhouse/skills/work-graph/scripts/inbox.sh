#!/usr/bin/env bash
# The humans' inbox: work and notes for the people who work with a Wheelhouse.
# The roster (skills/roster/assets/roster.json) holds one human: the default
# human (`"default": true` in `humans`), the name for work that needs a human
# but no particular one. Any other human is per session and is never written
# down: a person names themselves at the desk, and their command is their name
# in lowercase. Nothing here stores a person, an email or a username, and
# nothing here writes to the repository.
#
#   assign    a bead for a human to do (a merge, a decision, a credential) or
#             read (a report),
#             assigned to them, created as the seat that asked, optionally
#             blocking the bead it holds up, labelled with the repository it
#             touches. A merge or review needs --url and a repository.
#   note      an FYI for a human: a memory in ynm, namespace human/<command>,
#             tagged inbox, shown at the desk's wake until it is relayed.
#   close     closes a human's inbox bead with a reason, once the human has done
#             it and the work is verified (alias: done). Only the desk runs it,
#             and only on an inbox bead assigned to a human.
#   show      the ready beads and notes for the default human and, when
#             --name says who is at the desk for this session, for them too.
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
                       [--description <text>] [--priority 0-4]
                       [--kind merge|review|decision|credential|report|other]
       inbox.sh note --content <text> --from <seat> [--to default|<command>]
       inbox.sh close <bead> --reason <text> --from <desk seat>
       inbox.sh show [--name <Name>]

Common: --dir <wheelhouse repo> (default: the current directory).

assign    Creates a bead assigned to a human (--to: default, the default human,
          or any human's command, their name in lowercase),
          as the seat that asked (--from, default: $BEADS_ACTOR). --url is kept
          as the bead's external_ref; a merge or review is refused without
          one. A merge whose pull request is still a draft is refused when gh
          can tell (with gh missing or failing, it warns and carries on).
          --kind says which it is; without --kind, a title with the word
          "merge" or "review" in it (any case, anywhere) is taken as one.
          --blocks makes the given bead wait on this one. --repo labels the
          bead repo:<repo>, the one repository it touches; without --repo it
          takes the repo: label of the --blocks bead. A merge or review must
          end up with one; other kinds go unlabelled when the work touches no
          repository. --kind report is something to read, such as a weekly
          report: it needs no --url or repository, gets priority 3 unless
          --priority says otherwise, and show lists it after the rest.
          Every kind is labelled inbox:<kind>. --priority sets any bead's
          priority (0 highest, 4 lowest; bd's default, 2, unless given).
note      Leaves an FYI in ynm, namespace human/<command>, tagged inbox.
close     (alias: done) Closes a human's bead (<bead>, or --id) with a reason
          (--reason, or --note), as the seat recording it (--from, default:
          $BEADS_ACTOR), once the human has done it or told you it is done and
          the work is verified. Only the desk runs it: --from must be a seat in
          the desk group. The bead must be an inbox bead (labelled inbox)
          assigned to a human, never a seat's work. bd refuses a plain close of
          a bead like this, so close forces it: the one forced close a seat
          makes of a bead it does not hold, which is why it is limited to inbox
          beads. Prints {id, closedBy, note}.
show      Prints {you, humans: [{name, command,
          role: you|anyone, beads: [{id, title, kind, askedBy, priority,
          ref: {short, url}, unblocks}] (reports last, then by priority), notes: [{memoryId, content}]}],
          errors, empty, relay (what to do with it)}. --name is the human at
          the desk for this session ("it's me, <name>"): their inbox is the
          beads assigned to their command (the name in lowercase ASCII, [a-z0-9][a-z0-9-]*)
          and the ynm notes in human/<command>, with no roster entry. you is
          {name, command}, or null with no --name, when the desk treats the
          human as the default human. Nothing is stored or written.
          If bd or ynm fails, that human's beads or notes are null, errors
          says what failed, empty is null (never true) and show exits 3,
          still printing what the other tool returned.
EOF
}

die() { echo "$2" >&2; exit "$1"; }

[ $# -gt 0 ] || { usage >&2; exit 1; }
cmd="$1"; shift
case "$cmd" in
  assign | note | show | close | done) ;;
  --help | -h) usage; exit 0 ;;
  *) echo "unknown command: $cmd" >&2; usage >&2; exit 1 ;;
esac

dir="."
title=""; from="${BEADS_ACTOR:-}"; to="default"; url=""; blocks=""; repo=""; description=""; kind=""; priority=""
content=""; name=""; id=""; note=""
while [ $# -gt 0 ]; do
  case "$1" in
    --help | -h) usage; exit 0 ;;
    --dir | --title | --from | --to | --url | --blocks | --repo | --priority | --description | --kind | --content | --name | --id | --note | --reason)
      [ $# -ge 2 ] || { usage >&2; exit 1; }
      v="$2"
      case "$1" in
        --dir) dir="$v" ;; --title) title="$v" ;; --from) from="$v" ;; --to) to="$v" ;;
        --url) url="$v" ;; --blocks) blocks="$v" ;; --repo) repo="$v" ;; --priority) priority="$v" ;; --description) description="$v" ;;
        --kind) kind="$v" ;; --content) content="$v" ;; --name) name="$v" ;; --id) id="$v" ;; --note | --reason) note="$v" ;;
      esac
      shift 2 ;;
    -*) echo "unknown argument: $1" >&2; usage >&2; exit 1 ;;
    *)
      # close takes the bead bare: inbox.sh close <bead> --reason <text>
      if { [ "$cmd" = close ] || [ "$cmd" = done ]; } && [ -z "$id" ]; then id="$1"; shift
      else echo "unknown argument: $1" >&2; usage >&2; exit 1; fi ;;
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

# A human's command: lowercase ASCII, starting with a letter or digit. It names
# an ynm namespace (human/<command>), so nothing else gets in.
valid_command() { [[ "$1" =~ ^[a-z0-9][a-z0-9-]*$ ]]; }

# A name's command: the name in lowercase ASCII, spaces and other characters dropped.
command_of() { printf '%s' "$1" | tr '[:upper:]' '[:lower:]' | tr -cd 'a-z0-9-'; }

# Resolves --to (default, or a human's command) to a command. A human needs no
# roster entry, but is never a seat.
resolve_to() {
  if [ "$1" = default ]; then default_human; return; fi
  valid_command "$1" || die 1 "$1 is not a human's command: use --to default, or a name in lowercase ASCII letters, digits and '-', starting with a letter or digit"
  if jq -e --arg c "$1" '.seats | any(.command == $c)' "$roster" >/dev/null; then
    die 1 "$1 is a seat, not a human: use --to default, or a human's command"
  fi
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
    case "$kind" in "" | merge | review | decision | credential | report | other) ;; *) die 1 "--kind must be merge, review, decision, credential, report or other" ;; esac
    priority="${priority#[Pp]}"
    case "$priority" in "" | 0 | 1 | 2 | 3 | 4) ;; *) die 1 "--priority must be 0 to 4 (0 highest)" ;; esac
    # A report is read, not done: it sorts below the work a human has to do.
    [ "$kind" != report ] || [ -n "$priority" ] || priority=3
    # Without --kind, the first whole word "merge" or "review" in the title
    # (any case, anywhere: "Merge: widget #13", "Please review ...") makes it one.
    if [ -z "$kind" ]; then
      kind=$(tr '[:upper:]' '[:lower:]' <<<"$title" | grep -oE '(^|[^a-z0-9])(merge|review)([^a-z0-9]|$)' | head -1 | tr -cd 'a-z')
    fi
    if [ -z "$url" ] && { [ "$kind" = merge ] || [ "$kind" = review ]; }; then
      die 1 "a $kind needs --url: the pull request it is about, so the human can open it"
    fi
    # A merge is asked of a human only once its pull request has left draft.
    # With gh, a draft is refused; without gh, or if gh can't tell, warn and go on.
    if [ "$kind" = merge ]; then
      if ! command -v gh >/dev/null 2>&1; then
        echo "warning: gh is not installed, so I can't check $url is out of draft" >&2
      elif draft=$(gh pr view "$url" --json isDraft --jq .isDraft 2>/dev/null) && [ "$draft" = true ]; then
        die 1 "$url is still a draft: ask a human to merge it only once it has left draft (the review seat takes it out of draft when satisfied)"
      elif [ "$draft" != false ]; then
        echo "warning: couldn't ask gh whether $url is a draft; carrying on" >&2
      fi
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
    [ -n "$priority" ] && args+=(--priority "$priority")
    [ -n "$url" ] && args+=(--external-ref "$url")
    [ -n "$blocks" ] && args+=(--deps "blocks:$blocks")
    out=$(bd "${args[@]}" --json 2>&1) || die 3 "bd create failed: $out"
    id=$(jq -r '(.data? // .) | if type == "array" then .[0] else . end | .id' <<<"$out")
    jq -n --arg id "$id" --arg to "$human" --arg from "$from" --arg url "$url" --arg blocks "$blocks" --arg kind "$kind" --arg repo "$repo" --arg priority "$priority" \
      '{id: $id, to: $to, askedBy: $from, kind: (if $kind == "" then null else $kind end),
        priority: (if $priority == "" then null else ($priority | tonumber) end),
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

  close | done)
    need bd
    [ -n "$id" ] || die 1 "close needs the bead to close: inbox.sh close <bead> --reason <text>"
    [ -n "$note" ] || die 1 "close needs --reason: what the human did, for the close reason"
    check_from
    jq -e --arg c "$from" '.seats | any(.command == $c and .group == "desk")' "$roster" >/dev/null ||
      die 1 "$from is not the desk: only the desk closes a human's bead (hand it to the desk)"
    out=$(bd show "$id" --json 2>/dev/null) || die 1 "no bead $id"
    bead=$(jq -c '(.data? // .) | if type == "array" then .[0] else . end' <<<"$out" 2>/dev/null)
    [ -n "$bead" ] && [ "$bead" != null ] || die 1 "no bead $id"
    jq -e '(.labels // []) | index("inbox")' <<<"$bead" >/dev/null ||
      die 1 "$id is not an inbox bead (no inbox label): close it with bd close, not through the inbox"
    owner=$(jq -r '.assignee // ""' <<<"$bead")
    if [ -z "$owner" ] || jq -e --arg c "$owner" '.seats | any(.command == $c)' "$roster" >/dev/null; then
      die 1 "$id is not assigned to a human (assignee: ${owner:-none}): close it with bd close"
    fi
    status=$(jq -r '.status // ""' <<<"$bead")
    [ "$status" != closed ] || die 1 "$id is already closed"
    res=$(bd close "$id" --reason "$note" --force --actor "$from" 2>&1) || die 3 "bd close failed: $res"
    jq -n --arg id "$id" --arg from "$from" --arg note "$note" '{id: $id, closedBy: $from, note: $note}'
    ;;

  show)
    need bd; need ynm
    dflt=$(default_human) || exit $?
    you=""
    if [ -n "$name" ]; then
      you=$(command_of "$name")
      valid_command "$you" || die 1 "can't make a command from $name: it needs a letter or digit in it"
      if jq -e --arg c "$you" '.seats | any(.command == $c)' "$roster" >/dev/null; then
        die 1 "$you is a seat, not a human: name yourself with your own name"
      fi
      # The default human at the desk is the default human's inbox, shown once.
      [ "$you" != "$dflt" ] || { you=""; name=""; }
    fi

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
      local c="$1" role="$2" n="$3" out beads notes msg
      if out=$(bd ready --assignee "$c" --json 2>/dev/null) && beads=$(jq -c "$short"'
        (.data? // .) | map(select(.issue_type != "epic"))
        | map(. + {kind: ([(.labels // [])[] | select(startswith("inbox:")) | ltrimstr("inbox:")][0] // null)})
        | sort_by([(.kind == "report"), .priority])
        | map({id, title, kind, askedBy: (.created_by // null), priority,
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
      humans=$(jq -nc --arg n "$n" --arg c "$c" --arg role "$role" --argjson beads "$beads" --argjson notes "$notes" --argjson hs "$humans" \
        '$hs + [{name: $n, command: $c, role: $role, beads: $beads, notes: $notes}]')
    }
    humans='[]'
    [ -n "$you" ] && inbox_of "$you" you "$name"
    inbox_of "$dflt" anyone "$(jq -r --arg c "$dflt" '[.humans[] | select(.command == $c)][0].name // $c' "$roster")"
    yours='null'
    [ -n "$you" ] && yours=$(jq -nc --arg n "$name" --arg c "$you" '{name: $n, command: $c}')
    # One line, so a reader that keeps only the head of the output keeps it all.
    # empty is true only when everything was read and nothing waits; with
    # errors it is null, never "nothing waiting".
    jq -nc --argjson you "$yours" --argjson humans "$humans" --argjson errors "$errors" \
      '{you: $you, humans: $humans,
        errors: $errors,
        empty: (if ($errors | length) > 0 then null
                else ($humans | all((.beads | length) == 0 and (.notes | length) == 0)) end),
        relay: ("Relay this to the human first. Retire each note you relay, in the same turn: ynm forget --memory-id <its memoryId> --reason relayed. Leave the beads to the human."
                + (if $you == null then " With no name given, this is the default human\u0027s inbox: always end by telling the human they can name themselves for this session (\"it\u0027s me, <name>\") to see their own; nothing is saved." else "" end))}'
    if [ "$errors" != '[]' ]; then
      jq -r '.[]' <<<"$errors" >&2
      exit 3
    fi
    ;;
esac
