# Apple Calendar tools (che-ical-mcp)

Source: `github.com/PsychQuant/che-ical-mcp` (MIT, Swift, EventKit). For exact parameters and
return fields, check each tool's own description; only what is known is listed.

## The six tools this harness allows

| Tool | What it is for | Notes |
|---|---|---|
| `list_calendars` | The calendars and their sources | Use before naming a calendar; gives iCloud, Google and Exchange sources |
| `list_events` | Events in a date range | `start_date` and `end_date` required; `calendar_name`, `calendar_source`, `filter` (all, past, future, all_day), `sort`, `limit`, `detail_level` (summary or standard), `display_timezone`, `fields` |
| `list_events_quick` | A named range | `range`: today, tomorrow, this_week, next_week, this_month, next_7_days, next_30_days |
| `search_events` | Events by keyword | `keyword` or `keywords` with `match_mode`; optional date range and calendar; same output options |
| `check_conflicts` | Overlapping events in a range | For clashes between accepted meetings |
| `find_duplicate_events` | Likely duplicate events | Not needed for triage |

All six are marked read only by the server.

## Event fields that matter

`id`, `title`, `start_date`, `end_date`, `start_date_local`, `end_date_local`, `timezone`,
`is_all_day`, `calendar`, `location`, `notes`, `url`, `is_recurring`, `attendees` (each with
`email`, `name`, `role`, `status`, `type`, `is_current_user`) and `organizer` (`name`, `email`,
`is_current_user`). The standard detail level carries attendees and organizer; check that the
summary level does before relying on it. There is no creation date and no cancelled flag.

## Tools the harness blocks

The server registers 29 tools. These 23 are blocked by the harness hook, and you must not call
them: `create_calendar`, `update_calendar`, `delete_calendar`, `create_event`, `create_events_batch`,
`update_event`, `delete_event`, `delete_events_batch`, `move_events_batch`, `copy_event`, `undo`,
`redo`, `undo_history`, and the Reminders tools `list_reminders`, `search_reminders`,
`list_reminder_tags`, `create_reminder`, `create_reminders_batch`, `update_reminder`,
`complete_reminder`, `delete_reminder`, `delete_reminders_batch`, `cleanup_completed_reminders`.

## Installing the server

The server is a Swift binary, not an npm or PyPI package. Its README installs a prebuilt notarized
release (`curl` from GitHub Releases), which is not guaranteed to match the source. Safer:
- Pin one release, download it, and check its SHA-256 against the release before use.
- Or build it from source with Swift (`swift build -c release`) and put the result on your `PATH`
  as `che-ical-mcp`.
- Do not run `--self-update`: it downloads a newer binary from GitHub Releases.
- When macOS asks, allow Calendar. Deny Reminders; the harness never uses it.

## Permission

macOS offers "Full Access" to Calendars, which reads and writes. There is no read-only level, so
the harness hook is the only thing stopping a write.
