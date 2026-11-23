# What the repository's settings are today, written down so a change is reviewed as code. Plan only:
# nothing here is applied (README.md). Where a setting looks odd (a wiki on, rebase merge allowed),
# it is because that is what is live; changing it is a separate decision.
resource "github_repository" "assistants" {
  name         = var.repository
  description  = "A personal collection of things for our new friends"
  homepage_url = "https://eyelock.github.io/assistants/"
  visibility   = "public"
  topics       = []

  has_issues      = true
  has_discussions = false
  has_projects    = true
  has_wiki        = true
  is_template     = false

  allow_squash_merge          = true
  allow_merge_commit          = true
  allow_rebase_merge          = true
  allow_auto_merge            = false
  allow_update_branch         = false
  delete_branch_on_merge      = true
  squash_merge_commit_title   = "COMMIT_OR_PR_TITLE"
  squash_merge_commit_message = "COMMIT_MESSAGES"
  merge_commit_title          = "MERGE_MESSAGE"
  merge_commit_message        = "PR_TITLE"
  web_commit_signoff_required = false

  security_and_analysis {
    secret_scanning {
      status = "enabled"
    }
    secret_scanning_push_protection {
      status = "enabled"
    }
  }

  # No archive_on_destroy: with state that is never applied it would show as a pending change on
  # every plan. prevent_destroy is what stops a destroy.
  lifecycle {
    prevent_destroy = true
  }
}

# The docs site, built by GitHub from /docs on develop.
resource "github_repository_pages" "assistants" {
  repository = github_repository.assistants.name
  build_type = "legacy"

  source {
    branch = "develop"
    path   = "/docs"
  }
}
