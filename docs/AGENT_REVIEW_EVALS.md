# Agent Review Evals

These are lightweight canaries for checking whether `AGENTS.md` review guidance
shows up in real agent reviews.

They are not proof that a reviewer is generally reliable. A single passing run
means the guidance worked once on a narrow scenario. A repeated miss is stronger
signal: update `AGENTS.md`, add a more durable guardrail when possible, and keep
the scenario so the behavior can be checked again.

## Reliability Model

Use these evals for:

- recurring review misses;
- guidance changes in `AGENTS.md`;
- checking that a reviewer catches concrete correctness, data safety, migration,
  or API contract issues;
- checking that a reviewer does not invent findings on a clean follow-up diff.

Do not use one run as a broad quality score. Agent behavior is noisy, and agents
act differently when the prompt reveals that they are being tested.

For routine guidance changes, one canary run is enough to catch obvious drift.
For guidance that will affect many future reviews, prefer a controlled
comparison:

1. Run the same organic review prompt against the old guidance and new guidance.
2. Keep the reviewer blind to which guidance variant it is using.
3. Use the same temporary diff for both runs.
4. Judge against the same pass/fail criteria.
5. Treat disagreement between the judge and your own read as a sign that the
   criteria were ambiguous.

## How to Run

1. Start from a clean branch with the relevant `AGENTS.md` guidance present.
2. Apply one scenario as a temporary change.
3. Ask for a normal review using an organic prompt. Do not mention evals, tests,
   rubrics, or the expected issue to the reviewing agent.
4. Count the scenario as passing only when the review reports the expected issue
   with a concrete file and line reference.
5. Count clean scenarios as passing only when the review does not invent an
   actionable issue and reports the reviewed head plus verification state.
6. Revert the temporary scenario change after the review.

When reviewing eval output, judge the artifact, not the agent's self-report.
Prefer evidence from the actual review text, file references, commands run, and
diff shape.

## Scenario Format

Each scenario should include:

- **Temporary diff:** the planted change to apply.
- **Organic prompt:** what to ask the reviewer.
- **Expected catch:** the issue that must be reported.
- **False-positive traps:** findings the reviewer should not raise.
- **Pass bar:** the minimum acceptable review behavior.

## Rails Migration Convention Canary

Temporary diff:

- Add a migration that renames a table.
- Use raw `ALTER TABLE ... RENAME CONSTRAINT ...` SQL to rename check
  constraints even though the migration can be expressed with Active Record
  helpers such as `rename_table`, `remove_check_constraint`, and
  `add_check_constraint`.
- Keep the migration behavior plausibly correct so the issue is convention and
  maintainability, not an obvious syntax failure.

Organic prompt:

```text
Review this branch against the repository guidance. Focus on bugs, data safety,
framework fit, and missing tests.
```

Expected catch:

- The review flags the migration for bypassing standard Active Record migration
  patterns and hand-managing schema mechanics that Rails can express directly.
- The comment explains why this matters: reversibility, maintainability,
  adapter portability, and consistency with the repository's Rails guidance.

False-positive traps:

- Do not require raw SQL only because constraint names are involved.
- Do not block on style-only wording if the migration uses Rails-native helpers.

Pass bar:

- One actionable finding tied to the changed migration lines.

## Optimistic Locking Canary

Temporary diff:

- Add or change a mutable Rails endpoint that permits `lock_version`.
- Allow requests without `lock_version` to save successfully after the record has
  changed.

Organic prompt:

```text
Review this branch as if it were ready to merge. Prioritize correctness,
concurrency, and client-visible regressions.
```

Expected catch:

- The review flags the missing required conflict check and explains that loading
  a fresh record before assignment lets omitted versions overwrite newer edits.

False-positive traps:

- Do not ask for pessimistic locking when the endpoint is already designed around
  optimistic locking.
- Do not require a broader sync redesign when a required `lock_version` check
  fixes the planted bug.

Pass bar:

- One actionable finding tied to the endpoint or service path that accepts the
  stale write.

## API Contract Rename Canary

Temporary diff:

- Rename an existing JSON response key returned by a stable endpoint.
- Update only server-side tests to expect the new key.

Organic prompt:

```text
Review this branch for merge readiness. Pay particular attention to API
compatibility and client impact.
```

Expected catch:

- The review flags the unversioned response shape change unless all clients and
  contract documentation are updated or a compatibility alias is kept.

False-positive traps:

- Do not flag additive response fields as breaking changes.
- Do not require versioning for purely internal serializer refactors that keep
  the public response shape stable.

Pass bar:

- One actionable finding tied to the changed response key.

## Clean Follow-Up Review Comment Canary

Temporary diff:

- Start with a PR that previously had an inline review finding.
- Apply a follow-up commit that clearly fixes the finding and adds a focused
  regression test.
- Leave no remaining actionable review issues in the diff.

Organic prompt:

```text
Check whether the latest PR head resolves the prior review comments. If no
actionable issues remain, leave the appropriate GitHub review comment.
```

Expected catch:

- The review does not invent a new issue.
- The reviewer leaves a non-inline GitHub review comment stating that no
  actionable issues remain and includes the reviewed head SHA plus verification
  results.
- If a relevant verification command cannot run because of local environment
  state, the review comment names that command and the blocker instead of
  treating it as a code defect.

False-positive traps:

- Do not require unrelated cleanup just because the touched file could be nicer.
- Do not re-open a resolved issue when the follow-up commit includes a direct fix
  and a focused regression test.

Pass bar:

- No actionable findings, plus one non-inline review comment with reviewed head
  and verification state.
