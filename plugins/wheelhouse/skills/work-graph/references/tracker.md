# The tracker config

A Wheelhouse has two levels of tracking. Beads holds the agents' build work. A **tracker** (GitHub
Issues, JIRA, or another; or none) holds the humans' project view, grouped into releases. The
Wheelhouse's tracker config says which tracker it uses and how to talk to it, so no skill or
script has to assume one.

The config is `tracker.json` at the Wheelhouse root, beside `AGENTS.md`. Seats and scripts read
it; the humans change it. A Wheelhouse with **no** `tracker.json` is the same as
`{ "kind": "none" }`. A file that exists but cannot be read or parsed is a fault, never "no
tracker": report it and stop.

## Shape

```json
{
  "kind": "github",
  "item": {
    "name": "issue",
    "reference": "the full issue URL",
    "pattern": "^https://github\\.com/[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+/issues/[0-9]+$",
    "example": "https://github.com/eyelock/ynh/issues/680"
  },
  "release": {
    "name": "milestone",
    "read": "gh issue view \"$TRACKER_ITEM\" --json milestone --jq '.milestone.title // empty'"
  },
  "state": {
    "read": "gh issue view \"$TRACKER_ITEM\" --json state --jq .state",
    "open": ["OPEN"],
    "closed": ["CLOSED"]
  }
}
```

| Field | Meaning |
|---|---|
| `kind` | the tracker's name: `github`, `jira`, another, or `none`. Nothing branches on it except to pick an adapter (`tracker-<kind>.sh`, falling back to a generic one). Everything a seat needs is in the fields below. |
| `item.name` | what the tracker calls one item (`issue`, `ticket`), for what seats write. |
| `item.reference` | how a bead's `external_ref` writes the item: a full URL or a key. |
| `item.pattern` | **Required** for any kind but `none`. An extended regular expression (as `grep -E`) a valid reference matches, JSON-escaped. Write it with a safe character class (`[A-Za-z0-9_.-]`), never `[^/]+`: the pattern is what keeps shell special characters out of a reference. |
| `item.example` | one real-looking reference, shown to a seat that has to write one. |
| `release.name` | what the tracker calls the release grouping (`milestone`, `fixVersion`), for what seats write. |
| `release.read` | a shell command that prints the item's release, empty when it has none. |
| `state.read` | a shell command that prints the item's state. |
| `state.open`, `state.closed` | lists of the strings `state.read` prints for an open and for a closed item, so a sweep can compare them with the work. Any other state is "unknown", which a sweep reports rather than guesses. |

The commands run with the human's own tracker login; the config never holds a credential.

## Running a command safely

A reference comes from a bead's `external_ref`, which an agent writes, often from a prompt or an
issue body. It must never reach a shell as code. So:

1. **Validate first.** Check the reference against `item.pattern` before running anything. A
   reference that fails is refused, not run. A config with no `pattern` (for a kind other than
   `none`) is a fault: refuse to run its commands.
2. **Pass it in the environment.** The commands are written against `"$TRACKER_ITEM"` (quoted,
   and not inside single quotes), and the consumer runs them as
   `TRACKER_ITEM="$ref" sh -c "$command"`. The reference is never substituted into the command
   text.

## Starting points

Defaults to adapt, not a closed list. Another tracker is another config; ask the human for the
CLI or API call that prints an item's release and its state, and for a safe pattern. There is no
starting point for a tracker whose command line you do not know: do not guess one.

GitHub issues is the shape above. JIRA, with the `jira` CLI:

```json
{
  "kind": "jira",
  "item": {
    "name": "ticket",
    "reference": "the issue key",
    "pattern": "^[A-Z][A-Z0-9]+-[0-9]+$",
    "example": "PLAT-1234"
  },
  "release": {
    "name": "fixVersion",
    "read": "jira issue view \"$TRACKER_ITEM\" --raw | jq -r '.fields.fixVersions[0].name // empty'"
  },
  "state": {
    "read": "jira issue view \"$TRACKER_ITEM\" --raw | jq -r '.fields.status.statusCategory.key'",
    "open": ["new", "indeterminate"],
    "closed": ["done"]
  }
}
```

(`new` is JIRA's "To Do", `indeterminate` its "In Progress".)

## Writing to the tracker

The config only reads. Changing an item's release (assigning it to a milestone or a fixVersion) is
tracker-specific: it is done with the tracker's own CLI, which the human names when seating the
role that does it. Where none is named, the role proposes the change to the humans instead of
making it.

## Reading it

- No file, or `kind: "none"`: no tracker. Say so; never invent one.
- A file that cannot be read, is not valid JSON, has no `kind`, or has no `item.pattern`: a fault.
  Report it, and don't fall back silently.
- Check a reference: `jq -r '.item.pattern' tracker.json`, then `grep -E` it.
- Read an item's release: validate the reference, then run `release.read` as above.
