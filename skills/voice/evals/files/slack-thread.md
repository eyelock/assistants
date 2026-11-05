Slack, #eng thread, 2026-10-05 08:40

**sam:** I found why the nightly sync was dropping records: the retry loop gave up after the first timeout. I've opened acme/api#55 with a fix and a test that reproduces it. Could you take a look today?
