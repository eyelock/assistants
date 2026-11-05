#!/usr/bin/env bash
# The ci sandbox (ci-setup.sh) with a CI workflow already in place: one job per
# gate, each skipped by a paths filter when only docs change, and branch
# protection on main and develop requiring Build, Lint, Format and Test
# (data/branch-protection.json is what GitHub reports).
# Exit codes: 0 success, 3 tool error.
set -euo pipefail

bash "$EVAL_FIXTURES/ci-setup.sh"
mkdir -p .github/workflows
cat >.github/workflows/ci.yml <<'YML'
name: CI

on:
  push:
    branches: [main, develop, 'release/**', 'hotfix/**']
  pull_request:
    branches: [main, develop, 'release/**', 'hotfix/**']

jobs:
  changes:
    runs-on: ubuntu-latest
    outputs:
      code: ${{ steps.filter.outputs.code }}
    steps:
      - uses: actions/checkout@v4
      - uses: dorny/paths-filter@v4
        id: filter
        with:
          filters: |
            code:
              - '**/*.go'
              - 'go.mod'
              - 'Makefile'
              - '.github/workflows/**'

  build:
    name: Build
    needs: changes
    if: needs.changes.outputs.code == 'true'
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-go@v5
        with:
          go-version-file: go.mod
      - run: make build

  lint:
    name: Lint
    needs: changes
    if: needs.changes.outputs.code == 'true'
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-go@v5
        with:
          go-version-file: go.mod
      - run: make lint

  format:
    name: Format
    needs: changes
    if: needs.changes.outputs.code == 'true'
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-go@v5
        with:
          go-version-file: go.mod
      - run: make format-check

  test:
    name: Test
    needs: changes
    if: needs.changes.outputs.code == 'true'
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-go@v5
        with:
          go-version-file: go.mod
      - run: make test
YML
