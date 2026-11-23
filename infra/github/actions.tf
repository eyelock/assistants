resource "github_actions_repository_permissions" "assistants" {
  repository      = github_repository.assistants.name
  enabled         = true
  allowed_actions = "all"
}

# Live today: workflows get a read-write GITHUB_TOKEN and may approve pull requests. Tightening
# that is a separate decision.
resource "github_workflow_repository_permissions" "assistants" {
  repository                       = github_repository.assistants.name
  default_workflow_permissions     = "write"
  can_approve_pull_request_reviews = true
}

# The environment GitHub Pages deploys through: develop and gh-pages may deploy to it.
resource "github_repository_environment" "github_pages" {
  repository  = github_repository.assistants.name
  environment = "github-pages"

  deployment_branch_policy {
    protected_branches     = false
    custom_branch_policies = true
  }
}

locals {
  # Branch policy ids, from
  # `gh api repos/eyelock/assistants/environments/github-pages/deployment-branch-policies`.
  pages_branch_policies = {
    develop    = "64840623"
    "gh-pages" = "64840622"
  }
}

resource "github_repository_environment_deployment_policy" "github_pages" {
  for_each = local.pages_branch_policies

  repository     = github_repository.assistants.name
  environment    = github_repository_environment.github_pages.environment
  branch_pattern = each.key
}
