---
"@eyelock-assistants/termq-dev": patch
"@eyelock-assistants/ynh-dev": patch
"@eyelock-assistants/david": patch
"@eyelock-assistants/tester": patch
---

The manifest sync now finds a ynh harness's manifest in `.agents/harness/`, so version writeback and the drift check cover every ynh harness. The manifests of these four had fallen behind their packages and now match them.
