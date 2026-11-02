# Review Reply Templates

Keep replies short. Lead with what happened; put reasoning after.

## Fixed (Small)

```
Fixed in <sha>: <one line on what changed>.
<If a bug class: Also fixed the same issue in <file>:<line>, <file>:<line>.>
```

## Fixed with a choice

```
Fixed in <sha>: <what changed>.

**Assumptions & Autonomous Decisions**
- Decision: <what I chose>
- Why: <reason>
- Alternatives: <what else was possible>
- Tier: 2 (logged)
```

## Ripple

```
This touches <contract / shared behavior> that <repo-a>, <repo-b> also depend
on, so it is being handled across the feature rather than in this PR alone.
<Who> will follow up here once the plan amendment is decided.
```

## Ambiguity (after your human partner decides)

```
Went with option <n>: <short description> (<sha>).
Considered: <other options in a few words>. Chose this because <reason>.
```

## Large, moved to a sub-PR

```
Agreed this is worth doing. It is larger than this PR's scope, so it is in
<sub-PR link> (stacked on this branch). Happy to fold it in if you prefer.
```

## Disagree

```
I don't think this is right here, because <technical reason>.
Evidence: <test, doc, benchmark, file:line>.
If you still prefer the change, <owner> will decide - let me know.
```

## Pre-existing

```
Good catch - this predates this PR (it is on <default branch> at <file>:<line>).
Keeping it out of scope here; filed <work item link> to follow up.
```

## Declining a nit

```
Leaving this one as is to keep the review focused - <short reason>.
```

## Re-review request (round 2+)

```
Addressed in <sha range>: <thread 1>, <thread 2>, ...
Re-review only the changes since <last reviewed sha>, please.
Still open: <thread> - waiting on <whom/what>.
```
