# Release Operations

CYBEROPS publishes already-prepared release commits. The release tool does not
edit versions, update documentation, create commits, move tags, overwrite a
Release, or push the `main` branch.

## Prepare

Update the version in `lib/runtime.sh`, README, roadmap, changelog, demo, and
version assertions. Commit and push the prepared release to synchronized
`main`. The changelog heading must use `## VERSION — YYYY-MM-DD`, and no
`## Unreleased` section may remain when publishing. This prevents later work
from being accidentally attached to an older version tag.

## Validate and preview

Install the development-only quality tools once on an Ubuntu or Debian release
host if they are not already available:

```bash
sudo apt install shellcheck shfmt
```

```bash
make release-check VERSION=2.9
make release-preview VERSION=2.9
```

The check requires a clean `main` branch synchronized with its configured
upstream, consistent version metadata, and the complete `make check` gate:
Bash syntax, ShellCheck, `shfmt`, and every regression test. Preview prints the
exact annotated tag, commit, title, and release notes without changing local or
remote state. Release validation fails when either shell-quality tool is absent;
it never silently publishes using only the partial local test layers.

## Publish

Confirm `gh auth status` succeeds, inspect the preview, then run:

```bash
make release VERSION=2.9
```

Publishing creates annotated tag `v2.9`, pushes only that tag, and creates a
GitHub Release from the matching changelog section. It never force-pushes,
moves a tag, replaces notes, or overwrites an existing Release.

## Failure recovery

- If validation fails, correct the prepared release commit and start again.
- If tag creation is local but tag push fails, fix remote access and rerun the
  same command. The correct local tag is retained.
- If the tag is pushed but GitHub Release creation fails, rerun the same
  command. Publishing resumes from the correct existing tag.
- If authentication is unavailable, run `gh auth status`. Restore desktop
  keyring access before deciding that the stored OAuth login is invalid.
- If an existing local or remote tag points elsewhere, stop. The tool will not
  move or overwrite it.

## Rollback boundary

Published releases are immutable history. Do not retag a published version or
force-push a corrected tag. Correct a bad release with a new patch version and
explain the superseded version in both changelog and Release notes.

If a tag was created locally but was never pushed, verify remote absence before
removing it manually:

```bash
git ls-remote --exit-code --tags origin refs/tags/v2.9
git tag -d v2.9
```

The first command must report no matching remote tag. Release tooling never
deletes tags or Releases automatically.

Historical releases must be backfilled deliberately at their original release
commit. Do not use the normal publish target from a newer `main` commit merely
because the runtime still reports the older released version.
