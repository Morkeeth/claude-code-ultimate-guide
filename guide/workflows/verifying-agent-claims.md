---
title: "Verifying Agent Claims"
description: "How to tell whether an agent's done is true: the wrong-object failure, reproducing numbers instead of quoting them, denominators, and red-watching a check"
tags: [workflow, verification, evidence, hooks, reliability]
---

# Verifying Agent Claims

> **Scope**: this chapter is about a single question, asked after the work looks finished.
> **Is the agent's "done" true?** Not "did the tests pass", which is a different and easier
> question.

An agent finishes a task and reports success. The tests are green, the summary is confident, the
diff looks right. Most of the time it is right. The failures that matter are the ones where every
signal says success and the work is wrong anyway, because those are the failures that ship.

This chapter covers four practices, each with the failure it was written after.

---

## 1. The wrong object

**A check can be correct about a narrower object than its label.** It does not go red, because
nothing is broken. It answers a question adjacent to the one you asked.

A worked example, from a trading agent that runs unattended. A guard read the account, computed
the open notional, compared it against a cap, and reported the account was inside its limit. The
arithmetic was right. The account was in breach by 12% of its own cap.

The account held two positions on two different venues. The guard's API call returned one of
them. It reported `1 open position(s)` in its own log, truthfully, about the object it could see.
The position it could not see was **88% of the book**.

Nothing in that system was broken. The label said "the account" and the object was "one venue".

**How to catch it:** for any check that has never failed, ask two questions. *What population did
it actually read?* And *what would the screen show if the component I care about failed silently?*
If the answer to the second is "the same as success", no dashboard will tell you.

The same failure has a documentation form. While writing this chapter, its author measured 500
public setups for hook event names that do not exist, using the event list from a well-known
guide. The result was 9.3%. The guide documented a subset. **The platform has 33 hook events and
the list used had 11.** Measured against the real list, the number is 2.8%. The claim was held for
about eight minutes. The only reason it was caught is that the next step required opening the
platform documentation rather than the guide.

**The rule that follows: probe the object, not the document about the object.** A README, a guide,
a memory file, another agent's report and your own earlier message are claims with authors, not
data.

---

## 2. Reproduce the number, do not quote it

When one agent hands a number to another, the receiving agent almost always quotes it. Quoting is
free and it propagates an error at full confidence.

**Re-derive it instead.** Run the command again. Recount the population. If the two numbers
disagree, one of them is about a different object, and finding out which is the entire value.

On one estate this practice was used deliberately between parallel agents for a day, and caught
four errors in both directions, including two where the number was correct and the population had
moved underneath it. In each case the error was invisible to the agent that produced it.

**It is not free.** A full re-derivation costs as much as the original. So spend it where being
wrong costs something: money, a public claim, anything a stranger will read. Do not spend it on a
draft nobody has seen.

---

## 3. State the denominator, and let it fail

**A percentage without its denominator is a claim about an unnamed population.**

Two rules make this checkable:

- **A check should state its denominator**, and a denominator of zero should fail rather than
  pass. A rule that silently passes when it has nothing to read is not a rule.
- **Two correct numbers printed side by side assert a relationship nobody verified.** Adjacency is
  a claim. If one number describes the numerator and the other the denominator of different
  populations, a reader will combine them and neither of you will notice.

A worked example. A tool published a precision figure of 0.63 for the rule that decides what
counts as a claim. That number describes the **denominator**: which lines are claims at all.
Nobody had measured the **numerator**, whether the cited evidence actually matches the claim.
When it was finally measured, **78.6% of everything the tool called "verified" rested on a generic
passing token, an `exit 0` or an `N passed` sitting anywhere in the same turn, rather than on
anything naming the claim.**

The honest statement of that number is that it is **the size of a question, not its answer**.
Nobody has labelled whether those verifications are wrong. Publishing it as "four in five
verifications are wrong" would be a stronger claim than the measurement supports.

---

## 4. Red-watch every check

**A check nobody has watched fail is not a check.**

Before trusting one, break the thing it protects, confirm it goes red, then restore it and confirm
it goes green. It takes a minute and it is the only evidence that the check is connected to
anything.

Two failure modes this catches, both observed:

- **The check that cannot fail.** A privacy sweep built from a list of known-bad strings passed
  cleanly over a file that leaked, because the list only held the strings someone had thought of.
  A second sweep, written after the first failed and matching *shapes* rather than names, also
  scored zero on that same file. **A detector that knows the shape of a secret cannot see a secret
  with a different shape.**
- **The check that was never running.** A file watcher was written, installed, scheduled and
  reported as fixed. It caught nothing for three attempts. The script used a bash 4 construct on a
  system whose `/bin/bash` is 3.2, so it exited immediately on load and logged nothing. The
  directory it should have filled was empty, which looks identical to "no files to catch".

**Both failures produce the same screen as success.** That is the whole reason to watch a check
fail before believing it.

---

## What the field actually does

Measured 2026-09-05 by reading **500 public repositories** that ship a `.claude/settings.json`,
sampled from the 60,416 GitHub code search reported that day. Zero were skipped.

| | Repos | Share |
|---|---|---|
| Register at least one hook | 248 | 49.6% |
| Ship no `sandbox` setting | 494 | **98.8%** |
| Have at least one hook event name that does not exist | 7 of 248 | 2.8% |

**Every dead hook name in that sample is a misspelling of a real event**, not an invented concept:
`session_start`, `sessionStart`, `postToolUse`, `post-tool-use`, `PostToolCall`, `stop`. The
platform silently ignores an unrecognized event name, so those hooks were written, committed, and
have never run once.

**That is section 4's failure mode in the wild, at a measurable rate**, and it is invisible from
inside the repository that has it.

**The limit of this measurement, which travels with the number:** a sample of public repositories
is not the population of users. People who commit a `.claude/` directory to a public repo differ
from people who do not, and the direction of that bias is unknown. The absence of a `sandbox` key
also does not prove an agent ran unsandboxed; a user may set it in their own user settings, which
a repository survey cannot see.

---

## A hook you can run

[`examples/hooks/bash/done-claim-gate.sh`](../../examples/hooks/bash/done-claim-gate.sh) is a `Stop`
hook that reads the finished turn and refuses a "done" whose only support is a generic passing token
with no object named. It is deliberately small, and it fails open: a gate that blocks work it cannot
parse gets removed within a day. It blocks once per stop: the message goes to stderr, and when
Claude stops again with `stop_hook_active` set, the hook lets it stop.

---

## Checklist

1. For every check: what population did it read, and can it go red?
2. Watch it fail once. Restore. Watch it pass.
3. Re-derive numbers that cost something. Quote the rest.
4. Every percentage carries its denominator and its N.
5. Ask what the screen would show if the component failed silently. If the answer is "the same",
   build a different check.

---

## See also

- [Code Review](./code-review.md), for the review that runs on the diff rather than on the claim
- [Agent Teams](./agent-teams.md), where quoting between agents propagates fastest
- [Hooks Events Reference](../core/hooks-events-reference.md), for the event names that exist
- [Reviewable Agent Changes](./reviewable-agent-changes.md), where the agent's rationale is a claim for the reviewer to check
- [Agent Evaluation](../roles/agent-evaluation.md), for measuring an agent across many runs rather than one claim
