---
"@eyelock-assistants/wheelhouse": minor
---

Seat models: the roster declares what model each seat starts on, as a vendor-agnostic tier (`fast`, `balanced`, `deep`) on the seat or by group default in `models.groups`, with optional per-vendor overrides (`models`) and a tier-to-model map (`models.tiers`). add-seat gains `scripts/model.sh` to resolve it, and its templates, the dispatcher's, the work-graph's and the desk's launch instructions use it (`--model` for launchers, the Agent tool's `model` for subagents). The starter team puts workers, CI watchers and releasers on `fast`, and designers, reviewers and dispatchers on `deep`. The doctor warns about a seat with no model.
