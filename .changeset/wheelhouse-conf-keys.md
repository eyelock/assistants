---
"@eyelock-assistants/wheelhouse": minor
---

`wheelhouse.json` gains the keys the rules-as-mechanisms guards and sensors read: `shared_checkouts`, `protected_branches`, `sanctioned_force`, `budgets` and `guards` (`mode` and `overrides`), beside `memory` and `tasks`. `wheelhouse-lib.sh` gains `wl_conf KEY [DIR]`, which returns a key's value or its default when the file or key is missing, and `wl_conf_problems [DIR]`, which names each unknown or malformed key with how to fix it. The doctor checks them (`wheelhouse.json keys`) and errors on a bad file. Nothing specific to one Wheelhouse is in the plugin.
