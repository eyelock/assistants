# Give a harness a tool

Teach a harness to use a tool, and to be stopped from misusing it. You will build a small ynh harness that gets an MCP server (the tool), attaches a `before_tool` hook that blocks anything that would change something, and names a repeatable question as a focus. Along the way you will see skills from this repo arrive in the harness, and the hook refuse a write.

The tool here is an MCP server that reads Messages, pointed at a fake database. Any MCP server follows the same steps; Messages is just a convenient one because a fake `chat.db` is easy to build. The skills the harness includes happen to answer "what is waiting on me?", which is one use of this repo among many. What you are learning is the tool and the hook.

Nothing here touches your real Messages and nothing needs a login. The data is invented, in a database you build yourself.

## Prerequisites

- `ynh` and `ynd` v0.12.0, on your PATH
- Claude Code (`claude`), signed in
- Node.js with `npx`, `git` and `sqlite3`
- macOS or Linux. The fake database does not need a Mac.

```bash
ynh --version
```

You should see:

```
v0.12.0
```

One step below runs a model, once, with `--model=sonnet`. It makes one paid Claude request of a few turns.

## Make a workspace

Everything goes in one folder, and `YNH_HOME` keeps ynh's own state inside it, so your real `~/.ynh` is untouched.

```bash
rm -rf /tmp/assistants-tutorial
mkdir -p /tmp/assistants-tutorial
cd /tmp/assistants-tutorial
export YNH_HOME=/tmp/assistants-tutorial/home
git clone https://github.com/eyelock/assistants.git
ynh init
```

You should see:

```
ynh home: /tmp/assistants-tutorial/home

Add this to your shell profile if not already present:
  export PATH="/tmp/assistants-tutorial/home/bin:$PATH"
```

Ignore the PATH suggestion. The clone gives the harness a local copy of this repo's skills to include. Keep `YNH_HOME` exported in this terminal for every step that follows.

## Build the fake Messages database

The MCP server reads Messages from a SQLite file called `chat.db`. This script writes a small one with five invented conversations. Dates are built relative to now, so the messages always look recent.

