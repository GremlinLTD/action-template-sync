# action-template-sync

Sync files from a parent template repository to downstream repos via pull request.

## How it works

1. Clones the parent template repo
2. Reads `.sync-manifest.yml` from the template to determine which files to sync
3. Compares template files against local versions
4. If differences exist, opens (or updates) a PR with the changes

## Usage

Add this workflow to any repo that should sync from a template:

```yaml
# .github/workflows/template-sync.yml
name: Template Sync

on:
  schedule:
    - cron: "0 8 * * 1" # Weekly Monday 8 AM
  workflow_dispatch:

permissions:
  contents: write
  pull-requests: write

jobs:
  sync:
    name: Sync from template
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: gremlinltd/action-template-sync@v1
        with:
          template-repo: gremlinltd/template-rust
          token: ${{ secrets.GITHUB_TOKEN }}
```

## Inputs

| Input           | Required | Default         | Description                                                  |
| --------------- | -------- | --------------- | ------------------------------------------------------------ |
| `template-repo` | yes      |                 | Parent template repo (e.g., `gremlinltd/template-rust`)      |
| `template-ref`  | no       | `main`          | Branch or tag to sync from                                   |
| `pr-label`      | no       | `template-sync` | Label for sync PRs                                           |
| `token`         | yes      |                 | GitHub token with `contents:write` and `pull-requests:write` |

## Template manifest

The parent template repo must contain a `.sync-manifest.yml` in its root:

```yaml
files:
  - .github/workflows/stale-prs.yml
  - .github/ISSUE_TEMPLATE/bug_report.yml
  - .github/ISSUE_TEMPLATE/feature_request.yml
  - CONTRIBUTING.md
  - SECURITY.md
  - LICENSE
```

Only files listed in the manifest are synced. Add a new file to the manifest and every downstream repo gets it on next sync.

## Ignoring files

Downstream repos can place a `.sync-ignore` file in their root to skip specific files:

```
# These files are intentionally customized
CONTRIBUTING.md
.github/pull_request_template.md
```

## Behavior

- Uses a fixed branch `chore/template-sync` (force-pushed on each run)
- Opens a single PR per repo, updates it if already open
- Files removed from the manifest are left in place (no automatic deletion)
- Missing template files produce a warning, not a failure
- If all files are in sync, no PR is created

## License

MIT
