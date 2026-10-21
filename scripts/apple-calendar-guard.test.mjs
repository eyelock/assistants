// The apple-calendar harness is read only because a hook blocks every tool of its server except
// six. The server has no read-only mode, so this pattern is the only barrier: a tool the pattern
// misses is a tool that can write. These are the 29 tools che-ical-mcp 3.x registers.
import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import { dirname, join } from "node:path";
import { test } from "node:test";
import { fileURLToPath } from "node:url";

const root = join(dirname(fileURLToPath(import.meta.url)), "..");
const manifest = JSON.parse(
  readFileSync(join(root, "ynh", "apple-calendar", ".agents", "harness", "plugin.json"), "utf8"),
);
const guards = manifest.hooks.before_tool;
const matcher = new RegExp(guards[0].matcher);

const READ = [
  "list_calendars",
  "list_events",
  "list_events_quick",
  "search_events",
  "check_conflicts",
  "find_duplicate_events",
];
const BLOCKED = [
  "create_calendar",
  "update_calendar",
  "delete_calendar",
  "create_event",
  "create_events_batch",
  "update_event",
  "delete_event",
  "delete_events_batch",
  "move_events_batch",
  "copy_event",
  "undo",
  "redo",
  "undo_history",
  "list_reminders",
  "search_reminders",
  "list_reminder_tags",
  "create_reminder",
  "create_reminders_batch",
  "update_reminder",
  "complete_reminder",
  "delete_reminder",
  "delete_reminders_batch",
  "cleanup_completed_reminders",
];
const name = (tool) => `mcp__plugin__claude_apple-calendar__${tool}`;

test("the guard lets the six read tools through", () => {
  for (const tool of READ) assert.equal(matcher.test(name(tool)), false, tool);
});

test("the guard blocks every other tool of the server", () => {
  for (const tool of BLOCKED) assert.equal(matcher.test(name(tool)), true, tool);
});

test("the guard blocks a tool added later, because it allows only a list", () => {
  assert.equal(matcher.test(name("some_future_tool")), true);
  assert.equal(matcher.test(name("list_events_and_delete")), true);
});

test("the guard blocks with exit code 2 and says why", () => {
  assert.equal(guards.length, 1);
  assert.match(guards[0].command, /exit 2$/);
  assert.match(guards[0].command, />&2/);
});

test("the harness registers no tool the guard would not have seen", () => {
  assert.deepEqual(Object.keys(manifest.mcp_servers), ["apple-calendar"]);
});
