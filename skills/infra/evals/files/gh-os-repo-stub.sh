#!/usr/bin/env bash
# A gh for the gh-os-repo sandbox. gh-os-repo-setup.sh installs it as
# .eval/bin/gh, with @LOG@ replaced by the stub log. It answers like GitHub for
# acme/widget, a public repo that eval-user administers: it still has classic
# branch protection on main (requiring Build and Test) and no rulesets. Every
# call is logged, with any request body sent on stdin (--input -) or in a file
# (--input <file>). Writes print what GitHub returns, and settings, rulesets and
# classic protection keep their state in .eval/, so a later read sees them.
# Exit codes: 0 success, 1 a failed gh command.
set -uo pipefail

log="@LOG@"
repo="acme/widget"

{
  printf 'gh'
  printf ' %q' "$@"
  printf '\n'
} >>"$log"

has() {
  local want="$1"
  shift
  for a in "$@"; do [[ "$a" == "$want" || "$a" == "$want="* ]] && return 0; done
  return 1
}

opt() {
  local want="$1"
  shift
  while (($#)); do
    case "$1" in
      "$want") echo "${2:-}"; return ;;
      "$want="*) echo "${1#*=}"; return ;;
    esac
    shift
  done
}

out() {
  local filter
  filter="$(opt --jq "$@")"
  [[ -z "$filter" ]] && filter="$(opt -q "$@")"
  if [[ -n "$filter" ]]; then jq -r "$filter"; else jq .; fi
}

input="$(opt --input "$@")"
if [[ -n "$input" ]]; then
  if [[ "$input" == - ]]; then body="$(cat)"; else body="$(cat "$input" 2>/dev/null)"; fi
  printf '  request body:\n%s\n' "$(sed 's/^/    /' <<<"$body")" >>"$log"
fi

method="GET"
m="$(opt -X "$@")"
[[ -z "$m" ]] && m="$(opt --method "$@")"
[[ -n "$m" ]] && method="$(tr '[:lower:]' '[:upper:]' <<<"$m")"
# gh api switches to POST when fields are given without -X.
if [[ -z "$m" ]] && { has -f "$@" || has -F "$@" || has --field "$@" || has --raw-field "$@" || [[ -n "$input" ]]; }; then
  method=POST
fi

repo_json='{"id": 7301, "name": "widget", "full_name": "acme/widget", "private": false, "visibility": "public",
  "description": "Sizes widgets", "default_branch": "main", "has_issues": true, "has_discussions": false,
  "has_wiki": true, "has_projects": true, "allow_squash_merge": true, "allow_merge_commit": true,
  "allow_rebase_merge": true, "delete_branch_on_merge": false, "allow_auto_merge": false,
  "license": null, "topics": [],
  "security_and_analysis": {"secret_scanning": {"status": "disabled"}, "secret_scanning_push_protection": {"status": "disabled"},
    "dependabot_security_updates": {"status": "disabled"}}}'

classic_json='{"url": "https://api.github.com/repos/acme/widget/branches/main/protection",
  "required_status_checks": {"strict": false, "contexts": ["Build", "Test"]},
  "enforce_admins": {"enabled": false}, "required_linear_history": {"enabled": false},
  "allow_force_pushes": {"enabled": false}, "allow_deletions": {"enabled": false},
  "required_conversation_resolution": {"enabled": false}}'

# State persists between calls, so a read after a write sees the write.
dir="$(dirname "$log")"
[[ -f "$dir/gh-repo.json" ]] || jq . <<<"$repo_json" >"$dir/gh-repo.json"
[[ -f "$dir/gh-rulesets.json" ]] || echo '[]' >"$dir/gh-rulesets.json"
[[ -f "$dir/gh-classic.json" ]] || jq . <<<"$classic_json" >"$dir/gh-classic.json"
repo_json="$(cat "$dir/gh-repo.json")"

# Applies -f/-F key=value fields (and an --input JSON body) to the repo.
patch_repo() {
  local cur="$repo_json" k v
  while (($#)); do
    case "$1" in
      -f | -F | --field | --raw-field)
        k="${2%%=*}"
        v="${2#*=}"
        if [[ "$k" =~ ^security_and_analysis\[([a-z_]+)\]\[status\]$ ]]; then
          cur="$(jq --arg f "${BASH_REMATCH[1]}" --arg v "$v" '.security_and_analysis[$f].status = $v' <<<"$cur")"
        elif [[ "$1" != -f && "$1" != --raw-field && "$v" =~ ^(true|false|[0-9]+)$ ]]; then
          cur="$(jq --arg k "$k" --argjson v "$v" '.[$k] = $v' <<<"$cur")"
        else
          cur="$(jq --arg k "$k" --arg v "$v" '.[$k] = $v' <<<"$cur")"
        fi
        shift 2
        ;;
      *) shift ;;
    esac
  done
  if [[ -n "${body:-}" ]]; then cur="$(jq --argjson b "$body" '. * $b' <<<"$cur" 2>/dev/null || echo "$cur")"; fi
  echo "$cur" >"$dir/gh-repo.json"
  repo_json="$cur"
}

