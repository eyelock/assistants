#!/usr/bin/env bash
# Lists the docs a change may have made wrong, as a starting point for the
# docs-sync skill. Read-only: it runs git and grep over tracked files, and
# changes nothing.
#
# From the diff against --base (default: where HEAD left the default branch),
# with uncommitted changes included, it collects the names the change touched:
# command-line flags, environment variables, exported Go and TypeScript names,
# Cobra commands and make targets. Each is added (only on + lines), removed
# (only on - lines) or changed (both), and still in the code or gone.
# Then it searches every tracked doc for them: Markdown and text files, skills,
# AGENTS.md and CLAUDE.md, and help text in code (Go under cmd/, files with
# Cobra's Short:/Long: or a CLI's .description()). Each doc that mentions one
# is listed with the lines, and with any caveat lines ("known issue",
# "workaround", "not yet supported") that may describe a defect since fixed.
#
# It reads only what an allow-list of extensions names: source code, build
# files and docs, all tracked by git. Anything else, secrets files included,
# is never opened. It skips node_modules, vendor, dist, build and history
# (CHANGELOG.md, .changeset/), which records the past on purpose.
#
# Output: JSON on stdout, {base, files: {code, docs}, terms: [{term, kind,
# status, inCode}], docs: [{path, kind, changed, hits: [{line, term, text}],
# caveats: [{line, text}]}]}. Diagnostics on stderr.
# Exit codes: 0 done, 1 bad args, 2 not a git repository, 3 git or jq missing.
set -uo pipefail

usage() {
  cat <<'EOF'
Usage: doc-candidates.sh [--base <ref>] [--dir <repository>] [--max-terms <n>]

Lists the docs that mention what the change since --base touched. --base
defaults to the merge base of HEAD and the default branch (origin/HEAD, else
develop, else main, else master).
EOF
}

die() { echo "$2" >&2; exit "$1"; }

dir="."; base=""; max=150
while [ $# -gt 0 ]; do
  case "$1" in
    --help | -h) usage; exit 0 ;;
    --base | --dir | --max-terms)
      [ $# -ge 2 ] || { usage >&2; exit 1; }
      case "$1" in --base) base="$2" ;; --dir) dir="$2" ;; --max-terms) max="$2" ;; esac
      shift 2 ;;
    *) echo "unknown argument: $1" >&2; usage >&2; exit 1 ;;
  esac
done
[[ "$max" =~ ^[1-9][0-9]*$ ]] || die 1 "--max-terms must be a positive number"
for t in git jq; do command -v "$t" >/dev/null 2>&1 || die 3 "$t is required"; done
cd "$dir" 2>/dev/null || die 2 "no folder $dir"
git rev-parse --git-dir >/dev/null 2>&1 || die 2 "not a git repository: $dir"

if [ -z "$base" ]; then
  for b in origin/HEAD origin/develop develop origin/main main origin/master master; do
    if git rev-parse --verify -q "$b" >/dev/null; then base=$(git merge-base HEAD "$b") && break; fi
  done
  [ -n "$base" ] || die 1 "no default branch found: pass --base <ref>"
fi
git rev-parse --verify -q "$base" >/dev/null || die 1 "no such ref: $base"

# Paths it never reads.
skip() {
  case "$1" in
    node_modules/* | */node_modules/* | vendor/* | */vendor/* | dist/* | build/* | \
      CHANGELOG.md | */CHANGELOG.md | .changeset/*) return 0 ;;
  esac
  return 1
}

# What kind of doc a path is, or nothing for code.
doc_kind() {
  case "$1" in
    AGENTS.md | */AGENTS.md | CLAUDE.md | */CLAUDE.md) echo agents ;;
    */SKILL.md | skills/*.md | */skills/*.md) echo skill ;;
    *tutorial*.md | *tutorial*/*.md | *tutorials/*.md) echo tutorial ;;
    *reference*.md | */reference/*.md) echo reference ;;
    README.md | */README.md) echo readme ;;
    *.md | *.mdx | *.txt | *.rst | *.adoc) echo doc ;;
  esac
}

# Help text in code: Go commands under cmd/, Cobra's Short:/Long:, a CLI's
# .description() or usage strings.
help_files() {
  git ls-files -- 'cmd/*.go' 'cmd/**/*.go' 2>/dev/null
  git grep -l -E 'Short:|Long:|\.description\(|[Uu]sage:' -- '*.go' '*.ts' '*.js' '*.py' '*.sh' 2>/dev/null
}

# The code it reads, by extension: nothing else is diffed or searched.
code=('*.go' '*.ts' '*.tsx' '*.js' '*.jsx' '*.mjs' '*.cjs' '*.py' '*.rb' '*.rs' '*.java' '*.kt' '*.swift'
  '*.sh' '*.bash' 'Makefile' '*.mk' 'package.json' '*.yaml' '*.yml' '*.toml')

diff=$(git diff --unified=0 --no-color "$base" -- "${code[@]}" 2>/dev/null) ||
  die 2 "git diff against $base failed"

# Changed lines, + and - kept apart; diff headers dropped.
added=$(grep -E '^\+' <<<"$diff" | grep -vE '^\+\+\+ ')
removed=$(grep -E '^-' <<<"$diff" | grep -vE '^--- ')

