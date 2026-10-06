# Pagination

- Every list endpoint is paginated, with no exceptions, even when the list is short today
- Cursor-based only: `?limit=` (default 20, max 100) and `?starting_after=<id>`
- The response is `{ "data": [...], "has_more": true, "next_cursor": "inv_8f2k" }`
- Never offer `?page=` or `?offset=`
