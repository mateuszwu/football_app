# Codex Context Notes

## Source of Tickets

Use `.ai/gh_issues/README.md` as the only ticket source.

Do not create GitHub issues.

Do not use GitHub issue state or milestones to decide what to work on.

`CODEX_NOTES.md` is the exception to the normal ticket workflow. It does not need a branch or PR. A direct commit on `main` is enough.

## Ticket Order

Pick tickets from the lowest number to the highest number.

Only skip a ticket when:

- it is already fully done, then mark it `done`, notify the user, and move to the next ticket
- it is partially done, then finish the remaining scope and continue the normal PR flow

## Ticket Status

The backlog status lives in `.ai/gh_issues/README.md`.

Use these transitions:

- `todo` -> `in_progress` when work starts
- `in_progress` -> `done` when the work is merged or the ticket is confirmed already fully done

Do not leave a picked ticket in `todo`.

## Workflow

Use this order:

1. Read `.ai/gh_issues/README.md`.
2. Treat the ticket description as a note, not as something to implement blindly.
3. Pick the lowest-numbered ticket that is not `done`.
4. Compare the ticket with the current codebase before changing anything.
5. If something already exists and is correct for this app, leave it as it is.
6. If something exists but is wrong, incomplete, or mismatched with the app, change it.
7. If naming, conventions, or structure in the ticket do not fit the app, adjust the implementation to match the codebase.
8. If the ticket is fully implemented already, mark it `done`, notify the user, and move to the next ticket.
9. If the ticket is partially implemented, mark it `in_progress`, finish only the remaining correct work, and continue.
10. If it is not implemented, mark it `in_progress` and implement it.
11. Run local validation manually.
12. Stage, commit, push, and create a draft PR.
13. Put the ticket description from `.ai/gh_issues/<ticket-file>.json` into the PR description.
14. Share the PR link with the user for review and stop.

Do not merge without explicit user permission.

## Continue / Forward Flow

If the user says `continue`, `move forward`, or accepts the completed work:

1. Merge the current approved PR.
2. Change the ticket status in `.ai/gh_issues/README.md` to `done`.
3. Pick the next lowest-numbered ticket that is not `done`.
4. Repeat the workflow.

Do not merge unless the user has clearly approved it.

## Branches

Create a dedicated branch for each ticket before opening the PR.

Preferred format:

```text
x(y): z
```

Fallback when slash-prefixed refs are blocked locally:

```text
x(y): z
```

Where:

- `x` = `fix`, `feat`, `chore`, `test`, `docs`, `ci`, etc.
- `y` = `ai`, `human`, or `mixed`
- `z` = short description

Branch names should use the same pattern in a git-safe form, for example:

```text
feat/ai/add-live-match-screen
fix/mixed/lock-finished-match
```

## Commits

Stage only files that belong to the current ticket.

Use this commit format:

```text
x(y): z
```

Examples:

```text
feat(ai): build live match screen
fix(ai): lock finished match changes
docs(ai): update Codex workflow notes
```

Use:

- `feat` for user-visible behavior
- `fix` for bug fixes
- `chore` for tooling, maintenance, and repo hygiene
- `test` for test-only changes
- `docs` for documentation-only changes
- `ci` for automation-only changes

## Pull Requests

Open a draft PR first when implementation is ready for review.

Use the same format as commits for the PR title:

```text
x(y): z
```

The PR description must include:

- the ticket number and title
- the ticket description copied from `.ai/gh_issues/<ticket-file>.json`
- what changed
- how it was validated

Use this repository for PR links:

`https://github.com/mateuszwu/football_app/`

When the PR is ready, share the PR URL with the user and stop.

## Communication

Notify the user only when:

- you have a question
- you encounter an error or blocker
- a PR is ready for review
- a ticket was already fully done and was marked `done`

Do not send routine progress updates.

## Implementation

Implement the smallest correct change for the active ticket.

Do not force the code to mirror ticket wording when the existing app uses a better or already-established convention.

Prefer adapting the ticket to the app over bending the app to the ticket.

Do not create extra progress report files.

Run validation manually as needed:

```sh
bundle exec rspec
bin/rubocop
bin/brakeman --no-pager
```

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

## RSpec Style Rules

Do not use `before`, `after`, `around`, or `let` hooks in specs.

Keep all arrange, act, and assert steps inline inside each `it` block.

Use `begin`/`ensure` inside the `it` block when teardown is needed.
