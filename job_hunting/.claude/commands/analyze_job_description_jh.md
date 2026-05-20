Analyze a job description and save the result for later CV generation. Usage: `/analyze_job_description_jh {url}` or `/analyze_job_description_jh` then paste the JD text. Parallel-safe — writes only to `cv/.pending/`, never to `jobs.md` or `skills.my.md`.

## Guard — verify personal files before doing anything else

Before processing any input, run:

```bash
test -f profile.my.md && echo "ok" || echo "missing"
test -f skills.my.md && echo "ok" || echo "missing"
```

If either is missing, **stop immediately** and print:

```
Cannot analyse — personal files not set up:

  profile.my.md:  [ok / MISSING]
  skills.my.md:   [ok / MISSING]

Set them up first:
  cp profile.sample.md profile.my.md
  cp skills.sample.md  skills.my.md

Then run /analyze_job_description_jh again.
```

## Input handling

If `$ARGUMENTS` starts with `http`:
- Fetch the page:
  ```bash
  curl -s '$ARGUMENTS' -A "Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 Chrome/120.0.0.0 Safari/537.36"
  ```
- For Greenhouse widget URLs containing `gh_jid=`, extract `gh_jid` and `board_token` and call the API instead:
  ```
  https://boards-api.greenhouse.io/v1/boards/{board_token}/jobs/{gh_jid}
  ```

If `$ARGUMENTS` is plain text — treat it directly as the job description.

## Run Steps 1–3 silently

Execute Steps 1–3 from `CLAUDE.md` internally. Do not narrate. Do not write to `jobs.md` or `skills.my.md`.

## Save analysis

Derive a slug from the company and role title (lowercase, hyphens, max 40 chars). Create:

```bash
mkdir -p cv/.pending/{slug}
```

Write `cv/.pending/{slug}/analysis.md` with the following sections:

```
# {Company} — {Role Title}
source: {url or "pasted"}
analyzed: {YYYY-MM-DD}

## Raw JD
{full original JD text}

## ATS Keywords
{comma-separated list, exact spelling/casing from JD}

## JD Spirit
{one sentence}

## Profile ID
{backend | techlead | platform | fullstack | ai}

## Recruiter Priority Stack
{ranked list of top 3–5 recruiter filters}

## Anti-signals
{list — elements to suppress or reframe}

## Gap Table
| JD requirement | In skills.md? | Confirmed? | Action |
|---|---|---|---|
...

## Fit Score
{N}% — {GO / CAVEATS / NO-GO}

## Planned Stack
Languages:          {list}
Frameworks:         {list}
Distributed/Infra:  {list}
Databases:          {list}
Practices:          {list}

Suppressed (anti-signals): {list}
Dropped (not in skills.md / not JD-matched): {list}
```

## Gap question resolution (STOP if unknowns exist)

After saving the initial analysis, check the Gap Table for any rows where `In skills.md?` is `No` and the skill is plausible given the user's background.

If any unknowns exist, **stop and ask the user about each one** before closing:

```
Before finishing — a few quick questions about skills not in skills.my.md:

  1. Do you have experience with {skill}? (yes / no / partial)
  2. Do you have experience with {skill}? (yes / no / partial)
  ...
```

Wait for the user to reply. Then:
- Update the Gap Table in `analysis.md` — set `Confirmed?` to `yes / no / partial` for each answered item
- If confirmed `yes` or `partial` — update `Action` to `Include` and add the skill to the Planned Stack in `analysis.md`
- If confirmed `no` — set `Action` to `Drop`
- **Do not write to `skills.my.md`** — that happens in `/generate_cv_jh` after stack confirmation

If no unknowns exist, skip this step entirely.

## Output

Print only:

```
Fit: {N}% ({GO | CAVEATS | NO-GO})

Gap questions: resolved ✓  [or list any that remain unanswered]

Analysis saved: cv/.pending/{slug}/analysis.md

Run when ready:
  /generate_cv_jh
```

Do not ask for stack confirmation here — that happens in `/generate_cv_jh`.
