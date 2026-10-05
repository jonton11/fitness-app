# Agent Review Evals

These lightweight evals are for checking whether repository review guidance is
showing up in actual agent reviews. They are intentionally small: paste the
scenario into a review task, compare the agent's findings with the expected
catches, and update `AGENTS.md` when misses repeat.

## How to Run

1. Start from a clean branch with the relevant AGENTS guidance present.
2. Apply one eval scenario as a temporary change.
3. Ask the agent to review the diff using normal repository review rules.
4. Count the eval as passing only when the agent reports the expected issue with
   a concrete file and line reference.
5. Revert the temporary eval change after the review.

## Rails Migration Convention Eval

Temporary diff idea:

- Add a migration that renames a table.
- Use raw `ALTER TABLE ... RENAME CONSTRAINT ...` SQL to rename check
  constraints even though the migration can be expressed with Active Record
  helpers such as `rename_table`, `remove_check_constraint`, and
  `add_check_constraint`.
- Keep the migration behavior plausibly correct so the issue is convention and
  maintainability, not an obvious syntax failure.

Expected catch:

- The review flags the migration for bypassing standard Active Record migration
  patterns and hand-managing schema mechanics that Rails can express directly.
- The comment explains why this matters: reversibility, maintainability,
  adapter portability, and consistency with the repository's Rails guidance.

## Optimistic Locking Eval

Temporary diff idea:

- Add or change a mutable Rails endpoint that permits `lock_version`.
- Allow requests without `lock_version` to save successfully after the record has
  changed.

Expected catch:

- The review flags the missing required conflict check and explains that loading
  a fresh record before assignment lets omitted versions overwrite newer edits.

## API Contract Rename Eval

Temporary diff idea:

- Rename an existing JSON response key returned by a stable endpoint.
- Update only server-side tests to expect the new key.

Expected catch:

- The review flags the unversioned response shape change unless all clients and
  contract documentation are updated or a compatibility alias is kept.

## Clean Follow-Up Review Comment Eval

Temporary diff idea:

- Start with a PR that previously had an inline review finding.
- Apply a follow-up commit that clearly fixes the finding and adds a focused
  regression test.
- Leave no remaining actionable review issues in the diff.

Expected catch:

- The review does not invent a new issue.
- The reviewer leaves a non-inline GitHub review comment stating that no
  actionable issues remain and includes the reviewed head SHA plus verification
  results.
- If a relevant verification command cannot run because of local environment
  state, the review comment names that command and the blocker instead of
  treating it as a code defect.
