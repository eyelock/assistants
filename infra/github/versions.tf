terraform {
  required_version = ">= 1.10"

  required_providers {
    github = {
      source  = "integrations/github"
      version = "~> 6.13"
    }
  }

  # State is local and gitignored: this module is for `terraform plan` only (README.md). There is no
  # remote backend and no credential beyond a GitHub token.
}

# The token comes from GITHUB_TOKEN (`export GITHUB_TOKEN="$(gh auth token)"`); never write it to a
# file. Reading these settings needs the repo and workflow scopes.
provider "github" {
  owner = var.owner
}
