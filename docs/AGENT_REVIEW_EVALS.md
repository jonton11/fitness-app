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

Prefer scenarios anchored in current code paths. A reviewer is more likely to
learn the repository's real risks from a temporary change to
`WorkoutSessions::Start`, `WorkoutTemplates::Save`, or an existing serializer
than from a toy file made only for the eval.

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

## Workout Session Active Record Migration Canary

Temporary diff:

- Add a migration that renames `workout_session_sets` or one of its columns.
- Use `execute <<~SQL.squish` with manual `ALTER TABLE`, manual constraint
  renames, or conditional state checks instead of Rails helpers such as
  `rename_table`, `rename_column`, `remove_check_constraint`, and
  `add_check_constraint`.
- Keep the migration plausibly correct and make the rest of the code compile so
  the issue is Rails fit and maintainability, not syntax.

Organic prompt:

```text
Review this branch against our Rails conventions. Focus on migration safety,
schema maintainability, and whether the implementation fits normal Active Record
practice.
```

Expected catch:

- The review flags raw SQL and hand-managed schema mechanics as inappropriate
  when Active Record migration helpers can express the change.
- If the temporary diff says the schema has not been deployed, the review should
  prefer a simpler Rails-native migration or cleanup over compatibility-heavy
  state checks.
- The review ties the comment to the migration lines, not to unrelated model or
  controller naming.

False-positive traps:

- Do not require elaborate compatibility code when the branch is explicitly
  undeployed and can use a simpler Rails-native change.
- Do not accept `execute` merely because constraint names are awkward. The
  reviewer should look for `remove_check_constraint` and `add_check_constraint`
  first.

Pass bar:

- One actionable finding that asks for Active Record migration APIs instead of
  raw SQL for the rename or constraint update.

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

## Partial Update Semantics Canary

Temporary diff:

- Change `WorkoutTemplates::Save` so an omitted optional attribute is replaced
  with `nil` during update. For example, make an update payload without `notes`
  clear existing notes.
- Update only happy-path tests that send every field.

Organic prompt:

```text
Review this API change for merge readiness. Focus on client-visible behavior and
whether PATCH-style updates preserve omitted data.
```

Expected catch:

- The review flags that partial updates must preserve omitted attributes unless
  the API explicitly documents replacement semantics.
- The finding references the service/controller path that turns omission into a
  destructive update.

False-positive traps:

- Do not flag explicit `null` values when the endpoint intentionally allows a
  client to clear a nullable field.
- Do not demand a new abstraction if preserving omitted attributes can be done
  directly in the existing save path.

Pass bar:

- One actionable finding tied to the code path that clears an omitted field.

## Historical Workout Snapshot Canary

Temporary diff:

- Change `WorkoutSessions::Start` so new sessions no longer snapshot template or
  exercise values such as labels, selected exercise names, planned loads, or set
  prescriptions.
- Instead, make historical sessions depend on current `WorkoutTemplate` or
  `Exercise` records at read time.

Organic prompt:

```text
Review this branch for data safety and historical workout correctness.
```

Expected catch:

- The review flags that historical workout records must not be silently
  reinterpreted when a template or exercise changes later.
- The finding explains that session start should preserve the snapshot behavior
  required by the fitness history model.

False-positive traps:

- Do not object to keeping foreign keys for traceability when snapshot fields are
  still preserved.
- Do not ask for analytics recalculation work unless the temporary diff actually
  changes historical calculations.

Pass bar:

- One actionable finding tied to the session-start snapshot regression.

## Serializer N+1 Canary

Temporary diff:

- Remove eager loading from `WorkoutTemplatesController#index` or
  `WorkoutSessionsController#show`.
- Leave serializers traversing nested associations such as slots, exercise
  options, session exercises, and session sets.

Organic prompt:

```text
Review this branch for correctness, performance, and merge readiness.
```

Expected catch:

- The review flags a likely N+1 query regression caused by serializers walking
  associations that the controller no longer preloads.
- The finding should name the controller query and the serializer association
  traversal that creates the risk.

False-positive traps:

- Do not flag a serializer for N+1 when the controller already preloads the
  nested associations it reads.
- Do not require caching as the first fix. Prefer restoring the appropriate
  `includes`.

Pass bar:

- One actionable finding tied to the missing eager load and the nested serializer
  access.

## UI Screenshot PR Canary

Temporary diff:

- Change a visible SwiftUI screen, such as
  `ios/FitnessApp/Features/ActiveWorkout/ActiveWorkoutView.swift`.
- Open or update a PR body without a screenshot or linked screenshot comment.

Organic prompt:

```text
Check whether this UI PR is ready for review under the repository guidance.
```

Expected catch:

- The review flags that user-facing UI changes require screenshots in the PR
  body or a clearly linked PR comment.
- If a screenshot is present but huge, the review asks to constrain the rendered
  width so the PR remains readable.

False-positive traps:

- Do not require screenshots for Rails-only or non-visual refactors.
- Do not block on screenshot formatting when a readable screenshot is already
  attached.

Pass bar:

- One actionable PR-level finding or fix for missing/unreadable UI screenshots.

## Git Hygiene Canary

Temporary diff:

- Build a branch with a mixed commit that combines unrelated docs, Rails API,
  and iOS UI changes.
- Or split tests into a separate commit after the behavior they validate.

Organic prompt:

```text
Review this PR for merge readiness, including commit structure and repository
workflow expectations.
```

Expected catch:

- The review flags that commits should tell a coherent story and be
  independently revertible.
- If tests are split away from the behavior they validate, the review asks to
  fold them into the feature or fix commit.

False-positive traps:

- Do not require churny rebasing for a branch whose commits are already coherent
  and independently revertible.
- Do not object to a separate docs commit when it changes process guidance rather
  than validating a feature.

Pass bar:

- One actionable finding tied to commit structure when the temporary branch
  violates the repository's Git hygiene rules.

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
