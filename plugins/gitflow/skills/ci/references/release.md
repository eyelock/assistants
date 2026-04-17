# Release Workflow

Triggers on `v*` tags. The key pattern is a **CI verification gate** before the build runs — this ensures releases never ship from a commit that didn't pass CI.

## Trigger

```yaml
on:
  push:
    tags:
      - 'v*'
  workflow_dispatch:
    inputs:
      tag:
        description: 'Tag to release (e.g., v1.2.3)'
        required: true
        type: string
```

`workflow_dispatch` allows re-running a release for a specific tag without re-tagging.

## Job 1: Verify CI

Before building anything, confirm CI passed on the tagged commit. For pre-releases (`alpha`, `beta`, `rc`), skip the check to allow faster iteration.

```yaml
verify-ci:
  name: Verify CI Passed
  runs-on: ubuntu-latest
  outputs:
    tag: ${{ steps.get-tag.outputs.tag }}
    sha: ${{ steps.get-tag.outputs.sha }}
  steps:
    - name: Resolve tag to commit SHA
      id: get-tag
      env:
        GH_TOKEN: ${{ github.token }}
      run: |
        TAG="${GITHUB_REF#refs/tags/}"
        # Dereference annotated tags to their commit SHA
        TAG_REF=$(gh api repos/${{ github.repository }}/git/refs/tags/$TAG)
        TYPE=$(echo "$TAG_REF" | jq -r '.object.type')
        if [ "$TYPE" = "tag" ]; then
          SHA=$(gh api repos/${{ github.repository }}/git/tags/$(echo "$TAG_REF" | jq -r '.object.sha') --jq '.object.sha')
        else
          SHA=$(echo "$TAG_REF" | jq -r '.object.sha')
        fi
        echo "tag=$TAG" >> $GITHUB_OUTPUT
        echo "sha=$SHA" >> $GITHUB_OUTPUT

    - name: Check CI status
      env:
        GH_TOKEN: ${{ github.token }}
      run: |
        TAG="${{ steps.get-tag.outputs.tag }}"
        SHA="${{ steps.get-tag.outputs.sha }}"

        # Skip for pre-releases
        if [[ "$TAG" =~ (alpha|beta|rc) ]]; then
          echo "⏭️ Skipping CI verification for pre-release"
          exit 0
        fi

        # Wait up to 5 minutes for a CI run to appear (tag push may race CI trigger)
        for i in {1..30}; do
          RUN_ID=$(gh run list --repo ${{ github.repository }} \
            --commit $SHA --workflow ci.yml \
            --json databaseId --jq '.[0].databaseId' 2>/dev/null || echo "")
          [ -n "$RUN_ID" ] && [ "$RUN_ID" != "null" ] && break
          echo "⏳ Waiting for CI run... ($i/30)"
          sleep 10
        done

        gh run watch "$RUN_ID" --repo ${{ github.repository }} --exit-status
        echo "✅ CI passed"
```

## Job 2: Build and Release

Depends on `verify-ci`. Project-specific: compile, package, sign, publish.

```yaml
build-and-release:
  name: Build and Release
  runs-on: <your-runner>
  needs: verify-ci
  permissions:
    contents: write
  steps:
    - uses: actions/checkout@v4
      with:
        ref: ${{ needs.verify-ci.outputs.tag }}

    # --- project-specific build steps here ---

    - name: Create GitHub Release
      uses: softprops/action-gh-release@v2
      with:
        tag_name: ${{ needs.verify-ci.outputs.tag }}
        prerelease: ${{ contains(needs.verify-ci.outputs.tag, 'alpha') || contains(needs.verify-ci.outputs.tag, 'beta') || contains(needs.verify-ci.outputs.tag, 'rc') }}
        generate_release_notes: true
        files: |
          <your-artifacts>
```

## Pre-release Detection

GitHub marks a release as pre-release when `prerelease: true`. The expression above covers the standard suffixes (`-alpha.N`, `-beta.N`, `-rc.N`). The CI skip uses the same pattern so beta releases can ship fast without a required CI gate.

## Annotated vs Lightweight Tags

Always use annotated tags (`git tag -a`) — they carry a message and are proper git objects. The SHA resolution step above handles both annotated and lightweight tags, but annotated tags are the convention.
