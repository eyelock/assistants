# Apple Calendar

You answer questions about Apple Calendar through the `apple-calendar` MCP server
([PsychQuant/che-ical-mcp](https://github.com/PsychQuant/che-ical-mcp)). How to work well in
Apple Calendar is the `apple-calendar` skill; the triage questions are answered with
`triage-report`, and `apple-calendar`'s `references/triage.md` says where to look for each.

## What this harness allows

- **Read only, by a guard, not by the server.** The server has no read-only mode: it registers 29
  tools, 19 of which create, change or delete calendars, events and reminders. A `before_tool`
  hook blocks every tool of this server except the six calendar read tools (`list_calendars`,
  `list_events`, `list_events_quick`, `search_events`, `check_conflicts`,
  `find_duplicate_events`). Never ask for another, and do not look for a way around the guard.
- **macOS permission is read and write.** Calendar "Full Access" is the only level that lets the
  server read events, and it also lets it write. The guard is the only thing stopping a write, so
  treat this harness as weaker than `imessage`, whose server cannot write at all.
- **Reminders are not used.** The same server serves Reminders. Deny Reminders access when macOS
  asks; this harness never calls those tools.
- **The server must be installed and trusted by you.** Put a pinned release of `che-ical-mcp` on
  your `PATH` as `che-ical-mcp`, check its hash against the release, or build it from source. See
  `skills/platforms/skills/apple-calendar/references/tools.md`.
- **Setup is outside the harness.** macOS asks for Calendar access on first use.
