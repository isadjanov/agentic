Analyze a job description, assign a job ID, register it in jobs.md, and save the result to findings/{ID}/analysis.md for later CV generation. Usage: `/analyze_job_description_jh {url}` or paste the JD text after the command.

Parallel-safe: the ID is reserved atomically at the very start via `flock`, so multiple instances running simultaneously will each get a unique ID.

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

## Reserve ID — do this immediately after the guard, before any analysis

Atomically claim the next ID and write a placeholder row to `jobs.md`:

```bash
ID=$(./jobs.sh reserve)
```

`$ID` is now set (e.g. `ENG-A19`) and `findings/$ID/` exists. Use `$ID` for all subsequent steps.

`jobs.sh` holds an exclusive lock on `.jobs.lock` for the whole read/modify/write cycle. **Never write to `jobs.md` directly** — locking the register file itself does not work, because any in-place rewrite replaces its inode and a second session would lock a different object.

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

Execute Steps 1–3 from `CLAUDE.md` internally. Do not narrate. Do not write to `skills.my.md`.

## Save analysis

Write `findings/{ID}/analysis.md` with the following sections:

```
# {Company} — {Role Title}
id: {ID}
source: {url or "pasted"}
analyzed: {YYYY-MM-DD}
jd_hash: {./state.sh hash <file containing the raw JD>}

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
{N}% — {GO / CAVEATS | NO-GO}

## Planned Stack
Languages:          {list}
Frameworks:         {list}
Distributed/Infra:  {list}
Databases:          {list}
Practices:          {list}

Suppressed (anti-signals): {list}
Dropped (not in skills.md / not JD-matched): {list}
```

## Update jobs.md row

Replace the placeholder row (written during ID reservation) with the real values:

```bash
./jobs.sh update "$ID" "$(date +%Y-%m-%d)" "{Role Title}" "{Company}" "{Location}" "{Profile ID}" new "{url or —}"
```

Goes through the same lock as the reservation, and passes values as arguments rather than splicing them into a `sed` expression — so titles containing `&`, `/` or `\` are written literally instead of being interpreted as replacement syntax.

Status is always `new` at this stage — updated to `applied` / `interviewing` / etc. later.

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
- Update the Gap Table in `findings/{ID}/analysis.md` — set `Confirmed?` to `yes / no / partial` for each answered item
- If confirmed `yes` or `partial` — update `Action` to `Include` and add the skill to the Planned Stack in `analysis.md`
- If confirmed `no` — set `Action` to `Drop`
- **Do not write to `skills.my.md`** — that happens in `/generate_cv_jh` after stack confirmation

If no unknowns exist, skip this step entirely.

## Output

Print only:

```
{ID} — {Company} — {Role Title}
Fit: {N}% ({GO | CAVEATS | NO-GO})

Gap questions: resolved ✓  [or list any that remain unanswered]

Analysis saved: findings/{ID}/analysis.md

Run when ready:
  /generate_cv_jh {ID}
```

Do not ask for stack confirmation here — that happens in `/generate_cv_jh`.
