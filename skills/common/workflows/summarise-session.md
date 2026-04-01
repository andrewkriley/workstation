# summarise-session

Summarise the current working session — what was worked on, what was achieved, what remains, and any blockers. Use at the end of a session or when handing off work.

## Context gathering

Gather the following from the current environment:

```bash
pwd
git status --short 2>/dev/null
git log --oneline -15 2>/dev/null
git diff --name-only 2>/dev/null
git diff --name-only --cached 2>/dev/null
date
```

## Task

User's focus area (if provided): `$ARGUMENTS`

### Step 1 — Infer the session goal

From the git history and changed files, determine what this session was primarily about. If `$ARGUMENTS` is provided, use it as context.

If the goal is unclear, ask the user **one question**: "What were you trying to achieve in this session?"

### Step 2 — Produce the summary

---

## Session Summary — <date>

**Project:** <inferred project name or directory>
**Goal:** <one sentence describing what the session set out to do>

### What was done
<3–6 bullet points covering key actions — reference actual files or commands where relevant>

### What was achieved
<what is now working or complete that wasn't before>

### What remains
<outstanding tasks, TODOs, or next steps>

### Blockers / notes
<anything stuck, deferred, or needing a decision — or "None" if clean>

---

### Step 3 — Offer next actions

Ask the user if they'd like to:
- **Share on LinkedIn** → invoke the linkedin-post skill
- **Save the summary** to a file in the project directory
- **Nothing, just the summary** — stop here
