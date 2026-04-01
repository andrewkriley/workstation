# repo-status

Check the full sync status of a git repository and produce a clear summary of local vs remote branches, commits ahead/behind, open PRs, and working tree state.

## Step 1 — Identify the repo

If an argument is provided, use it as the repo path. Otherwise use the current working directory.

Confirm it is a git repo and get its remote URL:

```bash
REPO="${ARGUMENTS:-$(pwd)}"
cd "$REPO"
git rev-parse --show-toplevel 2>/dev/null || echo "NOT A GIT REPO"
git remote get-url origin 2>/dev/null
```

If it is not a git repo, tell the user and stop.

## Step 2 — Fetch and collect status

```bash
cd "${ARGUMENTS:-$(pwd)}"

git fetch --all --quiet 2>/dev/null

echo "=REPO=$(git rev-parse --show-toplevel)"
echo "=REMOTE=$(git remote get-url origin 2>/dev/null)"
echo "=CURRENT_BRANCH=$(git branch --show-current)"

echo "=LOCAL_BRANCHES="
git branch -v

echo "=REMOTE_BRANCHES="
git branch -rv

echo "=STATUS="
git status --short

echo "=STASH_COUNT=$(git stash list | wc -l | tr -d ' ')"

echo "=DEV_AHEAD_MAIN="
git log main..dev --oneline 2>/dev/null || echo "(branches not found)"

echo "=MAIN_AHEAD_DEV="
git log dev..main --oneline 2>/dev/null || echo "(branches not found)"

echo "=OPEN_PRS="
gh pr list --state open --json number,title,headRefName,baseRefName,url \
  --template '{{range .}}#{{.number}} [{{.headRefName}}→{{.baseRefName}}] {{.title}} {{.url}}{{"\n"}}{{end}}' 2>/dev/null || echo "(gh CLI not available)"
```

## Step 3 — Produce the summary

---

**Repo:** `<repo name>` (`<remote URL>`)
**Current branch:** `<branch>`

### Branch alignment

For each branch that exists both locally and remotely, state clearly whether it is:
- ✅ **In sync** — local and remote at the same commit
- ⬆️ **Local ahead** — N commits not yet pushed
- ⬇️ **Local behind** — N commits to pull
- ↕️ **Diverged** — both sides have commits the other doesn't

Focus on `main` and `dev` first, then any other active branches.

### Commits: dev vs main

List commits on `dev` but not `main` (pending merge). List any commits on `main` not yet in `dev`.

### Open PRs / MRs

List open PRs with number, title, branch direction, and URL. If none, say so.

### Working tree

State whether clean or dirty. If dirty, briefly describe what is modified.

### Stash

If stash entries exist, note the count.

### Overall assessment

One or two sentences on the overall state.

---

Keep the summary factual and concise. Do not reproduce raw git output.
