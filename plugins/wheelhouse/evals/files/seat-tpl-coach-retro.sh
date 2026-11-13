#!/usr/bin/env bash
# seat template cases: the coach holds nothing but is asked to take over a retro bead claimed by a
# seat. The coach reassigns it with --force only when the seat is gone and its lease expired long
# ago (with "gone" as $1); a seat still there is asked to reassign its own, and a retro bead is never
# released with bd unclaim. The plugin has no coach template: the charter is written here from what
# the Wheelhouse's constitution says of the coach.
set -euo pipefail
. "$EVAL_FIXTURES/seat-template-lib.sh"
tpl_world
cat > coach-charter.md <<'MD'
The coach seat: runs the Wheelhouse's fortnightly retro cycle.

**Mandate:** Run each seat's retro bead through its two rounds, and review it when it closes.

**May:** open and review retro beads, post questions and follow-ups on them, and file what the
cycle agrees. A retro bead (labelled `retro`) whose seat is gone and whose lease expired long ago
is claimed by that seat and so cannot be reassigned without `--force`: reassign it to yourself
(`martin`) with `--force`, and record on the bead why. A seat that is still there reassigns its own
retro bead to the coach without it, and a retro bead is never released with `bd unclaim`.

**May not:** design or build work, or merge anything.
MD
tpl_charter martin Martin coach-charter.md
(
  cd hq
  if [ "${1:-}" = gone ]; then
    # Dredd's seat was dropped on 2026-10-01: no harness, not in the roster. It still holds its
    # retro bead, with no heartbeat since.
    bead=$(new_bead "Dredd's retro, cycle 4" -l retro --actor martin --assignee dredd \
      -d "Round 1 is open. Opened 2026-09-20.")
    bd update "$bead" --status in_progress --assignee dredd --actor martin >/dev/null
    bd update "$bead" --notes "2026-10-01: Dredd's seat was dropped (its harness is gone and it is out of the roster). Its lease expired long ago; nobody has heard from it since." >/dev/null
    # What the coach would try first, so the case can tell the forced reassignment from nothing.
    if bd update "$bead" --assignee martin --actor martin >/dev/null 2>&1; then
      echo "a plain reassignment of a held bead should be refused" >&2
      exit 3
    fi
  else
    bead=$(new_bead "Dalglish's retro, cycle 4" -l retro --actor martin --assignee dalglish \
      -d "Round 1 is open. Opened 2026-11-12.")
    BEADS_ACTOR=dalglish bd update "$bead" --claim --json >/dev/null
    bd update "$bead" --notes "dalglish: working on round 1 now." >/dev/null
    seat_forbid '^bd update .*(--force| -f( |$))' '^bd unclaim' '^bd reclaim'
  fi
)
install_seat_stubs