```bash
cat > /tmp/assistants-tutorial/make-fake-chat-db.sh << 'EOF'
#!/bin/bash
# Build a small, invented Messages database. Every name, number and text is made up.
set -euo pipefail
DB="${1:?usage: make-fake-chat-db.sh <path-to-chat.db>}"
rm -f "$DB"

sqlite3 "$DB" << 'SQL'
CREATE TABLE handle (ROWID INTEGER PRIMARY KEY AUTOINCREMENT, id TEXT, country TEXT, service TEXT);
CREATE TABLE chat (ROWID INTEGER PRIMARY KEY AUTOINCREMENT, guid TEXT, style INTEGER, state INTEGER, account_id TEXT, chat_identifier TEXT, service_name TEXT, display_name TEXT);
CREATE TABLE message (ROWID INTEGER PRIMARY KEY AUTOINCREMENT, guid TEXT, text TEXT, handle_id INTEGER, service TEXT, date INTEGER, date_read INTEGER, date_delivered INTEGER, is_from_me INTEGER, is_read INTEGER, is_delivered INTEGER, cache_has_attachments INTEGER DEFAULT 0, associated_message_type INTEGER DEFAULT 0, associated_message_guid TEXT, reply_to_guid TEXT, thread_originator_guid TEXT, item_type INTEGER DEFAULT 0, group_action_type INTEGER DEFAULT 0, date_edited INTEGER DEFAULT 0, date_retracted INTEGER DEFAULT 0);
CREATE TABLE chat_message_join (chat_id INTEGER, message_id INTEGER, message_date INTEGER DEFAULT 0, PRIMARY KEY (chat_id, message_id));
CREATE TABLE chat_handle_join (chat_id INTEGER, handle_id INTEGER);
CREATE TABLE attachment (ROWID INTEGER PRIMARY KEY AUTOINCREMENT, guid TEXT, filename TEXT, mime_type TEXT, transfer_name TEXT, total_bytes INTEGER);
CREATE TABLE message_attachment_join (message_id INTEGER, attachment_id INTEGER);

INSERT INTO handle (id, country, service) VALUES
  ('+447700900101','gb','iMessage'), ('+447700900102','gb','iMessage'),
  ('+447700900103','gb','iMessage'), ('+447700900104','gb','iMessage'),
  ('+447700900105','gb','iMessage');

INSERT INTO chat (guid, style, state, account_id, chat_identifier, service_name, display_name) VALUES
  ('iMessage;-;+447700900101',45,3,'A:fake','+447700900101','iMessage',''),
  ('iMessage;-;+447700900102',45,3,'A:fake','+447700900102','iMessage',''),
  ('iMessage;-;+447700900103',45,3,'A:fake','+447700900103','iMessage',''),
  ('iMessage;-;+447700900104',45,3,'A:fake','+447700900104','iMessage',''),
  ('iMessage;+;chat900001',43,3,'A:fake','chat900001','iMessage','Climbing Crew');

-- Apple stores dates as nanoseconds since 2001-01-01 UTC. Build them relative to now.
CREATE TEMP TABLE seed (chat INTEGER, handle INTEGER, from_me INTEGER, hours_ago INTEGER, body TEXT);
INSERT INTO seed VALUES
  (1,1,0,30,'Morning! Are you still ok to review the pitch deck before Thursday?'),
  (1,1,0,28,'Need your yes or no by tonight if you can'),
  (2,2,0,60,'Thanks for the intro last week'),
  (3,3,0,12,'Are you coming Sunday?'),
  (3,0,1,11,'Yes, I will bring dessert'),
  (4,4,0,10,'Can you send me the gym schedule?'),
  (4,0,1,9,'I will send it over on Friday'),
  (5,5,0,6,'Who is up for the wall on Saturday at 10?'),
  (5,1,0,5,'I am in'),
  (5,0,1,4,'Count me in too'),
  (2,0,1,50,'Could you send me the invoice number for the October order?');

INSERT INTO message (guid, text, handle_id, service, date, date_read, date_delivered, is_from_me, is_read, is_delivered)
  SELECT 'fake-' || rowid, body, handle, 'iMessage',
         ((CAST(strftime('%s','now') AS INTEGER) - 978307200) - hours_ago*3600) * 1000000000,
         0, 0, from_me, 1, 1
  FROM seed ORDER BY hours_ago DESC;

INSERT INTO chat_message_join (chat_id, message_id, message_date)
  SELECT s.chat, m.ROWID, m.date FROM message m JOIN seed s ON m.guid = 'fake-' || s.rowid;
SQL
echo "Wrote $DB: $(sqlite3 "$DB" 'select count(*) from message') messages in $(sqlite3 "$DB" 'select count(*) from chat') chats"
EOF
chmod +x /tmp/assistants-tutorial/make-fake-chat-db.sh
/tmp/assistants-tutorial/make-fake-chat-db.sh /tmp/assistants-tutorial/chat.db
```

You should see:

```
Wrote /tmp/assistants-tutorial/chat.db: 11 messages in 5 chats
```

Look at it. In this data only one conversation is waiting on you: the pitch deck. The others end on your own message, or on a thank-you that asks nothing.

```bash
sqlite3 /tmp/assistants-tutorial/chat.db "select c.chat_identifier, m.is_from_me, m.text from message m join chat_message_join j on j.message_id = m.ROWID join chat c on c.ROWID = j.chat_id order by m.date"
```

You should see:

```
+447700900102|0|Thanks for the intro last week
+447700900102|1|Could you send me the invoice number for the October order?
+447700900101|0|Morning! Are you still ok to review the pitch deck before Thursday?
+447700900101|0|Need your yes or no by tonight if you can
+447700900103|0|Are you coming Sunday?
+447700900103|1|Yes, I will bring dessert
+447700900104|0|Can you send me the gym schedule?
+447700900104|1|I will send it over on Friday
chat900001|0|Who is up for the wall on Saturday at 10?
chat900001|0|I am in
chat900001|1|Count me in too
```

## Write the hook

A hook is a script the assistant runs before every matching tool call. This one blocks anything that would change something. Exit code 2 means "stop", and what the script prints to stderr goes back to the model.

