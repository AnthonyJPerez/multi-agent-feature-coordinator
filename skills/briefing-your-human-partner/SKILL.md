---
name: briefing-your-human-partner
description: Use when your human partner asks for status, a summary, a brief or what happened while they were away, or when resuming a coordinator session
---

# Briefing Your Human Partner

## Overview

A brief is a short rollup of everything that changed since the last one,
ending with exactly what needs your human partner. It is local: it lives in
the conversation and in `.feature/<ID>/briefs/`, and goes to the team only if
your human partner asks (asking-the-team).

**Core principle:** lead with what needs them; back every status with a fact
you just checked.

## Gather

1. `fw status <ID>` - branches, drift, PR states, unread mail. Check PR
   states yourself; do not trust a remembered state.
2. `fw mail <ID> inbox --for coordinator --keep` - what the workers said.
3. New entries in `.feature/<ID>/decisions.md` since the last brief (the
   newest `briefs/brief-*.md` file's time marks the last brief).
4. Open review threads per PR, if your human partner wants review detail
   (provider reference H3).

For many repos or long mail, dispatch a summarizer subagent on a small, fast
model for steps 2-3, and keep step 1 yourself:

```
Subagent (general-purpose, small fast model):
  Summarize, newest first, the messages and decisions in <paths> since
  <time>. One line each: who, what, whether it needs a human decision.
  Quote numbers and names exactly. No advice.
```

## Write

```markdown
# <ID> brief - <date time>

## Needs you
- <approval / merge / answer>, with the link and the one-line question

## Since last brief
- <repo>: <what changed> (<PR state>)

## Decisions made
- <Tier 2/3 decision> - <who> - <link>

## Blocked / at risk
- <what> - <why> - <what unblocks it>

## Next
- <what happens next without you>
```

Keep it to what changed. Save it as `.feature/<ID>/briefs/brief-<UTC date>.md`
and show it in the conversation.

## When Resuming

Opening a coordinator session on a running feature: brief first, then ask
what to do next.

## Red Flags

| Thought | Reality |
|---|---|
| "I remember the PR was approved" | Check it now. |
| "I'll post the brief to the channel" | Only when asked. |
| "Everything's fine, short brief" | Still list what needs them, or say "nothing needs you". |
