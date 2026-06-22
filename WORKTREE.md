# Git Worktree Guide — Rana

Every issue is worked on in an isolated **git worktree** so that `master` always stays clean and no
half-finished work leaks between issues.

---

## Quick Start

```bash
# 1. Create a worktree for an issue (run from the root repo)
git worktree add ../Rana-<id>-<slug> -b feat/Rana-<id>-<slug>

# 2. Work inside the worktree
cd ../Rana-<id>-<slug>

# 3. When done — commit, then merge back
git add .
git commit -m "feat: <summary>"
git push origin feat/Rana-<id>-<slug>

cd /Users/apple/Programming/Projects/Personal/Rana
git merge feat/Rana-<id>-<slug> --no-edit
git push origin master          # only when remote is configured

# 4. Clean up the worktree
git worktree remove ../Rana-<id>-<slug>
git branch -d feat/Rana-<id>-<slug>
```

---

## Naming Convention

| Segment | Pattern | Example |
|---------|---------|---------|
| Directory | `../Rana-<id>-<short-slug>` | `../Rana-k9w-flutter-init` |
| Branch | `feat/Rana-<id>-<short-slug>` | `feat/Rana-k9w-flutter-init` |

Use `fix/` prefix for bug-fix issues instead of `feat/`.

---

## Active Worktrees

Run `git worktree list` from the root repo to see all live worktrees.

---

## Rules

1. **Never commit directly to `master`** — always work in a worktree branch.
2. **One issue = one worktree branch.** Don't reuse branches across issues.
3. **Remove the worktree** after merging to keep `git worktree list` tidy.
4. **Do not push `master` without a green build** (run `flutter analyze && flutter test` first).
5. **Beads workflow** — always run `bd update <id> --claim` before starting work in a worktree.
