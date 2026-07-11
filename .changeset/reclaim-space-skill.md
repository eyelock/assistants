---
"@eyelock-assistants/media-management": minor
---

Add `reclaim-space` skill: reclaim local disk by offloading cloud-backed Apple Music downloads. `audit-library.sh` reports the iCloud-status histogram (cloud-safe vs Ineligible) and the protected "keep" folder's playlists; `build-offload-playlist.sh` creates a snapshot playlist of tracks that are safe to Remove Download — excluding the keep folder, a Grouping prefix, and local-only Kinds (WAV). Includes a reference recipe for the auto-updating Smart Playlist equivalent. Non-destructive: removing downloads stays a deliberate manual step.
