Generate a tailored CV from a job description and compile it to PDF. Usage: `/generate_cv_jh {ID}` (resume from existing analysis), `/generate_cv_jh {url}`, or paste the full JD text after the command.

The full CV generation workflow is defined in `CLAUDE.md`. Execute it now for the provided input.

## Guard — verify personal files before doing anything else

Before processing any input, run:

```bash
test -f profile.my.md && echo "ok" || echo "missing"
test -f skills.my.md && echo "ok" || echo "missing"
```

If either is missing, **stop immediately** and print:

```
Cannot generate a CV — personal files not set up:

  profile.my.md:  [ok / MISSING]
  skills.my.md:   [ok / MISSING]

These files contain your real work history and skills.
Using the sample files would produce a CV for a fictional person.

Set them up first:
  cp profile.sample.md profile.my.md   # then replace with your real work history
  cp skills.sample.md  skills.my.md    # then replace with your real skills

Then run /generate_cv_jh again.
```

Do not proceed past this point until both files exist.

## Input handling

**If `$ARGUMENTS` matches the job ID pattern** (`^[A-Z]+-[A-Z][0-9]+$`, e.g. `ENG-A09`) — resume from the existing analysis:

```bash
test -f findings/{ID}/analysis.md && echo "found" || echo "missing"
```

If missing, stop:
```
No analysis found at findings/{ID}/analysis.md.
Run /analyze_job_description_jh first, or check the ID in jobs.md.
```

If found — proceed to analysis validation.

**If `$ARGUMENTS` is empty** — find all jobs with status `new` that have an analysis but no CV yet:

```bash
awk -F'|' '/\| new \|/{gsub(/ /,"",$2); print $2}' jobs.md | while read id; do
  [ -f "findings/${id}/analysis.md" ] && [ ! -f "findings/${id}/CV.tex" ] && echo "${id}"
done
```

- **1 found** — use it automatically. Print: `Resuming from findings/{ID}/analysis.md` then proceed to analysis validation.
- **2+ found** — auto-select the most recently modified:
  ```bash
  awk -F'|' '/\| new \|/{gsub(/ /,"",$2); print $2}' jobs.md | while read id; do
    [ -f "findings/${id}/analysis.md" ] && [ ! -f "findings/${id}/CV.tex" ] && \
    echo "$(stat -c %Y findings/${id}/analysis.md) ${id}"
  done | sort -rn | head -1 | awk '{print $2}'
  ```
  Print: `Resuming from findings/{ID}/analysis.md  (most recent — N others pending)` then proceed.
- **0 found** — stop and ask the user to provide a job URL or paste the JD:
  ```
  No pending analysis found. Provide a job description:
    /analyze_job_description_jh <url>   — analyze first (recommended)
    /generate_cv_jh <url>               — or go directly with a URL
  ```

**If `$ARGUMENTS` starts with `http`:**
- Fetch the page:
  ```bash
  curl -s '$ARGUMENTS' -A "Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 Chrome/120.0.0.0 Safari/537.36"
  ```
- For Greenhouse widget URLs containing `gh_jid=`, extract the `gh_jid` and `board_token` values and call the API instead:
  ```
  https://boards-api.greenhouse.io/v1/boards/{board_token}/jobs/{gh_jid}
  ```

**If `$ARGUMENTS` is plain text** — treat it directly as the job description.

## Analysis validation (when resuming from findings/{ID}/analysis.md)

Before proceeding, verify the analysis file is complete. Check that all required sections are present:
- `## Raw JD`
- `## Fit Score`
- `## Planned Stack`
- `## Gap Table`
- `## Recruiter Priority Stack`

If any section is missing, stop immediately:
```
Analysis file is incomplete — missing sections: {list}
This likely means /analyze_job_description_jh was interrupted.
Re-run: /analyze_job_description_jh {source url or paste JD}
```

## Gap table reconciliation (when resuming from findings/{ID}/analysis.md)

Before presenting Step 4, re-check the Gap Table from `analysis.md` against the **current** `skills.my.md`.

Any skill marked `No` or `unknown` in the analysis but since added to `skills.my.md` should be auto-resolved to `Include` — do not ask about it again.

Update the Planned Stack accordingly before showing it to the user at Step 4.

## Execute CLAUDE.md workflow

**Steps 1–3 run silently** (skipped entirely when resuming from a saved analysis). Do not narrate. Output only the fit score, any remaining gap questions, and the planned stack block — nothing else before Step 4.

Run Steps 1 through 8 from `CLAUDE.md` in order:

1. Parse the job description (already have it — skip the curl if pasted)
2. *(silent)* JD analysis — keywords, JD Spirit, Profile ID, Recruiter Priority Stack, anti-signals, gap table
3. *(silent)* Fit score + go/no-go decision
4. **STOP** — output the following header, then fit score, any remaining gap questions, and planned tech stack; wait for user confirmation before proceeding:
   ```
   {ID} — {Company} — {Role Title}
   ```
   When the user confirms a new skill, append it to `skills.my.md` under a lock — an unprotected read-modify-write loses one session's edits if two runs confirm skills at the same time:
   ```bash
   flock -x .skills.lock -c 'cat >> skills.my.md' <<< "{new skill lines}"
   ```
5. Register job in `jobs.md` — always via `./jobs.sh`, never by editing the file directly:
   - **If resuming from `findings/{ID}/analysis.md`** — job is already registered by `/analyze_job_description_jh`. Verify:
     ```bash
     ./jobs.sh get {ID} >/dev/null 2>&1 && echo "ok" || echo "missing"
     ```
     If missing, register it with `./jobs.sh update ...`. If present, skip.
   - **If starting fresh from URL/text** — `ID=$(./jobs.sh reserve)`, then `./jobs.sh update "$ID" ...` once the company and title are known.
6. Check for `template.my.tex`, fall back to `template.sample.tex` if absent, then create `findings/{ID}/CV.tex` using its preamble and section order — use placeholders for all personal details (see CLAUDE.md Step 6)
6b. **STOP** — print the header `{ID} — {Company} — {Role Title}`, then present all experience bullets in plain text for review; wait for user confirmation; apply all edits in one batch before proceeding
7. Run all quality checks from the checklist in `CLAUDE.md`

## Compile

After quality checks pass, check whether `.env.my` exists:

```bash
test -f .env.my && echo "exists" || echo "missing"
```

**If `.env.my` exists** — compile immediately:

```bash
bash compile.sh {ID}
```

Scan the output for the page count line:
- `(1 page, ...)` → success
- `(2 pages, ...)` or more → tighten margins/spacing/bullets, re-run quality checks, and recompile
- Page count absent → report the log output and ask the user to check

Report the final result:
```
{ID} — {Company} — {Role Title}

CV written:  findings/{ID}/CV.tex
Compiled:    cv/{ID}/CV.pdf   [1 page ✓  or  ⚠ N pages — needs trimming]
```

**If `.env.my` is missing** — skip compilation and tell the user:
```
{ID} — {Company} — {Role Title}

CV written: findings/{ID}/CV.tex

.env.my not found — personal details not substituted. Set it up once:
  cp .env.sample .env.my
  # edit .env.my: CV_NAME, CV_EMAIL, CV_PHONE, CV_CITY, CV_LINKEDIN

Then compile with: /recompile_cv {ID}
```

## On completion

If the user reports a 2-page PDF, tighten margins/spacing/bullets and recompile.
