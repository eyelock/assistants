---
"@eyelock-assistants/wheelhouse": patch
---

CI has one required check, All Clear, which needs Check and SkillSpector and fails on any failed, cancelled or skipped job. CI also runs on `merge_group` for the merge queue, push runs on develop and main are no longer cancelled, and the SkillSpector action is pinned by commit.
