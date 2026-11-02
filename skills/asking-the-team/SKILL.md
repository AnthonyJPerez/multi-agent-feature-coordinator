---
name: asking-the-team
description: Use only when your human partner asks to involve the wider team - posting a question to a shared channel or a PR thread and collecting the answers
---

# Asking the Team

## Overview

Sometimes a decision needs people beyond your human partner: another team's
owner, the reviewers, the channel. You draft the question, your human
partner approves the exact text, you post it where the team's stack says,
and you bring the answers back as decisions.

**Core principle:** nothing leaves this machine for a shared space without
your human partner approving the words and the destination.

## 1. Draft

- One question per message. Two sentences of context, the options, your
  recommendation, and the decision deadline if there is one.
- Link the PR, the plan section or the spec - never paste internals the
  audience should not see (secrets, customer data, internal hostnames).
- Name who you need an answer from, if known.

## 2. Approve

Show your human partner the draft and the destination (channel, PR thread,
work item). Post only after an explicit yes. Changes to the text mean
showing it again.

## 3. Post

Where depends on the team stack (`fw config <ID>`):

- **Team chat** (`chat` = teams, slack, discord): read the provider
  reference (C1). Webhook URLs and tokens come from the environment variable
  the config names (`chat.webhook_env`); never write them into files,
  commands you echo, or messages.
- **A PR thread** (H4) - best when the question is about a specific change.
- **The work item** (T4) - best when the answer should stay with the ticket.
- **No chat configured:** offer the PR thread or the work item, or give your
  human partner the text to post themselves.

Note where you posted and when, in `.feature/<ID>/decisions.md` as an open
question.

## 4. Collect

- If the provider can read replies (C2), read them when your human partner
  asks. Otherwise your human partner relays them.
- Summarize the answers back to your human partner; they make the call.
- Record the outcome with `fw log-decision` and, if it changes the plan,
  treat it as a ripple.

## Red Flags

| Thought | Reality |
|---|---|
| "Posting the brief automatically saves time" | Only when asked, text approved. |
| "I'll include the stack trace for context" | Check it for secrets and customer data first, or leave it out. |
| "No reply yet, I'll decide" | The question went out because it was not yours to decide. |
