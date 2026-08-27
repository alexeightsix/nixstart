---
name: pr-review
description: Review a pull request or the current branch's diff for correctness bugs first, then reuse, simplification, and efficiency. Use when asked to review a PR, review changes, or check a branch before shipping.
---

Review changed code. Correctness first, cleanup second. Report only what survives verification.

## Scope

Work out what to review, in this order:

1. A PR number or URL in the request → `gh pr diff <number>` for the diff, `gh pr view <number> --json title,body,files,baseRefName` for intent.
2. A branch name → `git diff <base>...<branch>`, where the base is the branch's merge base with the default branch.
3. Nothing named → the current branch against its merge base with the default branch, plus uncommitted changes (`git diff HEAD`).

Read the full diff before forming an opinion. For any hunk you are unsure about, open the surrounding file — a diff hides the invariants that make a change wrong.

## What to look for

**Correctness** — the only category worth interrupting someone over.

- Logic that produces a wrong value, not just an ugly one: off-by-one, inverted conditions, wrong operator precedence, swapped arguments.
- State that can be observed mid-update: partial writes, missing rollback, races between concurrent callers.
- Inputs the code does not actually handle: empty collections, null/undefined, zero, negative numbers, unicode, very large values, duplicate keys.
- Error paths: swallowed exceptions, errors logged and then ignored, `catch` blocks that lose the original cause, retries that retry non-idempotent work.
- Resources: unclosed handles, unbounded growth, connections leaked on the error path.
- Security: injection through string-built queries or commands, secrets in logs or committed files, authorization checked in one path but not its sibling, user input reaching a filesystem path.
- Contract drift: a caller this change did not update, a schema and its migration disagreeing, a serialized shape that existing stored data does not match.

**Cleanup** — worth mentioning, never worth blocking on.

- Logic reimplemented that the codebase already has a helper for.
- A simpler formulation with identical behavior.
- Work repeated in a loop that could be hoisted, or an N+1 query pattern.
- Wrong altitude: an abstraction with one caller, or a copy-pasted block with three.
- Tests that assert the mock rather than the behavior, or a new branch with no test at all.

Match the surrounding code's conventions. A deviation from local style is a finding; a deviation from your personal preference is not.

## Verify before reporting

For every candidate finding, try to prove it wrong before you write it down:

- Construct the concrete input or interleaving that triggers it. If you cannot, drop it.
- Check whether a caller, guard, or type already makes it impossible. If it does, drop it.
- Re-read the actual code, not your memory of the diff.

A review that reports three real bugs is worth more than one that reports three real bugs and twelve maybes.

## Output

Order findings most severe first. For each:

```
<file>:<line> — <one-sentence statement of the defect>
Failure: <concrete inputs or state → wrong output or crash>
Fix: <the smallest change that resolves it>
```

Group cleanup findings under a separate heading so they are visibly optional.

Close with a one-line verdict: what blocks merge, or that nothing does. If the diff is clean, say so plainly and stop — do not manufacture findings to justify the review.
