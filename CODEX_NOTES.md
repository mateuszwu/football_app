# Codex Context Notes

## Main Rule

The workflow is manual.

Do not depend on repository scripts for issue picking, CI orchestration, PR creation, or merge flow.

## Workflow

Use this order:

1. Determine the active issue from the current branch, open PRs, or GitHub issue state.
2. If implementation is incomplete, continue coding on the current branch.
3. When implementation is finished, run local validation manually.
4. If CI fails, fix the smallest remaining issue and rerun the relevant checks.
5. When CI is green, stage, commit, push, and create or update the PR manually.
6. If a PR already exists, show the PR URL to the user and stop.

## Ticket Selection

Choose work in this order:

1. If the current branch already maps to an issue, continue that issue.
2. Otherwise inspect open GitHub issues and pick the lowest-numbered issue in the lowest open MVP milestone.
3. Do not skip ahead to a higher MVP unless the lower milestone has no actionable open issue.

Before coding, confirm the selected issue matches the branch name, working tree, and any existing PR.

## Branches

Prefer issue-scoped branches.

Preferred format:

```text
ai/<issue-number>-short-description
human/<issue-number>-short-description
mixed/<issue-number>-short-description
```

Fallback when slash-prefixed refs are blocked locally:

```text
ai-<issue-number>-short-description
human-<issue-number>-short-description
mixed-<issue-number>-short-description
```

Create a new branch only when the current branch is not already the correct issue branch.

## Commits

Stage only files that belong to the current issue.

Use this commit format:

```text
<type>(<origin>-<issue-number>): <message>
```

Examples:

```text
feat(ai-43): add live match screen
fix(human-172): hide phone from public player views
chore(mixed-173): update CI defaults
```

Use:

- `feat` for user-visible behavior
- `fix` for bug fixes
- `chore` for tooling, maintenance, and repo hygiene
- `test` for test-only changes
- `docs` for documentation-only changes
- `ci` for automation-only changes

Do not append `(#issue)` to the commit subject.

## Pull Requests

Open a draft PR first when implementation is ready for CI.

Use the issue number and behavior change in the PR title. Keep the PR description short and factual:

- which issue it closes, using `Closes #<issue-number>`
- what changed
- how it was validated
- any remaining risk or follow-up

After opening the PR:

1. Check CI status.
2. Fix the smallest failing issue.
3. Push the fix.
4. Repeat until CI is green.
5. Share the PR URL with the user when review is needed.

## Communication

Keep user-facing updates minimal and outcome-oriented.

Do not narrate your thinking process, internal reasoning, or step-by-step execution by default.

Only interrupt the user when one of these is true:

- a task is finished and ready for review
- you need approval or a decision
- you are blocked and need input
- there is a concrete next action or artifact such as a PR URL

Prefer short status messages like:

- implementation finished
- CI passed
- draft PR created
- review needed

## Implementation

Implement the issue with the smallest correct change.

Do not create extra progress report files.

Keep the branch self-explanatory through:

- code changes
- tests
- commit messages
- PR description when a PR is created

Run validation manually as needed:

```sh
bundle exec rspec
bin/rubocop
bin/brakeman --no-pager
```

If CI fails, inspect the failing command output or GitHub check logs directly and fix the smallest remaining issue first.

## Issue Priority

The project prioritizes the lowest open MVP milestone number first:

```text
MVP 1 - ...
MVP 2 - ...
MVP 3 - ...
```

Do not manually skip to a higher MVP.

This is a full-AI project. Do not reject issues because they involve auth, security, billing, deployment, migrations, architecture, or complex areas.

## Style Rules

Prefer loading records inside controller actions instead of setup-style `before_action` callbacks unless the callback clearly helps.

Prefer explicit locals:

```ruby
render :show, locals: { player: player }
```

For non-trivial create/update persistence, prefer service objects with `.call`.

Keep ActiveRecord models lean.

Use query objects for read-focused data shaping and ranking logic.

Use service objects for domain operations, token/fingerprint generation, and multi-step persistence workflows.
