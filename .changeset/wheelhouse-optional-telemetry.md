---
"@eyelock-assistants/wheelhouse": minor
---

`create-wheelhouse` gains an optional telemetry step, asked only when ynr is installed and taken only on a clear yes, and `scripts/telemetry.sh` to set it up later. `init` picks a free relay port, creates the relay's HMAC key (32 random bytes, mode 0600, in a private folder under `$YNH_HOME`, never in the repository or the spool, never printed) and records only the port under `telemetry` in `wheelhouse.json`; `start` runs `ynr relay` in the foreground on the loopback (no daemon), `stop` ends it, `show` reports the state, and `endpoint` and `configure-ynh` give the human ynh's `YNH_TELEMETRY_RELAY_ENDPOINT` setting. A Wheelhouse without ynr, or that says no, changes nothing. The doctor's telemetry checks come separately.
