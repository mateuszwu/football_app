# Codex Context Notes

## Main Rule

When the user says `continue`, run:

```sh
./scripts/codex-continue
```

Then follow the next step printed by the script.

Do not manually choose issues, create branches, run the full CI flow, create PRs, or merge PRs when a dedicated script exists.

Main scripts:

```sh
./scripts/codex-continue
./scripts/codex-pick-next-ticket
./scripts/codex-run-local-ci
./scripts/codex-create-draft-pr
./scripts/codex-merge-reviewed-pr
```

## Workflow

The script `./scripts/codex-continue` determines the current step.

It may:

* merge an existing reviewed PR
* pick the next ticket
* tell Codex to continue implementation
* run local CI
* create a draft PR
* show the PR link

After running a script, follow the printed instructions.

If a draft PR is created, show the PR URL to the user and stop.

## Implementation

When a task is selected, read:

```sh
.ai/codex-task.md
.ai/selected-issue.json
.ai/issue.json
```

Implement the issue with the smallest correct change.

At the end, write:

```sh
.ai/codex-report.md
```

Use this structure:

```md
# Codex report

## Files changed

## Summary

## Tests run

## Test result

## Risks / review notes

## Follow-up notes
```

Then run:

```sh
./scripts/codex-run-local-ci
```

If CI fails, read:

```sh
.ai/ci-summary.md
.ai/codex-next-step.md
```

Fix the smallest remaining issue and rerun CI.

When CI is green, run:

```sh
./scripts/codex-create-draft-pr
```

## Issue Priority

Issue selection is handled by:

```sh
./scripts/codex-pick-next-ticket
```

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