case "${1:-}" in
  api)
    path="$(for a in "${@:2}"; do [[ "$a" == repos/* || "$a" == /repos/* || "$a" == user* || "$a" == graphql ]] && echo "$a" && break; done)"
    path="${path#/}"
    case "$method $path" in
      "GET repos/$repo") out "$@" <<<"$repo_json" ;;
      "PATCH repos/$repo") patch_repo "$@"; out "$@" <<<"$repo_json" ;;
      "GET repos/$repo/branches/main/protection")
        if [[ -s "$dir/gh-classic.json" ]]; then out "$@" <"$dir/gh-classic.json"; else echo '{"message": "Branch not protected", "status": "404"}'; echo "gh: Branch not protected (HTTP 404)" >&2; exit 1; fi ;;
      "PUT repos/$repo/branches/main/protection")
        jq . <<<"${body:-$classic_json}" >"$dir/gh-classic.json" 2>/dev/null; out "$@" <"$dir/gh-classic.json" ;;
      "DELETE repos/$repo/branches/main/protection") : >"$dir/gh-classic.json" ;;
      "GET repos/$repo/rulesets") jq '[.[] | {id, name, target, enforcement, source_type, source}]' "$dir/gh-rulesets.json" | out "$@" ;;
      "GET repos/$repo/rulesets/"*) jq ".[] | select(.id == ${path##*/})" "$dir/gh-rulesets.json" | out "$@" ;;
      "POST repos/$repo/rulesets")
        n=$((4211 + $(jq length "$dir/gh-rulesets.json")))
        new="$(jq --argjson id "$n" '{id: $id, name: (.name // "ruleset"), target, source_type: "Repository", source: "acme/widget", enforcement, conditions, rules, bypass_actors}' <<<"${body:-null}" 2>/dev/null)"
        if [[ -z "$new" ]]; then echo '{"message": "Invalid request.", "status": "422"}'; echo "gh: Invalid request. (HTTP 422)" >&2; exit 1; fi
        jq --argjson r "$new" '. + [$r]' "$dir/gh-rulesets.json" >"$dir/gh-rulesets.tmp" && mv "$dir/gh-rulesets.tmp" "$dir/gh-rulesets.json"
        out "$@" <<<"$new"
        ;;
      "GET repos/$repo/rules/branches/main")
        jq '[.[] | select(.enforcement == "active") | . as $rs | .rules[] | . + {ruleset_source_type: "Repository", ruleset_source: "acme/widget", ruleset_id: $rs.id}]' "$dir/gh-rulesets.json" | out "$@" ;;
      "PUT repos/$repo/vulnerability-alerts" | "PUT repos/$repo/automated-security-fixes" | "PUT repos/$repo/private-vulnerability-reporting") : ;;
      "GET repos/$repo/vulnerability-alerts") echo '{"message": "Vulnerability alerts are disabled.", "status": "404"}' >&2; exit 1 ;;
      "GET repos/$repo/topics" | "PUT repos/$repo/topics") echo '{"names": []}' | out "$@" ;;
      "GET user") echo '{"login": "eval-user"}' | out "$@" ;;
      "GET repos/$repo/commits/main/check-runs" | "GET repos/$repo/commits/main/status")
        jq -n '{total_count: 5, check_runs: [{name: "Build", conclusion: "success"}, {name: "Test", conclusion: "success"}, {name: "Lint", conclusion: "success"}, {name: "Format Check", conclusion: "success"}, {name: "All Clear", conclusion: "success"}]}' | out "$@" ;;
      *) echo '{}' ;;
    esac
    ;;
  repo)
    case "${2:-}" in
      view)
        repo_json="$(cat "$dir/gh-repo.json")"
        if has --json "$@"; then
          jq '{nameWithOwner: .full_name, name, owner: {login: "acme"}, description, visibility: "PUBLIC", isPrivate: false,
            hasIssuesEnabled: .has_issues, hasDiscussionsEnabled: .has_discussions, hasWikiEnabled: .has_wiki,
            hasProjectsEnabled: .has_projects, defaultBranchRef: {name: "main"}, licenseInfo: null,
            repositoryTopics: [], url: "https://github.com/acme/widget", viewerPermission: "ADMIN"}' <<<"$repo_json" | out "$@"
        else
          printf 'name:\t%s\ndescription:\tSizes widgets\n' "$repo"
        fi
        ;;
      edit)
        cur="$repo_json"
        for a in "${@:3}"; do
          flag="${a%%=*}"
          val=true
          [[ "$a" == *=* ]] && val="${a#*=}"
          key=""
          case "$flag" in
            --enable-wiki) key=has_wiki ;;
            --enable-issues) key=has_issues ;;
            --enable-discussions) key=has_discussions ;;
            --enable-projects) key=has_projects ;;
            --enable-rebase-merge) key=allow_rebase_merge ;;
            --enable-squash-merge) key=allow_squash_merge ;;
            --enable-merge-commit) key=allow_merge_commit ;;
            --enable-auto-merge) key=allow_auto_merge ;;
            --delete-branch-on-merge) key=delete_branch_on_merge ;;
          esac
          [[ -n "$key" && "$val" =~ ^(true|false)$ ]] && cur="$(jq --arg k "$key" --argjson v "$val" '.[$k] = $v' <<<"$cur")"
        done
        echo "$cur" >"$dir/gh-repo.json"
        echo "✓ Edited repository $repo"
        ;;
      *) echo "(gh $* is not modelled in this sandbox; the call was recorded)" ;;
    esac
    ;;
  auth) echo "✓ Logged in to github.com account eval-user (GH_TOKEN)" ;;
  *) echo "(gh $* is not modelled in this sandbox; the call was recorded)" ;;
esac
