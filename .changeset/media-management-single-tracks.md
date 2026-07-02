---
"@eyelock-assistants/media-management": minor
---

Add support for single-track purchases that download as loose MP3/WAV files with no ZIP wrapper. `find-releases.sh` now scans Downloads for loose audio files alongside ZIPs and pairs them the same way (`Track.mp3` + `Track.wav` → one release), via a new `inspect-audio-file.sh`; release entries now report `mp3_source`/`wav_source` with a `source_type` of `"zip"` or `"file"` (renamed from `mp3_zip`/`wav_zip`, which assumed a ZIP). `process-album` gained a `copy-file.sh` script so it can place a loose file into the working folder instead of extracting a ZIP. `cleanup`'s `find-release-artifacts.sh`/`cleanup-release.sh` now also find and archive loose audio files to `processed/`.

Also fixed a latent bug in `find-release-artifacts.sh`: its glob-matching subshells ran under `set -e`, so a non-matching `ls`/`[[ -d ]]` glob (e.g. no `-2` suffix ZIP, or no separate `-wav` extraction folder — the common case for a solo release) silently aborted the subshell and dropped every pattern checked after it. Every glob attempt now ends in `|| true`.
