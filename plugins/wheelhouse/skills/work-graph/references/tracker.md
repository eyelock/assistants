# The tracker config

A Wheelhouse has two levels of tracking. Beads holds the agents' build work. A **tracker** (GitHub
Issues, JIRA, or another; or none) holds the humans' project view, grouped into releases. The
Wheelhouse's tracker config says which tracker it uses and how its items are named, and the
tracker's **adapter** script does the talking, so no skill or script has to assume one.

The config is `tracker.json` at the Wheelhouse root, beside `AGENTS.md`. Seats and scripts read
it; the humans change it. A Wheelhouse with **no** `tracker.json` is the same as
`{ "kind": "none" }`. A file that exists but cannot be read or parsed is a fault, never "no
tracker": report it and stop.

**The config holds no commands.** Nothing in it is ever run. What to run to read an item is code in
the adapter, where it can be read and scanned.

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
  "release": { "name": "milestone" },
  "exempt_repos": ["hq"]
}
```

| Field | Meaning |
|---|---|
| `kind` | the tracker's name: `github`, or another. It picks the adapter, `tracker-<kind>.sh` beside `open-pr.sh`, and must be lower-case letters, digits, `-` or `_`. `none` means no tracker, and needs nothing else. |
| `item.name` | what the tracker calls one item (`issue`, `ticket`), for what seats write. |
| `item.reference` | how a bead's `external_ref` writes the item: a full URL or a key. |
| `item.pattern` | **Required** for any kind but `none`. An extended regular expression (as `grep -E`) a valid reference matches, JSON-escaped. Write it with a safe character class (`[A-Za-z0-9_.-]`), never `[^/]+`: it keeps special characters out of a reference. |
| `item.example` | one real-looking reference, shown to a seat that has to write one. |
| `exempt_repos` | Optional. A list of repository names (the part after `repo:` in a bead's label) that are exempt from the tracker, such as the Wheelhouse's own repository when it plans in beads. A bead with one of these `repo:` labels needs no item, and `open-pr.sh` opens its pull request with no item, closing link or release, whatever its `external_ref` says; the dispatch note has no tracker line. The check is made by `open-pr.sh` before any adapter is called, so it holds for every kind. Anything but a list of strings is a fault. |
| `release.name` | what the tracker calls the release grouping (`milestone`, `fixVersion`), for what seats write. |

## The adapter

A kind's adapter is `scripts/tracker-<kind>.sh` in the `work-graph` skill. `tracker-github.sh` is
the one shipped. Each command is plain code that calls the tracker's own CLI with the item as a
single argument, after checking it against a strict form of its own:

| Command | Prints |
|---|---|
| `canon <ref>` | the canonical item id, so two spellings of one item compare equal |
| `release <item>` | the item's release, empty when it has none |
| `state <item>` | `open`, `closed` or `unknown` |
| `closing <item> <last\|more> <pr-repo>` | the closing line for a pull request body |
| `pr-flags <release>` | the arguments that set the release on a pull request, one a line |

Exit 1 for bad arguments, 3 for a failure (a missing tool, a failed call). A failure is a fault,
never an empty answer.

**A tracker with no adapter cannot open pull requests through `open-pr.sh`.** `tracker-generic.sh`
serves any other kind for the closing link and canon only; its `release` and `state` stop with
exit 3 and say so. To add a tracker (JIRA, say), write `tracker-<kind>.sh` with those five
commands, and a `tracker.json` naming the kind. Write the commands as literal code; never read a
command from the config.

## Reading it

- No file, or `kind: "none"`: no tracker. Say so; never invent one.
- A file that cannot be read, is not valid JSON, has no `kind`, or has no `item.pattern`: a fault.
  Report it, and don't fall back silently.
- Check a reference: `jq -r '.item.pattern' tracker.json`, then `grep -E` it, before calling the
  adapter.
- Read an item's release: `bash scripts/tracker-<kind>.sh release "<item>"`.

## Writing to the tracker

The adapter only reads. Changing an item's release (assigning it to a milestone or a fixVersion) is
tracker-specific: it is done with the tracker's own CLI, which the humans name when seating the
role that does it. Where none is named, the role proposes the change to the humans instead of
making it.