```bash
mkdir -p /tmp/assistants-tutorial/messages-harness/.agents/harness /tmp/assistants-tutorial/messages-harness/hooks

cat > /tmp/assistants-tutorial/messages-harness/hooks/block-writes.sh << 'EOF'
#!/bin/bash
# before_tool hook: this harness reads and reports. It never changes anything.
# The tool call arrives as JSON on stdin; exit code 2 blocks it and the
# message on stderr goes back to the model.
INPUT=$(cat)
TOOL=$(printf '%s' "$INPUT" | sed -n 's/.*"tool_name"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' | head -1)
cat >&2 << MSG
BLOCKED: this is a read-only harness; "$TOOL" would change something.
Remediation: put the result in your reply instead. Do not write files or send messages.
MSG
exit 2
EOF
chmod +x /tmp/assistants-tutorial/messages-harness/hooks/block-writes.sh
```

Try it on its own, with the JSON Claude Code would send for a file write:

```bash
echo '{"tool_name":"Write","tool_input":{"file_path":"report.md"}}' | /tmp/assistants-tutorial/messages-harness/hooks/block-writes.sh
echo "exit $?"
```

You should see:

```
BLOCKED: this is a read-only harness; "Write" would change something.
Remediation: put the result in your reply instead. Do not write files or send messages.
exit 2
```

## Write the harness

The harness is one file. It pulls in two skill sets from your clone of this repo, runs the `imessage-mcp` server against your fake database, attaches the hook, and defines a focus called `waiting-on-me`.

```bash
cat > /tmp/assistants-tutorial/messages-harness/.agents/harness/plugin.json << 'EOF'
{
  "$schema": "https://eyelock.github.io/ynh/schema/plugin.schema.json",
  "name": "messages-reader",
  "version": "0.1.0",
  "description": "Read-only Messages reader over a fake chat.db",
  "default_vendor": "claude",
  "includes": [
    { "git": "/tmp/assistants-tutorial/assistants", "path": "skills/triage" },
    {
      "git": "/tmp/assistants-tutorial/assistants",
      "path": "skills/platforms",
      "pick": ["skills/imessage"]
    }
  ],
  "mcp_servers": {
    "imessage": {
      "command": "npx",
      "args": [
        "-y", "imessage-mcp@3.2.0",
        "--privacy", "full",
        "--contacts", "none",
        "--database", "/tmp/assistants-tutorial/chat.db"
      ],
      "env": { "IMESSAGE_UPDATE_CHECK": "0", "IMESSAGE_CACHE": "0" }
    }
  },
  "hooks": {
    "before_tool": [
      {
        "matcher": "Write|Edit|MultiEdit|NotebookEdit|Bash",
        "command": "/tmp/assistants-tutorial/messages-harness/hooks/block-writes.sh"
      }
    ]
  },
  "agent": { "max_turns": 25, "effort": "low" },
  "focuses": {
    "waiting-on-me": {
      "prompt": "Use the waiting-on-me skill to find what is waiting on me in Messages."
    }
  }
}
EOF
```

This is the same shape as `ynh/imessage/.agents/harness/plugin.json` in the repo. That one includes the skills from GitHub and reads your real Messages; yours includes them from your clone and reads the fake file.

Check it:

```bash
ynd validate /tmp/assistants-tutorial/messages-harness
```

You should see (trimmed):

```
/tmp/assistants-tutorial/messages-harness: valid
  checked:
    manifest     .../messages-harness/.agents/harness/plugin.json against https://eyelock.github.io/ynh/schema/plugin.schema.json
    includes     /tmp/assistants-tutorial/assistants path skills/triage
                 /tmp/assistants-tutorial/assistants path skills/platforms pick skills/imessage
    mcp_servers  imessage runs `npx -y imessage-mcp@3.2.0 --privacy full --contacts none --database /tmp/assistants-tutorial/chat.db`
    hooks        before_tool runs `/tmp/assistants-tutorial/messages-harness/hooks/block-writes.sh`
    focuses      waiting-on-me
```

## See what the assistant will be given

