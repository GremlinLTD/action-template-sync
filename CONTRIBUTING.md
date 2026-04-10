# Contributing

## Setup

```sh
git clone https://github.com/gremlinltd/action-template-sync.git
cd action-template-sync
```

Install bats for running tests:

```sh
brew install bats-core  # macOS
# or
sudo apt-get install bats  # Ubuntu/Debian
```

## Commits

We use [Conventional Commits](https://www.conventionalcommits.org/). Commit messages look like this:

```
type(optional scope): description
```

Types and what they do on merge to main:

| Type        | Version bump | Example                                   |
| ----------- | ------------ | ----------------------------------------- |
| `fix:`      | patch        | `fix: handle missing manifest gracefully` |
| `feat:`     | minor        | `feat: add dry-run mode`                  |
| `feat!:`    | major        | `feat!: change manifest format`           |
| `chore:`    | patch        | `chore: update dependencies`              |
| `docs:`     | patch        | `docs: improve usage examples`            |
| `refactor:` | patch        | `refactor: simplify file comparison`      |
| `test:`     | patch        | `test: add edge case tests`               |
| `ci:`       | patch        | `ci: pin action versions`                 |

## Branching

We use Gitflow:

- `main` - releases, never commit directly
- `develop` - integration branch
- `feature/<name>` - new features
- `bugfix/<name>` - bug fixes
- `hotfix/<name>` - urgent fixes off main
- `release/<name>` - release prep

## Testing

```sh
shellcheck scripts/*.sh
bats tests/
```

Both need to pass before we merge.

## Pull requests

- Fill out the PR template
- Keep changes focused, one thing per PR
- Commit messages drive the changelog and version bumps, so keep them conventional
