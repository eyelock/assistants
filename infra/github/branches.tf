# Gitflow: develop is the default branch; main carries releases. Two repository rulesets protect
# them (set by hand from a script in assistants #186; classic branch protection is gone). There is
# no merge_queue block: GitHub refuses one on a personal account (HTTP 422).
resource "github_branch_default" "develop" {
  repository = github_repository.assistants.name
  branch     = "develop"
}

locals {
  protected_branches = {
    main = {
      name = "main branch protection"
    }
    develop = {
      name = "develop branch protection"
    }
  }
}

resource "github_repository_ruleset" "this" {
  for_each = local.protected_branches

  repository  = github_repository.assistants.name
  name        = each.value.name
  target      = "branch"
  enforcement = "active"

  conditions {
    ref_name {
      include = ["refs/heads/${each.key}"]
      exclude = []
    }
  }

  # Repository admins (role 5) bypass through a pull request only.
  bypass_actors {
    actor_id    = 5
    actor_type  = "RepositoryRole"
    bypass_mode = "pull_request"
  }

  rules {
    deletion         = true
    non_fast_forward = true

    pull_request {
      required_approving_review_count   = 0
      dismiss_stale_reviews_on_push     = false
      require_code_owner_review         = false
      require_last_push_approval        = false
      required_review_thread_resolution = false
    }

    required_status_checks {
      strict_required_status_checks_policy = false
      do_not_enforce_on_create             = false

      required_check {
        context = "All Clear"
      }
    }
  }
}