Preview assembles the harness for Claude without starting it.

```bash
ynd preview /tmp/assistants-tutorial/messages-harness -v claude -o /tmp/assistants-tutorial/preview
cat /tmp/assistants-tutorial/preview/.claude/hooks/hooks.json
ls /tmp/assistants-tutorial/preview/.claude/skills
```

You should see:

```
Preview written to /tmp/assistants-tutorial/preview
{
  "hooks": {
    "PreToolUse": [
      {
        "matcher": "Write|Edit|MultiEdit|NotebookEdit|Bash",
        "hooks": [
          {
            "type": "command",
            "command": "/tmp/assistants-tutorial/messages-harness/hooks/block-writes.sh"
          }
        ]
      }
    ]
  }
}
action-now-or-soon
add-triage-question
catch-up
find
imessage
my-commitments
triage-report
waiting-on-me
waiting-on-them
```

Your one hook became Claude's `PreToolUse`. The skills came from two places: `waiting-on-me`, `triage-report` and the rest are generic skills from `skills/triage`. `imessage` is the platform skill from `skills/platforms`, which knows how Messages stores dates and tapbacks. `.claude/.mcp.json` in the same folder holds the server.

## Run it

This is the one step that runs a model. The focus supplies the prompt. `--instructions` asks for something the hook must refuse, so you see it stop a write. `--allowedTools` lets the model call the read-only Messages tools without a prompt, since no one is at the keyboard in a focus run. Give it the full tool names, as below: a shorter prefix such as `mcp__plugin__claude_imessage` is not matched and every Messages call is refused.

*Your output will differ: it shows what the model did.*

```bash
P=mcp__plugin__claude_imessage__
ynh run /tmp/assistants-tutorial/messages-harness \
  --focus waiting-on-me \
  --model=sonnet \
  --allowedTools="${P}server_status,${P}list_conversations,${P}get_conversation,${P}resolve_contact,${P}search_messages" \
  --instructions "After you answer, also save the report to /tmp/assistants-tutorial/report.md."
```

You should see something like:

```
Resolving 2 include(s)...
  Cached /tmp/assistants-tutorial/assistants → skills/triage
  Cached /tmp/assistants-tutorial/assistants → skills/platforms [skills/imessage]
Launching claude...
I couldn't save the report. A hook in the read-only Messages harness blocked the write, so the report is only here in my reply.

### waiting-on-me

| Platform | What | Who | Since | Why now | Link |
|---|---|---|---|---|---|
| messages | Asked whether you can still review the pitch deck before Thursday, then asked for a yes or no by tonight. Neither message has a reply from you. | Unknown number +447700900101 (not in your contacts), 1:1 iMessage | 2026-10-19 | | No link; conversation with +447700900101, 2026-10-19 |

Looked back 14 days for messages, from 2026-10-06. I can widen that.

Counts: messages waiting-on-me 1.
```

The date is the day your database was built, not 2026-10-19.

Check that nothing was written:

```bash
ls /tmp/assistants-tutorial/report.md
```

You should see:

```
ls: /tmp/assistants-tutorial/report.md: No such file or directory
```

That is the whole result, and each part did one job. The MCP server is the tool: it returned the conversations. The `imessage` skill told the model how to read them. `waiting-on-me` decided that only the pitch deck waits on you. And the hook refused the write.

## Clean up

```bash
rm -rf /tmp/assistants-tutorial
unset YNH_HOME
```

## What you learned

- A harness is one `plugin.json` that names its skills, its MCP server, its hooks and its focuses
- `mcp_servers` gives the harness a tool, and `includes` gives it skills that say how to use it
- The MCP server is the only part that touches data, and here it reads a file you made
- A focus gives a repeatable question a name you pass with `--focus`
- A `before_tool` hook that exits 2 blocks a tool call, and its message goes back to the model

## Next

- Make the hook a proper script you can test and reuse: [Add a hook](add-a-hook.md)
- See every field you used: [Harness manifest](harness-manifest.md)
- Point the real `ynh/imessage` harness at a copy of your own `chat.db` with `--database`, as `ynh/imessage/AGENTS.md` suggests for a first trial.
