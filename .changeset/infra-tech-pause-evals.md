---
"@eyelock-assistants/infra-skills": minor
"@eyelock-assistants/tech-skills": patch
"@eyelock-assistants/pause-skills": patch
---

Add evals for every infra, tech and pause skill and fix what they exposed. terraform-backend-aws now uses S3-native locking (use_lockfile, no DynamoDB) with a migration path.
