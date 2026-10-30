---
"@eyelock-assistants/wheelhouse": minor
---

Every seat pushes what it wrote when its session ends. add-seat and create-wheelhouse give each seat, the desk included, an `on_session_end` hook (ynh 0.14.0 or later) that runs `scripts/wake.sh --end`: memory with `ynm sync --no-pull`, the work graph with `bd dolt push`, each skipped without a remote and time-boxed. create-wheelhouse now puts the desk in the roster, so it wakes like the others. The doctor's new "seats push at end" check names the seats without the hook.
