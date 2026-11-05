# Google Calendar tools (workspace-mcp, `--tools calendar`, `--read-only`)

For exact parameters and return fields, check each tool's own description; only what is known
is listed.

| Tool | What it is for | Notes |
|---|---|---|
| `list_calendars` | The calendars the user can see | Gives the primary calendar and its time zone |
| `get_events` | Events in a window | Attendees carry `responseStatus`; events carry `htmlLink` |
| `query_freebusy` | When people or calendars are busy | For availability, not for event details |

## Event fields that matter

`start` and `end` (`dateTime` for timed events, `date` for all-day), `status`, `attendees` with
`responseStatus`, `organizer`, `created`, `recurringEventId` on recurring instances,
`htmlLink`.

## Write tools: removed

`--read-only` removes the tools that create, change, delete or respond to events. Do not ask
for them.

## Auth

`GOOGLE_OAUTH_CLIENT_ID`, `GOOGLE_OAUTH_CLIENT_SECRET`, `USER_GOOGLE_EMAIL`, with `--single-user`.
