# Codex Notes

## Continue Workflow

When the user says "continue", treat it as:

1. Check the current draft PR CI/status.
2. If green and mergeable, mark the PR ready.
3. Merge it.
4. Update local `main`.
5. Pick the next suitable open ticket.
6. Implement it, run checks, push, and open the next draft PR.

