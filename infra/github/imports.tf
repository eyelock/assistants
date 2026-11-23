# Adopt the live repository into state. On a fresh state these import; once imported they are
# no-ops. No secrets are declared (the repository has none), and vulnerability alerts and Dependabot
# security updates are off, so there is nothing to import for them.
import {
  to = github_repository.assistants
  id = "assistants"
}

import {
  to = github_repository_pages.assistants
  id = "assistants"
}

import {
  to = github_branch_default.develop
  id = "assistants"
}

import {
  to = github_issue_labels.assistants
  id = "assistants"
}

import {
  to = github_actions_repository_permissions.assistants
  id = "assistants"
}

import {
  to = github_workflow_repository_permissions.assistants
  id = "assistants"
}

import {
  to = github_repository_environment.github_pages
  id = "assistants:github-pages"
}

import {
  for_each = local.pages_branch_policies

  to = github_repository_environment_deployment_policy.github_pages[each.key]
  id = "assistants:github-pages:${each.value}"
}

# Set by a script from assistants #186; the ids are the rulesets', from
# `gh api repos/eyelock/assistants/rulesets`.
import {
  to = github_repository_ruleset.this["develop"]
  id = "assistants:26924898"
}

import {
  to = github_repository_ruleset.this["main"]
  id = "assistants:26924900"
}
