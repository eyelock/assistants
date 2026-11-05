---
"@eyelock-assistants/wheelhouse": patch
---

`inbox.sh` handles odd titles and names. `assign` passes the title with `--title`, so a title starting with `-` is created rather than read as a flag, and, without `--kind`, takes a title with the word "merge" or "review" anywhere in it (such as "Merge: widget #13" or "Please merge widget #13") as a merge or review that needs `--url`. `show --name` makes the human's command from the name in lowercase ASCII (`[a-z0-9][a-z0-9-]*`), and refuses a name with no letter or digit in it.
