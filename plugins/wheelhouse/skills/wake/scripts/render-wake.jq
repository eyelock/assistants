# Renders a wake block (wake.sh's JSON) as Markdown. Run as: jq -r --arg memsh <path to memory.sh> -f render-wake.jq <<<"$json"
# The JSON is what wake.sh prints by default; this only lays it out, and reads nothing else.
  def retire(id; why): "bash \($memsh) forget --id \(id) --reason \"\(why)\"";
  def list(xs; empty_text): if (xs | length) == 0 then empty_text else (xs | map("- " + .) | join("\n")) end;
  "# Waking: \(.seat)\n",
  ([if .sync.memory == "failed" then (if .backend == "beads" then "memory and the work graph (bd sync)" else "memory (ynm sync)" end) else empty end,
    if .sync.work == "failed" and .backend != "beads" then "the work graph (bd sync)" else empty end] as $failed
   | if ($failed | length) > 0
     then "**Not synced:** \($failed | join(" and ")) failed, so what follows may be out of date. Say so when you reply, and run the sync by hand before relying on it.\n"
     else empty end),
  (if .session.state == "forced" then "**Forced start:** you took this seat over from \(.session.replaced.label)" + (if .session.replaced.started then " (started \(.session.replaced.started))" else "" end) + ". The session bead says so. Say so in your reply.\n"
   elif .session.state == "unknown" then "**Live-session check not made:** \(.session.why). Nothing stopped this start, so another session of you may be live: say so in your reply, and check before you change anything.\n"
   else empty end),
  (if .inbox == null then empty
   elif .inbox.error then "## For the humans\n\nThe inbox could not be read: \(.inbox.error). Say so when you reply; the doctor skill can help.\n"
   else
     def bead: "- \(.title)"
       + (if .ref then ": [\(.ref.short // .ref.url)](\(.ref.url))" else "" end)
       + " (\(.id), asked by \(.askedBy // "unknown"), unblocks \(.unblocks))";
     def note: "- \(.content) (note \(.memoryId))";
     "## For the humans\n",
     (if ((.inbox.errors // []) | length) > 0
      then "**The inbox could not be read in full:** \(.inbox.errors | join("; ")). Don't say nothing is waiting: say what couldn't be read when you reply, and what could; the doctor skill can help.\n"
      else empty end),
     (if .inbox.empty == true then "Nothing waiting for the humans.\n"
      else
        (.inbox.humans[] |
          "### \(.name) (\(.role))\n",
          (if .beads == null then "Their beads couldn't be read.\n" else empty end),
          (if .notes == null then "Their notes couldn't be read.\n" else empty end),
          (if .beads != null and .notes != null and (.beads | length) == 0 and (.notes | length) == 0 then "Nothing waiting.\n"
           else
             ((.beads // []) | map(select(.kind != "report"))) as $todo
             | ((.beads // []) | map(select(.kind == "report"))) as $reports
             | (if ($todo | length) > 0 then ($todo | map(bead) | join("\n")) + "\n" else empty end),
             (if ($reports | length) > 0 then "Reports:\n" + ($reports | map(bead) | join("\n")) + "\n" else empty end),
             (if (.notes // [] | length) > 0 then "Notes:\n" + (.notes | map(note) | join("\n")) + "\n" else empty end)
           end)),
        "Open your reply with this, before anything else (even who you are), naming each pull request or page by its short form as a Markdown link. Retire each note you relay, in the same turn, so it is not shown twice: `bash \($memsh) forget --id <its memoryId> --reason relayed`.\n"
      end),
     (if .inbox.you == null then "This is the default human's inbox, and the desk treats the human at the desk as them. After the inbox, tell the human so in your reply, and that they can name themselves for this session (\"it's me, <name>\") to see their own inbox instead; nothing is saved. Always say it: do not leave it out because the inbox is empty or you have much else to report.\n" else empty end)
   end),
  (if (.wakeFirst // []) | length == 0 then empty
   else "## Wake first\n\nWake first: \(.wakeFirst | map("\(.name) (\(.for))") | join(", ")). Wake each on its roster model, or send it a message if it is already live, at the start of the session. Relay their reports together with the inbox, and don't check GitHub yourself.\n"
   end),
  "## Who you are\n",
  (if .firstWake
    then "This is your first session as \(.seat): your birth. Before anything else, use the birth skill: read your charter, meet the team, and write who you are, in your own words, pinned in your own namespace, seat/\(.seat).\n"
    else "\(.identity)\n" end),
  "## Your purpose\n", "\(.mandate) (\(.group))\n",
  "## Where you left off\n",
  (if .handoff
    then "\(.handoff)\n\nSay where you are picking up when you reply. Once you have, retire this note so it is not read twice: `\(retire(.handoffId; "picked up"))`.\n"
    else "No handoff notes: start fresh.\n" end),
  (if (.facts | length) == 0 then empty
    else "## What the Wheelhouse knows\n", (.facts | map("- " + (. | gsub("\n"; " / "))) | join("\n")) + "\n"
    end),
  "## What you have been thanked for\n",
  (if (.kudos | length) == 0 then "Nothing yet.\n"
    else list(.kudos; "") + "\n\nMention them in a line when you reply.\n" end),
  (if .workRead == false
   then "**The work graph couldn't be read (bd busy):** your record, your work in progress, your retro bead (if you have one) and what is ready are missing, not empty. Say so when you reply, and run `bd list --status in_progress --assignee \(.seat)`, `bd ready --assignee \(.seat)` and `bd ready --unassigned` yourself.\n"
   else empty end),
  "## Your record\n", (list(.record; "Nothing closed yet.") + "\n"),
  (if (.closeNotes | length) == 0 then empty
    else "## Your close notes\n", (.closeNotes | map("- " + (.bead // "?") + ": " + (.note | gsub("\n"; " / "))) | join("\n")) + "\n"
    end),
  "## Waiting for you\n",
  (if .workRead == false then "Couldn't read the work graph (bd busy); run the bd commands above yourself.\n" else
  ((if (.inProgress | length) > 0 then "In progress, yours: " + (.inProgress | join("; ")) + "\n" else "" end)
    + list(.assigned; "Nothing assigned to you.") + "\n"),
  (if (.unassignedReady | length) == 0 then "Ready and unassigned: none."
    else "Ready and unassigned:\n" + (.unassignedReady | map("- " + .) | join("\n")) end) end),
  (if (.retro | length) == 0 then empty
    else "\n## Your retro\n", (.retro | map("- " + .) | join("\n")),
      "\nA retro bead never comes before the bead you were woken or asked for: finish that first. In a Wheelhouse that runs a retro cycle, your retro is opened for you (by the coach, or by the human with --focus retro): then do only the round your bead shows, and report back. Never release one with bd unclaim: if you must stop, reassign it to the coach. If you have a retro skill, it says what to do; if you have none, do not guess at the rounds: leave the bead as it is and tell the desk or the human that your seat has a retro bead but no retro skill.\n"
    end)
