---
"@eyelock-assistants/wheelhouse": patch
---

The ynh marketplace index lists wheelhouse and the four skills packages that were missing, and `sync-manifests` now keeps every entry's version in step with its package and fails `check` when a package is missing from the ynh index or, for a plugin or skills package, from any of the three vendor indexes (assistants #297).
