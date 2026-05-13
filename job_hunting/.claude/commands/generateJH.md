Generate a tailored CV from a pasted job description and compile it to PDF. Usage: `/generateJH` then paste the full JD text, or `/generateJH {url}` to fetch from a URL.

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

Then run /generateJH again.
```

Do not proceed past this point until both files exist.

## Input handling

If `$ARGUMENTS` starts with `http`:
- Fetch the page:
  ```bash
  curl -s '$ARGUMENTS' -A "Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 Chrome/120.0.0.0 Safari/537.36"
  ```
- For Greenhouse widget URLs containing `gh_jid=`, extract the `gh_jid` and `board_token` values and call the API instead:
  ```
  https://boards-api.greenhouse.io/v1/boards/{board_token}/jobs/{gh_jid}
  ```

If `$ARGUMENTS` is plain text — treat it directly as the job description.

## Execute CLAUDE.md workflow

**Steps 1–3 run silently.** Do not narrate each step. Output only the fit score, any gap questions, and the planned stack block — nothing else before Step 4.

Run Steps 1 through 8 from `CLAUDE.md` in order:

1. Parse the job description (already have it — skip the curl if pasted)
2. *(silent)* JD analysis — keywords, JD Spirit, Profile ID, Recruiter Priority Stack, anti-signals, gap table
3. *(silent)* Fit score + go/no-go decision
4. **STOP** — output fit score, gap questions (if any), and planned tech stack; wait for user confirmation before proceeding
5. Register job in `jobs.md` (index row only)
6. Check for `template.my.tex`, fall back to `template.sample.tex` if absent, then create `cv/{ID}/CV.tex` using its preamble and section order — use placeholders for all personal details (see CLAUDE.md Step 6)
6b. **STOP** — present all experience bullets in plain text for review; wait for user confirmation; apply all edits in one batch before proceeding
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
CV written:  cv/{ID}/CV.tex
Compiled:    cv/{ID}/CV.pdf   [1 page ✓  or  ⚠ N pages — needs trimming]
```

**If `.env.my` is missing** — skip compilation and tell the user:
```
CV written: cv/{ID}/CV.tex

.env.my not found — personal details not substituted. Set it up once:
  cp .env.sample .env.my
  # edit .env.my: CV_NAME, CV_EMAIL, CV_PHONE, CV_CITY, CV_LINKEDIN

Then compile with: /compileJH {ID}
```

## On completion

If the user reports a 2-page PDF, tighten margins/spacing/bullets and recompile.
