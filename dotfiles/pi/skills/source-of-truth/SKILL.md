---
name: source-of-truth
description: Bootstrap or work a project where the documentation is the specification rather than a description of the code. Sets up a docs site, a requirements ledger, a changelog, and a /docs command. Use when starting a project, when asked to work docs-first, or when changing behaviour that is written down.
---

The documentation is the specification. The code is an attempt at it. When they disagree, **the code is the defect**.

This inverts the usual reflex. You are not writing docs to describe what was built; you are writing down what should be true, then making it true.

## Bootstrapping a project

Run this once, in the project root. Skip any step already done.

**1. A docs site.**

```bash
npx --yes create-docusaurus@latest docs classic --typescript --skip-install
cd docs && npm install && cd ..
```

Strip the boilerplate: delete `blog/`, `docs/tutorial-*`, and `src/pages/index.tsx`. In `docusaurus.config.ts` set `blog: false`, `routeBasePath: '/'`, and give `intro.md` the frontmatter `slug: /` so the site root is the introduction rather than a 404.

Add to `.gitignore`: `docs/node_modules`, `docs/build`, `docs/.docusaurus`.

**2. The three standing pages.**

- `docs/docs/intro.md` — what this project is, and a statement that these docs are the source of truth.
- `docs/docs/requirements.md` — copy `assets/requirements.md` from this skill. The ledger of every request and its status.
- `docs/docs/changelog.md` — dated entries, newest first, each opening with **why**.

**3. The `/docs` command.**

Copy `assets/docs.ts` from this skill to `.pi/extensions/docs.ts`. It is self-contained: it finds the docs site by walking up from the working directory, derives a stable per-project port so several projects can serve at once, and opens a browser. No model call, nothing billed, works offline.

**4. Bind the working order.**

Put the loop below into `.pi/APPEND_SYSTEM.md` so every session in this project inherits it.

## The loop

1. **A request comes in.** Add it to `requirements.md` **now**, as `open`. Not when it is finished.
2. **Check the documentation.** Find the page governing this behaviour and read it. If none exists, that absence is the first thing to fix.
3. **Update the documentation** — if the request changes behaviour. Write what will be true, present tense, as though it already is.
4. **Then change the code** to match what you just wrote.
5. **Verify in the real environment.**
6. **Log the doc change with its reason**, and move the requirement to its resting status.

Step 3 before step 4 is the whole discipline. Writing the page first forces behaviour to be decided rather than discovered, and it surfaces contradictions before any code exists. It also catches divergence for free: write "X appears in the dashboard", find the dashboard has no such thing, and you have located a defect without running anything.

## Tracking requirements

`requirements.md` is append-only. Entries change status; they are never deleted.

- Add the row when the request **arrives**. A requirement that first appears once satisfied is one that can be quietly dropped.
- `done` requires evidence, and the evidence is named in the row. "Written" is not done. Loaded-but-never-exercised is `partial`.
- Record what you **decline** and why. A decision with no record gets re-litigated.
- Split a compound request into one row per independently-succeeding part, or the status lies about half of it.
- Read the file before answering "is everything done". That is what it is for.

## The changelog

Never edit a documentation page without logging it, and always state **why**. What changed is recoverable from version control; why it changed is not, and it is the expensive half.

Group edits sharing one reason under a single dated entry: the reason first, then one line per page describing the behaviour now in force.

## Verification

**Verify with the same mechanism your code uses, in the environment it runs in.** This is where confident work goes wrong, so it earns its own rules.

- **A more forgiving tool is not a verification.** Checking an HTTP server with `curl` proves nothing about code using a raw socket — `curl` retries address families your code does not.
- **Loading is not working.** A headless run proves a module imports. It says nothing about whether output is correct, aligned, or duplicated.
- **Anything that renders must be looked at.** In a terminal UI, capture the pane. Padding, alignment, colour and duplicated indicators are invisible to every assertion and obvious in a capture.
- **Environment assumptions are what bite.** Which loopback address a server binds; whether a symlinked file resolves imports from the link or the target; whether a callback is still valid outside its handler. Test them, do not reason about them.
- **Check a thing exists before answering questions about it.** A question phrased "when we do X" is not evidence X exists.

## Tests

Test the failures that are **silent**. A crash reports itself; a wrong answer does not.

- Logic that gates something — permissions, limits, safety classification — where a wrong "yes" produces no error and no output.
- Parsers where two inputs must never be confused, asserting explicitly that they differ.
- Time and boundary handling, where "worked when I tried it" depends on the hour.
- Anything you just got wrong. A bug that reached a user proves that class is reachable; close it with a test, not with care.

**Structure for testability.** Pure logic belongs in a module importing nothing from the host framework, so tests exercise shipped code. A copy of the logic in the test file is worse than no test: it passes forever while the real thing rots.

End-to-end tests should run the real binaries. Config parses, links resolve, credentials are live, nothing fails to load — these only fail against the real thing.

## Reporting

Say what is done, what is not, and what is blocked, as three separate things.

- **Never report as working something you have not seen work.** If it loads but was not exercised, say exactly that.
- **A request you could not satisfy is not a failure to hide.** "Not exposed by the API — here is what I probed to confirm" is a complete answer.
- **Distinguish "did not do" from "could not do."** They lead to different next steps.
- **When you got something wrong, name the part and move on.** No preamble, no tally.

## The failure this guards against

Work that is confident, plausible, internally consistent, and untrue. Docs written afterwards describe what was built instead of what should exist. Verification with a convenient tool confirms what you hoped. Reports summarise intent rather than outcome.

Every rule here exists because that failure is cheap to produce and expensive to detect.
