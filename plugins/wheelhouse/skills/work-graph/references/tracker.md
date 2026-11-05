# The tracker config

A Wheelhouse has two levels of tracking. Beads holds the agents' build work. A **tracker** (GitHub
Issues, JIRA, Linear, or none) holds the humans' project view, grouped into releases. The
Wheelhouse's tracker config says which tracker it uses and how to talk to it, so no skill or
script has to assume one.

The config is `tracker.json` at the Wheelhouse root, beside `AGENTS.md`. Seats and scripts read
it; the humans change it. A Wheelhouse with no `tracker.json` is the same as `{ "kind": "none" }`.

## Shape

```json
{
  "kind": "github",
  "item": {
    "name": "issue",
    "reference": "the full issue URL",
    "pattern": "^https://github\\.com/[^/]+/[^/]+/issues/[0-9]+$",
    "example": "https://github.com/eyelock/ynh/issues/680"
  },
  "release": {
    "name": "milestone",
    "read": "gh issue view {item} --json milestone --jq '.milestone.title // empty'"
  },
  "state": {
    "read": "gh issue view {item} --json state --jq .state",
    "open": "OPEN",
    "closed": "CLOSED"
  }
}
```

| Field | Meaning |
|---|---|
| `kind` | `github`, `jira`, `linear` or `none`. Informational: nothing branches on it except to pick a default adapter. Everything a seat needs is in the fields below. |
| `item.name` | what the tracker calls one item (`issue`, `ticket`), for what seats write. |
| `item.reference` | how a bead's `external_ref` writes the item: a full URL or a key. |
| `item.pattern` | a regular expression (extended, as `grep -E`) a valid reference matches; JSON-escaped. Used to refuse a malformed `external_ref`. Optional; without it, any non-empty value passes. |
| `item.example` | one real-looking reference, shown to a seat that has to write one. |
| `release.name` | what the tracker calls the release grouping (`milestone`, `fixVersion`, `cycle`), for what seats write. |
| `release.read` | a shell command that prints the item's release, empty when it has none. `{item}` is replaced by the reference. |
| `state.read` | a shell command that prints the item's state. `{item}` is replaced by the reference. |
| `state.open`, `state.closed` | the strings `state.read` prints for an open and a closed item, so a sweep can compare them with the work. |

`{item}` is the `external_ref` exactly as the bead holds it. The commands run with the human's own
tracker login; the config never holds a credential.

For `kind: "none"` the object is just `{ "kind": "none" }`: no other field is read.

## Starting points

These are defaults to adapt, not a closed list. Another tracker is another config.

GitHub issues, as above. JIRA, with the `jira` CLI:

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
    "read": "jira issue view {item} --raw | jq -r '.fields.fixVersions[0].name // empty'"
  },
  "state": {
    "read": "jira issue view {item} --raw | jq -r '.fields.status.statusCategory.key'",
    "open": "indeterminate",
    "closed": "done"
  }
}
```

`state.open` and `state.closed` are the strings to compare with. Any other state is "unknown",
which a sweep reports rather than guesses.

## Reading it

- Check a reference: `jq -r '.item.pattern // empty' tracker.json`, then `grep -E` it.
- Read an item's release: take `release.read`, replace `{item}` with the reference, run it.
- No file, `kind: "none"`, or an unreadable file: the Wheelhouse has no tracker. Never invent one.
  A malformed file is a fault: say so, don't fall back silently.
