# Codex Notes

## Continue Workflow

When the user says "continue", treat it as:

1. Check the current draft PR CI/status.
2. If green and mergeable, mark the PR ready.
3. Merge it.
4. Update local `main`.
5. Pick the next suitable open ticket.
6. Implement it, run checks, push, and open the next draft PR.

## GitHub PR Workflow Commands

Use these commands for the local GitHub workflow:

```sh
git status --short --branch
gh pr view <number> --json state,isDraft,mergeStateStatus,statusCheckRollup,url
gh pr ready <number>
gh pr merge <number> --squash --delete-branch
gh issue list --limit 25
gh issue view <number>
git switch -c ai/<issue-number>-short-description
git add <changed-files>
git commit -m "feat(ai-<issue-number>): short imperative message"
git push -u origin <branch-name>
gh pr create --draft --base main --head <branch-name> --title "feat(ai-<issue-number>): short title" --body "<markdown body>"
```

If `gh pr merge` fails because the PR is still a draft immediately after `gh pr ready`, rerun:

```sh
gh pr view <number> --json isDraft,state,mergeStateStatus,statusCheckRollup
gh pr merge <number> --squash --delete-branch
```

Keep unrelated local files out of the PR. Stage explicit file paths instead of `git add -A` when the worktree has unrelated changes.

## Local Validation Commands

Run these before publishing or merging implementation work:

```sh
bundle exec rspec
bin/rubocop
bin/brakeman --no-pager
```

Focused RSpec runs are useful while developing:

```sh
bundle exec rspec spec/models/season_spec.rb spec/requests/seasons_spec.rb
```

This repo does not use `bin/rails spec` for file-targeted spec runs; use `bundle exec rspec ...`.

## Rails Controller Style

Prefer loading records inside controller actions instead of using setup-style `before_action` callbacks such as `set_player`, unless the callback is clearly buying something more than hiding simple setup.

Prefer rendering views with explicit locals, for example `render :show, locals: { player: player }`, instead of relying on controller instance variables.

For non-trivial create/update persistence in controllers, prefer service objects with a single `.call` entrypoint, for example `CreateMatchDay.call(...)` and `UpdateMatchDay.call(...)`, instead of keeping transaction and association-sync logic inside the controller.
