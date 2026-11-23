# GitHub repository

Terraform for the `eyelock/assistants` repository's settings, so a change to them is read as a plan
before anyone makes it. **Plan only: never `terraform apply`.** Settings are changed by a human,
after the plan is reviewed. State is local and gitignored; no backend and no credential beyond a
GitHub token are needed.

| File | What it describes |
|---|---|
| `repository.tf` | The repository: description, homepage, features, merge options, secret scanning and push protection, and the GitHub Pages site (from `/docs` on `develop`) |
| `branches.tf` | `develop` as the default branch, and a ruleset on each of `main` and `develop`: no deletion or force-push, a pull request required (no approving review), "All Clear" green; repository admins bypass through a pull request only |
| `labels.tf` | Issue and PR labels, authoritatively: a label not listed would be removed on apply |
| `actions.tf` | Actions permissions, the workflow token's permissions, and the `github-pages` environment with its branch policies |
| `imports.tf` | Import blocks that adopt the live repository into a fresh state |

Not described here: anything committed to the repository (`.github/`), and a `merge_queue` block,
which GitHub refuses on a personal account (HTTP 422). The settings are what is live, odd ones
included (wiki on, rebase merge allowed, a read-write workflow token); changing one is a separate
decision. The repository has no Actions secrets, and Dependabot alerts and security updates are off.

## Check for drift

```bash
cd infra/github
export GITHUB_TOKEN="$(gh auth token)"   # in your shell only; never write it to a file
terraform init
terraform plan
```

On a fresh clone the plan shows the eleven imports from `imports.tf` as pending. To fill the local
state without applying anything, run `terraform import` once for each (the `to` and `id` of each
block), then plan again: it must say "No changes". Anything else is drift, or a setting changed
by hand.

`archive_on_destroy` is left out of `repository.tf` on purpose: it is not a GitHub setting, and in a
state that is never applied it would show as a change on every plan. `prevent_destroy` stops a
destroy.
