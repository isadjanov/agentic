End the CV generation session: stop the latex container and save a session handoff to memory.

## Steps

### 1 — Stop the latex container

```bash
docker stop latex-jh
```

Verify it stopped:
```bash
docker ps --filter name=latex-jh --format "{{.Names}}\t{{.Status}}"
```

### 2 — Summarise this session

Review what happened during this session:
- Which job IDs were processed (check `jobs.md` index for recent entries and `cv/` for new folders)
- Which CVs were compiled to PDF
- Any T1/T2 gaps that came up repeatedly across JDs
- Any blockers or unfinished work

### 3 — Update session memory

Overwrite `last_session.md` in the current working directory with:
- Date of this session
- Jobs worked on this session (IDs + company names)
- Last action taken (last job ID, file:line, or blocker)
- Immediate next step for the next session

### 4 — Check for recurring skill gaps

If a skill appeared as T1 or T2 in two or more JDs this session and is not yet in `skills.my.md`, flag it to the user:
```
Recurring gap: <skill> — appeared as T1/T2 in <ID1>, <ID2>. Add to skills.my.md once acquired.
```

### 5 — Clean up stale pending analyses

```bash
ls cv/.pending/*/analysis.md 2>/dev/null
```

If any pending analyses remain, list them and ask:

```
Pending analyses not converted to CVs this session:
  1. cv/.pending/{slug1}/analysis.md — {Company} — {Role}
  2. cv/.pending/{slug2}/analysis.md — {Company} — {Role}

Keep for next session or discard? (keep / discard all / discard 1,2,...)
```

Wait for reply. For each discarded slug:
```bash
rm -rf cv/.pending/{slug}
```

If no pending analyses exist, skip this step.

### 6 — Confirm to user

```
Latex container: stopped
Session saved:   last_session.md updated
Recurring gaps:  <list or "none this session">
Pending cleaned: <kept N / discarded N / none>
```

Tell the user they can now close Claude Code.
