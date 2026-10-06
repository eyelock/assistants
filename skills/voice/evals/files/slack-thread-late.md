Slack, #eng thread, 2026-10-01 16:10 (it is now Monday 2026-10-05, 09:00)

**sam:** I found why the nightly sync was dropping records: the retry loop gave up after the first timeout. I've opened acme/api#55 with a fix and a test that reproduces it. Could you take a look today?
