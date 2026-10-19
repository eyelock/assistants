---
"@eyelock-assistants/media-management": minor
---

Rip audio CDs and repair bad imports. The new `rip-cd` skill identifies a disc on MusicBrainz from its table of contents, rips it securely with cd-paranoia, verifies it against AccurateRip, and makes tagged MP3 320s (for Apple Music) and WAVs (for the NAS) from the one verified rip, with every disc of a set in one album. The new `audit-release` skill checks an album against a finished import, finds albums Apple Music split per disc, and merges, retitles, re-covers or replaces them in place, with a plan shown first and an undo. Also: temporary work goes to `$TMPDIR/media-management`, multi-disc WAV archives verify correctly and keep `1-01` names, `import-mp3s.sh --wait` confirms Apple Music picked files up, and setup reports `cd_read_offset` and `work_dir` as optional.
