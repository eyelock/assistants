#!/usr/bin/env bash
# handoff with held work: gahan is mid-way through the changelog (committed), and also holds a bead for a
# pull request that waits on a design bead: nothing gahan can do on it until the design closes. The
# held bead is claimed and in progress, and is not blocked in the graph yet.
set -euo pipefail
. "$EVAL_FIXTURES/graph-lib.sh"
wheelhouse_init
install_ynm_stub
changelog_in_progress >/dev/null
design=$(BEADS_ACTOR=ynw new_bead "Design the ynh 0.13 deprecation policy" -p 2 -l repo:ynh)
held=$(new_bead "Land the deprecation notices in ynh #700" -p 2 -l repo:ynh)
BEADS_ACTOR=gahan bd update "$held" --claim --json >/dev/null
BEADS_ACTOR=gahan bd update "$held" --append-notes "PR: https://github.com/eyelock/ynh/pull/700 (draft). Waiting on $design: the notices can't be worded until the policy is settled." --json >/dev/null
