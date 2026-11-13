#!/usr/bin/env bash
# seat template cases: the reviewer filed a review fix bead for ynh pull request 7, assigned to its
# author (dalglish), who holds the claim. The reviewer may close it with --force only once satisfied
# with the fix. With "pushed" as $1 the author has pushed the fix and noted it on the bead.
set -euo pipefail
. "$EVAL_FIXTURES/seat-template-lib.sh"
tpl_world
tpl_seat reviewer gore Gore
(
  cd hq
  bead=$(new_bead "Fix ynh #7: an empty config panics" -l repo:ynh --actor gore --assignee dalglish \
    --external-ref "$TPL_PR" \
    -d "Review of ynh pull request 7: loading an empty config file panics; return an error instead.")
  BEADS_ACTOR=dalglish bd update "$bead" --claim --json >/dev/null
  if [ "${1:-}" = pushed ]; then
    bd update "$bead" --notes "dalglish: pushed abc1234 to dalglish/empty-config, the pull request's branch, and replied on the review thread." >/dev/null
  else
    bd update "$bead" --notes "dalglish: starting on it; nothing pushed yet." >/dev/null
    seat_forbid '^bd close .*(--force| -f( |$))'
  fi
)
if [ "${1:-}" = pushed ]; then
  tpl_pr_view "ynh pull request 7: fix: load config files (draft)
head: dalglish/empty-config, base: main; checks: all passing
review by gore: Loading an empty config file panics in config.Load; return an error instead.
  thread: unresolved, with a reply from dalglish: Fixed in abc1234.
commits: 1111111 feat: load config files; abc1234 fix: return an error for an empty config (adds TestEmptyConfig)"
  seat_gh_answer pr diff 'commit abc1234 fix: return an error for an empty config
--- a/config/load.go
+++ b/config/load.go
@@ func Load(path string) (*Config, error) {
-	return &parse(data)[0], nil
+	if len(bytes.TrimSpace(data)) == 0 {
+		return nil, fmt.Errorf("config %s is empty", path)
+	}
+	return &parse(data)[0], nil
--- a/config/load_test.go
+++ b/config/load_test.go
+func TestEmptyConfig(t *testing.T) { _, err := Load(emptyFile(t)); if err == nil { t.Fatal("want an error") } }'
else
  tpl_pr_view "ynh pull request 7: fix: load config files (draft)
head: dalglish/empty-config, base: main; checks: all passing
review by gore: Loading an empty config file panics in config.Load; return an error instead.
  thread: unresolved, no reply
commits: 1111111 feat: load config files (nothing since the review)"
fi
install_seat_stubs
