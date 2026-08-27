---
title: Requirements
sidebar_position: 2
---

# Requirements

Every request made of this project, and what happened to it. Append-only: entries change status, they are never deleted.

This exists so that "did we do everything?" has an answer that is looked up rather than remembered. Requirements arrive scattered through conversations; without a ledger, the only record is a transcript nobody will re-read.

**Status meanings**

| Status | Means |
| --- | --- |
| `done` | Built **and verified**. The verification is named. |
| `partial` | Some of it works. What is missing is stated. |
| `open` | Accepted, not started. |
| `blocked` | Cannot proceed. The blocker is named, and whose it is. |
| `declined` | Deliberately not doing it. The reason is recorded. |
| `withdrawn` | The requester dropped it. |

`done` requires evidence. "Written" is not `done`. If it loaded but was never exercised, it is `partial`.

## Open

| # | Requirement | Status | Notes |
| --- | --- | --- | --- |
| 1 | _example_ — Export report as CSV | open | Accepted, not started |

## Delivered

| # | Requirement | Status | Verified by |
| --- | --- | --- | --- |
| — | _example_ — Users can reset their password | done | e2e `auth.spec.ts`, checked in a real browser |

## Blocked and declined

| # | Requirement | Status | Reason |
| --- | --- | --- | --- |
| — | _example_ — Show remaining API quota | blocked | Provider exposes no quota field; confirmed by probing the API directly |

## Keeping it honest

- Add the row **when the request arrives**, not when it is finished. A requirement that only appears once satisfied is a requirement that can be quietly forgotten.
- Record requests you decline and why. A decision with no record gets re-litigated.
- Split a request that has parts. One row per thing that can independently succeed or fail, or the status is a lie about half of it.
- Re-read this before answering "is it all done". That is the entire point of the file.
