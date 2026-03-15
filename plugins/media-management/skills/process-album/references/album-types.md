# Album Type Classification

## Single Artist

All tracks have the same artist.

**Metadata actions:**
- Clear Album Artist field (remove TPE2)
- Do NOT set compilation flag
- Each track's Artist field stays as-is

**Detection:** Count unique artist values across all tracks. If exactly 1 unique artist → Single Artist.

## Collaboration

Exactly two artists appear across the tracks.

**Metadata actions:**
- Set Album Artist to the primary/most-frequent artist
- Do NOT set compilation flag
- Each track keeps its own Artist value

**Detection:** Count unique artist values. If exactly 2 → Collaboration. Ask user to confirm which is primary.

## Compilation

Three or more different artists across tracks.

**Metadata actions:**
- Set Album Artist to "Various Artists"
- Set compilation flag = true (TCMP=1)
- Each track keeps its own individual Artist value

**Detection:** Count unique artist values. If 3+ → Compilation. Confirm with user before applying.
