# Auto-updating Smart Playlist recipe

`build-offload-playlist.sh` produces a **snapshot** playlist. Apple's automation
cannot author Smart Playlist *rules*, so for a hands-off, always-current version
build this Smart Playlist by hand once. It then re-evaluates itself forever as
tracks age out of your recency crates.

## Create it

`File → New → Smart Playlist` (⌥⌘N).

Match **all** of the following rules:

1. **Cloud-backed group (nested "any").** On the first rule's right edge, hold
   **⌥ Option** — the `+` button becomes `…`. Click it to add an indented group,
   set its header to **`any`**, and add:
   - `iCloud Status` · `is` · `Matched`
   - `iCloud Status` · `is` · `Uploaded`
   - `iCloud Status` · `is` · `Purchased`
   - `iCloud Status` · `is` · `Apple Music`
2. Back at the top level (outer `+`):
   - `Kind` · `does not contain` · `WAV`  — protects local-only lossless
   - `Grouping` · `does not start with` · `DJ`  — protects active DJ tracks
   - `Playlist` · `is not` · `Crates`  — **pick the folder** in the dropdown;
     this excludes membership in every playlist inside it

Enable **Live updating**, disable **Limit**. Name it (e.g. `Victor the Cleaner`).

## Use it

Open the playlist → **⌘A** → right-click → **Remove Download**. Safe to run on
the whole list: it is a no-op on anything not currently downloaded.

## Sanity checks before mass-removing

- Confirm **Sync Library** is on (`Music → Settings → General`). If off, nothing
  is in the cloud and removing downloads is data loss. Run `audit-library.sh`
  first to verify `cloud_safe` is large and `ineligible` is near zero.
- The track count should be noticeably **less than your full library** — if it
  equals the whole library, the `Playlist is not Crates` rule did not bind to
  the folder; re-pick the folder (not an individual playlist).
- Test on ~50 tracks first; confirm they re-stream before doing ⌘A.
