Start-to-finish CV production for a single job: session preflight, JD analysis, CV generation, compile. Usage: `/apply {url}`, `/apply` followed by pasted JD text, or `/apply {ID}` to resume.

Merges `/start_jh` + `/analyze_job_description_jh` + `/generate_cv_jh` into one pass. Safe to re-run: it derives progress from disk and picks up where it stopped.

For processing many listings at once, keep using `/analyze_job_description_jh` — its analysis phase is near-autonomous and fans out better than `/apply`, which stops twice for your input.

---

## Step 0 — Preflight (silent unless something is wrong)

Print **nothing** if every check passes. Go straight to Step 1.

```bash
docker ps -q --filter name=latex-jh --filter status=running
```

If the output is non-empty the container is already up — **do not restart it**, and do not run `docker start`. Only when empty:

```bash
flock -x .container.lock -c 'docker start latex-jh 2>/dev/null || docker run -d --name latex-jh --restart unless-stopped -v "$(pwd)":/workspace --entrypoint tail texlive/texlive:latest -f /dev/null'
```

The lock stops two parallel sessions racing to create the container and one failing with `name already in use`.

Then:

```bash
test -f profile.my.md && test -f skills.my.md && echo ok || echo BLOCKED
```

If `BLOCKED`, stop immediately:

```
Cannot run /apply — personal files not set up:

  profile.my.md:  [ok / MISSING]
  skills.my.md:   [ok / MISSING]

  cp profile.sample.md profile.my.md   # then add your real work history
  cp skills.sample.md  skills.my.md    # then add your real skills

Using the sample files would produce a CV for a fictional person.
```

`.env.my` and `template.my.tex` are **not** blockers — note their absence only at the point they matter (compile, and template selection).

Unlike `/start_jh`, do not print pending analyses or the last-session summary. Run `/start_jh` when you want that overview.

---

## Step 1 — Resolve the job to an ID

### `$ARGUMENTS` matches `^[A-Z]+-[A-Z][0-9]+$` (e.g. `ENG-A42`)
Use it directly. If `findings/{ID}/analysis.md` does not exist, stop and say so.

### `$ARGUMENTS` is empty
Resume the most recently modified job that is not finished:

```bash
for d in findings/*/; do id=$(basename "$d"); s=$(./state.sh state "$id"); \
  [ "$s" != "done" ] && echo "$(stat -c %Y "$d") $id $s"; done | sort -rn | head -5
```

Show the top candidate and ask before proceeding — with 88 jobs on disk, guessing wrong wastes a full run.

### `$ARGUMENTS` starts with `http`
Fetch it:

```bash
curl -s '$ARGUMENTS' -A "Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 Chrome/120.0.0.0 Safari/537.36"
```

For Greenhouse widget URLs containing `gh_jid=`, extract `gh_jid` and `board_token` and call the API instead:
`https://boards-api.greenhouse.io/v1/boards/{board_token}/jobs/{gh_jid}`

Then run duplicate detection below.

### `$ARGUMENTS` is plain text
Treat it as the JD. Run duplicate detection below.

---

## Step 2 — Duplicate detection (URL and pasted input only)

Write the raw JD to a temp file, then:

```bash
./state.sh find-dup /tmp/jd.txt
```

**Match found** — the identical listing was processed before. Announce and resume it, do not create a second ID:

```
Already processed: {ID} — {Company} — {Role}
{resume banner from ./state.sh detail {ID}}
```

**No hash match** — check the company against the register, because most of the corpus predates hashing and every earlier analysis was pasted, not linked:

```bash
grep -iE "^\| ENG-[A-Z0-9]+ \|[^|]*\|[^|]*\| *{Company}" jobs.md
```

If the company appears with a similar role title, ask before creating a new ID:

```
Possible duplicate: {ID} — {Company} — {Role} ({date}, {state})
Same role, or a different opening at the same company?
```

Same company with a genuinely different role is normal — proceed to reserve a new ID.

---

## Step 3 — Reserve the ID (new jobs only)

```bash
ID=$(./jobs.sh reserve)
```

Atomic: appends a `reserved` placeholder row to `jobs.md` and creates `findings/{ID}/` while holding `.jobs.lock`. Never edit `jobs.md` by hand — every write goes through `jobs.sh`.

---

## Step 4 — Determine the resume point

```bash
./state.sh detail {ID}
```

Print that line verbatim as the first output of the run, then jump to the matching stage:

| State | Jump to |
|---|---|
| `fresh` | Step 5 — analysis |
| `analysis_incomplete` | Step 5 — analysis (previous run was interrupted mid-write) |
| `gaps_unresolved` | Step 6 — Stop 1 |
| `need_cv` | Step 7 — write the CV |
| `need_review` | Step 8 — Stop 2 |
| `done` | Stop. Offer `/recompile_cv {ID}` or ask what to revise. |

Never redo a completed stage.

---

## Step 5 — Analysis (silent)

Run Steps 1–3 from `CLAUDE.md` internally. Do not narrate. Do not write to `skills.my.md`.

Write `findings/{ID}/analysis.md` in the standard format, with **one added frontmatter line** so future runs can recognise a re-paste:

```
# {Company} — {Role Title}
id: {ID}
source: {url or "pasted"}
analyzed: {YYYY-MM-DD}
jd_hash: {output of ./state.sh hash /tmp/jd.txt}
```

Sections, in order: `## Raw JD`, `## ATS Keywords`, `## JD Spirit`, `## Profile ID`, `## Recruiter Priority Stack`, `## Anti-signals`, `## Gap Table`, `## Fit Score`, `## Planned Stack` — exactly as specified in `/analyze_job_description_jh`.

Then register the real values:

```bash
./jobs.sh update {ID} {date} "{Role Title}" "{Company}" "{Location}" {profile_id} new "{url or —}"
```

### Fit gate

If the fit score is **below 60%**, stop before writing any CV:

```
{ID} — {Company} — {Role Title}
Fit: {N}% — below the 60% threshold.

{one line: what the blocking gap is}

Generate the CV anyway, or stop here?
```

Wait for an answer. 37 analyses in this repo never became applications — a low-fit run is worth confirming before it costs you a full CV pass.

---

## Step 6 — STOP 1: fit, gap questions, planned stack

One combined stop. Print the header, then all three blocks together:

```
{ID} — {Company} — {Role Title}
Fit: {N}% ({GO | CAVEATS | NO-GO})

Gap questions:
  1. Do you have experience with {skill}? (yes / no / partial)
  2. ...

Planned Skills section:
  Languages:          [list]
  Frameworks:         [list]
  Distributed/Infra:  [list]
  Databases:          [list]
  Practices:          [list]

Suppressed (anti-signals): [list]
Dropped (not in skills.md / not JD-matched): [list]
```

Skip the gap-questions block entirely when nothing is open.

Before showing this, reconcile the Gap Table against the **current** `skills.my.md` — anything marked `No` in the analysis but since added is auto-resolved to `Include`; never ask twice.

**Wait for confirmation.** Then:
- Update `Confirmed?` and `Action` in `findings/{ID}/analysis.md`
- Append any newly confirmed skills to `skills.my.md` under the lock:
  ```bash
  flock -x .skills.lock -c 'cat >> skills.my.md' <<< "{new skill lines}"
  ```
  Read-modify-write on `skills.my.md` without the lock loses one session's edits when two runs confirm skills at once.

---

## Step 7 — Write the CV

```bash
test -f template.my.tex && echo "template.my.tex" || echo "template.sample.tex"
```

Use that template's preamble and section order verbatim. Follow `CLAUDE.md` Step 6 in full — personal details stay as placeholders (`YOUR NAME`, `YOUR@EMAIL.COM`, `+00 000 000 0000`, `Your City`, `YOURLINKEDIN`); `compile.sh` substitutes them. `YOUR SUBTITLE` is JD-specific positioning you write directly.

Write to `findings/{ID}/CV.tex`. Batch every edit — do not compile yet.

---

## Step 8 — STOP 2: experience review

```
{ID} — {Company} — {Role Title}

{Employer} — {Title} ({dates})
  • bullet
  • bullet
```

Plain text, not LaTeX. Ask: "Do the bullets look correct? Confirm or tell me what to change."

**Wait for confirmation.** Apply all edits in one batch.

---

## Step 9 — Quality checks

Run the full Step 8 checklist from `CLAUDE.md`: LaTeX errors, ATS coverage, skills audit, JD coverage, floating skills, anti-signals, years consistency, evidence gate, bullet priority, banned words.

Add one check: **no language level in the CV may exceed the level recorded in `skills.my.md`.** German is a gap in 14 analyses and one application went out claiming B1 against a recorded A2–B1. Verify before compiling; if the JD demands a higher level, say so rather than inflating the CV.

---

## Step 10 — Compile

```bash
test -f .env.my && bash compile.sh {ID} || echo "no .env.my"
```

`compile.sh` reports the page count and writes `findings/{ID}/.compiled`. On anything other than 1 page, tighten margins/spacing/bullets and recompile.

**With `.env.my`:**
```
{ID} — {Company} — {Role Title}

CV written:  findings/{ID}/CV.tex
Compiled:    cv/{ID}/CV.pdf   [1 page ✓ | ⚠ N pages — needs trimming]

Next: submit, then record the outcome in jobs.md.
```

**Without `.env.my`:**
```
{ID} — {Company} — {Role Title}

CV written: findings/{ID}/CV.tex
.env.my not found — personal details not substituted.
  cp .env.sample .env.my    # then set CV_NAME, CV_EMAIL, CV_PHONE, CV_CITY, CV_LINKEDIN
Then: /recompile_cv {ID}
```

Leave the container running — `/apply` never stops it. Run `/stop_jh` when the session is over.

---

## Parallel safety

Two `/apply` sessions can run at once without corrupting state: ID reservation, every `jobs.md` write, `skills.my.md` appends and container creation are all lock-protected, and all other artifacts are namespaced by job ID.

Throughput is still bounded by you — both stops wait on your input, so past the analysis phase parallel sessions serialise on your attention rather than the tooling.
