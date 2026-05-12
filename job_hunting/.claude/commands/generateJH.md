Generate a tailored CV from a pasted job description and compile it to PDF. Usage: `/generateJH` then paste the full JD text, or `/generateJH {url}` to fetch from a URL.

The full CV generation workflow is defined in `CLAUDE.md`. Execute it now for the provided input.

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

Run Steps 1 through 8 from `CLAUDE.md` in order:

1. Parse the job description (already have it — skip the curl if pasted)
2. JD analysis — keywords, JD Spirit, Profile ID, Recruiter Priority Stack, anti-signals, gap table
3. Fit score + go/no-go decision
4. **STOP** — present planned tech stack and wait for user confirmation before proceeding
5. Register job in `jobs.md` (index row only)
6. Check for `my_template.tex`, fall back to `template.my.tex` if absent, then create `cv/{ID}/CV.tex` using its preamble and section order — use placeholders for all personal details (see CLAUDE.md Step 6)
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
