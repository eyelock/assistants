#!/usr/bin/env bash
# work-graph design handoff: the designer, Eno, holds a design bead that a build bead waits on
# (the build bead depends on the design bead). The human has agreed the design. The build bead
# already exists and belongs to a worker's repository, so the handoff is closing the design bead
# with the design written on the build bead, with no request to the desk.
set -euo pipefail
. "$EVAL_FIXTURES/graph-lib.sh"
wheelhouse_init
design=$(new_bead "Design the focus flag for ynh run" -p 1 -l repo:ynh)
build=$(new_bead "Build the focus flag for ynh run" -p 1 -l repo:ynh -d "Build what the design bead specifies.")
bd dep add -t blocks "$build" "$design" >/dev/null
BEADS_ACTOR=eno bd update "$design" --claim --json >/dev/null