# One term per line, as "kind<TAB>term", from changed lines on stdin.
extract() {
  local lines
  lines=$(cat)
  grep -oE -- '--[a-z][a-z0-9-]{2,}' <<<"$lines" | sed 's/^/flag\t/'
  sed -nE 's/.*Flags\(\)\.[A-Za-z]+\("([a-z][a-z0-9-]{2,})".*/flag\t--\1/p' <<<"$lines"
  grep -oE '\b[A-Z][A-Z0-9]*_[A-Z0-9_]{2,}\b' <<<"$lines" | sed 's/^/env\t/'
  sed -nE 's/^[+-]func (\([^)]*\) )?([A-Z][A-Za-z0-9_]*).*/go\t\2/p; s/^[+-]type ([A-Z][A-Za-z0-9_]*).*/go\t\1/p' <<<"$lines"
  sed -nE 's/^[+-]export (default )?(async )?(function|const|class|interface|type|enum) ([A-Za-z_][A-Za-z0-9_]*).*/ts\t\4/p' <<<"$lines"
  sed -nE 's/^[+-][[:space:]]*Use:[[:space:]]*"([a-z][a-z0-9-]*).*/command\t\1/p' <<<"$lines"
}
make_targets() {
  git diff --unified=0 --no-color "$base" -- 'Makefile' '*/Makefile' '*.mk' 2>/dev/null |
    sed -nE "s/^$1([a-z][a-z0-9_-]*):.*/make\t\1/p"
}

plus=$( { extract <<<"$added"; make_targets '\+'; } | sort -u)
minus=$( { extract <<<"$removed"; make_targets '-'; } | sort -u)
all=$(printf '%s\n%s\n' "$plus" "$minus" | grep -v '^$' | sort -u | head -n "$max")

files=$(git diff --name-only "$base" -- "${code[@]}" '*.md' '*.mdx' '*.txt' '*.rst' '*.adoc' 2>/dev/null)
code_files=()
doc_changed=()
while IFS= read -r f; do
  [ -n "$f" ] || continue
  skip "$f" && continue
  if [ -n "$(doc_kind "$f")" ]; then doc_changed+=("$f"); else code_files+=("$f"); fi
done <<<"$files"

terms='[]'
while IFS=$'\t' read -r kind term; do
  [ -n "${term:-}" ] || continue
  inp=false; inm=false; incode=false
  grep -qxF "$kind	$term" <<<"$plus" && inp=true
  grep -qxF "$kind	$term" <<<"$minus" && inm=true
  if git grep -qwF -- "$term" -- "${code[@]}" 2>/dev/null; then incode=true; fi
  status=changed
  [ "$inp" = true ] && [ "$inm" = false ] && status=added
  [ "$inp" = false ] && [ "$inm" = true ] && status=removed
  terms=$(jq -c --arg t "$term" --arg k "$kind" --arg s "$status" --argjson c "$incode" \
    '. + [{term: $t, kind: $k, status: $s, inCode: $c}]' <<<"$terms")
done <<<"$all"

# Every tracked doc, and help text in code.
docs=()
while IFS= read -r f; do
  [ -n "$f" ] && ! skip "$f" && [ -n "$(doc_kind "$f")" ] && docs+=("$f")
done < <(git ls-files -- '*.md' '*.mdx' '*.txt' '*.rst' '*.adoc')
helps=()
while IFS= read -r f; do
  [ -n "$f" ] && ! skip "$f" && helps+=("$f")
done < <(help_files | sort -u)

caveat='known (issue|bug|limitation)|workaround|not (yet )?supported|does(n.t| not) (yet )?(work|support)|is broken|until .* (is )?fixed|bug in|TODO|FIXME'

found='[]'
scan() {
  local f="$1" kind="$2" hits='[]' line text t
  while IFS=$'\t' read -r _ t; do
    [ -n "${t:-}" ] || continue
    while IFS=: read -r line text; do
      [ -n "${line:-}" ] || continue
      hits=$(jq -c --argjson l "$line" --arg t "$t" --arg x "${text:0:240}" '. + [{line: $l, term: $t, text: $x}]' <<<"$hits")
    done < <(grep -nwF -- "$t" "$f" 2>/dev/null)
  done <<<"$all"
  [ "$hits" != '[]' ] || return 0
  local cav
  cav=$(grep -niE "$caveat" "$f" 2>/dev/null | head -20 |
    jq -R -c 'capture("^(?<line>[0-9]+):(?<text>.*)$") | {line: (.line | tonumber), text: .text[0:240]}' | jq -s -c .)
  local changed=false
  printf '%s\n' "${doc_changed[@]:-}" "${code_files[@]:-}" | grep -qxF -- "$f" && changed=true
  found=$(jq -c --arg p "$f" --arg k "$kind" --argjson c "$changed" --argjson h "$hits" --argjson v "${cav:-[]}" \
    '. + [{path: $p, kind: $k, changed: $c, hits: $h, caveats: $v}]' <<<"$found")
}
if [ -n "$all" ]; then
  for f in "${docs[@]:-}"; do [ -n "$f" ] && scan "$f" "$(doc_kind "$f")"; done
  for f in "${helps[@]:-}"; do [ -n "$f" ] && scan "$f" help; done
fi

jq -n --arg base "$base" --argjson terms "$terms" --argjson docs "$found" \
  --argjson code "$(printf '%s\n' "${code_files[@]:-}" | jq -R -s -c 'split("\n") | map(select(. != ""))')" \
  --argjson changed "$(printf '%s\n' "${doc_changed[@]:-}" | jq -R -s -c 'split("\n") | map(select(. != ""))')" \
  '{base: $base, files: {code: $code, docs: $changed}, terms: $terms, docs: $docs}'
