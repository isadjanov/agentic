# job_hunting

Handles two workflows:

- **Outbound** — produces tailored, one-page LaTeX CVs for positions you apply to, derived from `profile.my.md` and `skills.my.md` and optimised against a parsed job description using Claude Code.
- **Inbound** — interview preparation for positions where the employer contacted you. No CV generation; Claude reads the hiring materials and produces stage-specific prep files in `findings/{ID}/`.

Each file has a `*.sample.*` committed template and a `*.my.*` personal version (gitignored). **`profile.my.md` and `skills.my.md` are required** — `/generate_cv_jh` will refuse to run without them. `template.my.tex` and `.env.my` have acceptable fallbacks and can be set up later.

---

## Step 1 — One-time setup

### 1.1 Personal details

```bash
cp .env.sample .env.my
```

Open `.env.my` and fill in your details:

| Variable | What to put |
|---|---|
| `CV_NAME` | Your full name |
| `CV_EMAIL` | Your email address |
| `CV_PHONE` | Your phone number |
| `CV_CITY` | Your city / location |
| `CV_LINKEDIN` | Your LinkedIn URL (e.g. `linkedin.com/in/yourprofile`) |

`.env.my` is gitignored and **never read by Claude** — substitution happens only inside `compile.sh` at compile time.

### 1.2 Work history (required)

```bash
cp profile.sample.md profile.my.md
```

Open `profile.my.md` and replace the sample content with your real work history. For each role, write:
- What the system did and at what scale (numbers)
- What you specifically changed and why
- Before → after metrics

`/generate_cv_jh` will not run if this file is missing.

### 1.3 Skills inventory (required)

```bash
cp skills.sample.md skills.my.md
```

Open `skills.my.md` and replace the sample content with your real skills, grouped by category. Only skills listed here may appear in any generated CV — this is the canonical gate.

`/generate_cv_jh` will not run if this file is missing.

### 1.4 CV template (required before first CV)

```bash
cp template.sample.tex template.my.tex
```

`template.my.tex` is your personal template — formatting is your choice. The sample gives you the correct structure (placeholders, section markers, preamble) but font, margins, spacing, and visual style are yours to decide.

> **Why?** Deliberately leaving visual formatting to each user ensures no two people produce identically styled CVs. A recruiter who sees the same layout repeatedly recognises a tool — your template should look like you, not like everyone else who used this project.

**A good CV template must:**
- Produce exactly **1 page** — this is a hard requirement, not a preference
- Be readable at 10–11pt font
- Have tight but not cramped margins (1.5–2 cm typical)
- Have clear visual separation between sections

**Claude can help with specific changes** — describe what you want:

> "The section headers need more visual weight"
> "Margins are too wide, I'm losing a line of content"
> "Make the bullet spacing tighter"
> "Switch the font to something more ATS-friendly"

Claude will edit `template.my.tex` in place and leave your aesthetic choices intact. Run `/recompile_cv` on an existing CV after any template change to verify the output is still 1 page.

Once `template.my.tex` exists, every future `/generate_cv_jh` run uses it automatically. If you skip this step, `template.sample.tex` is used as a fallback — review it first to decide whether it meets your standard.

### 1.5 Docker

Docker must be running. The `latex-jh` container is started automatically by `/start_jh` — no manual setup needed.

---

## Step 2 — Start a session

Run in Claude Code:

```
/start_jh
```

This:
- Starts the `latex-jh` Docker container (or creates it if absent)
- Checks all personal files and reports status for each:
  - `profile.my.md` / `skills.my.md` — ❌ blocks the session if missing; shows the exact `cp` command to fix it
  - `template.my.tex` — ⚠ warns if absent, falls back to `template.sample.tex`
  - `.env.my` — ⚠ warns if absent; CVs will still be written but not compiled until it is created
- Shows where you left off from the last session

---

## Step 3 — Generate a CV

### Single job (default)

Run in Claude Code:

```
/generate_cv_jh <job URL>
```

or paste the full job description text directly after `/generate_cv_jh`.

If `profile.my.md` or `skills.my.md` are missing, the command stops immediately with setup instructions before doing any work.

Claude will:
1. Parse the job description and extract ATS keywords
2. Score the fit against your skills (flags if below 60%)
3. **Stop and show you the planned tech stack — you confirm or adjust before anything is written**
4. Register the job in `jobs.md` with a generated ID (e.g. `ENG-A01`)
5. Write `cv/ENG-A01/CV.tex` using your template and profile — personal details are placeholders
6. **Stop and show you all experience bullets in plain text — you confirm or request edits**
7. Run quality checks (1-page fit, ATS coverage, no floating skills, no banned words)
8. Compile to `cv/ENG-A01/CV.pdf` with your real details substituted from `.env.my`

If the PDF comes out at 2 pages, Claude will tighten spacing and recompile automatically.

### Parallel batch (multiple jobs at once)

Use `/analyze_job_description_jh` to separate the non-interactive analysis from the interactive CV writing.

**Phase 1 — run in parallel across N Claude Code sessions:**

> Phase 1 does not need Docker or `/start_jh` — it is pure analysis with no compilation. Switch to **Haiku** (`meta+p`) before starting each session to save tokens; switch back to Sonnet for Phase 2.

```
/analyze_job_description_jh <job URL>   # session 1
/analyze_job_description_jh <job URL>   # session 2
/analyze_job_description_jh <job URL>   # session 3
```

Each session fetches the JD, scores fit, resolves skill gap questions interactively, and saves the full analysis to `cv/.pending/{slug}/analysis.md`. No writes to `jobs.md` or `skills.my.md` — fully parallel-safe.

**Phase 2 — run sequentially in one session:**

```
/generate_cv_jh cv/.pending/stripe-backend-engineer/analysis.md
/generate_cv_jh cv/.pending/cloudflare-platform-engineer/analysis.md
```

Skips Steps 1–3 (already done), jumps straight to stack confirmation. After a successful compile the pending file is archived into `cv/{ID}/analysis.md` and the slot is removed.

**Net effect:** total time is `max(analysis times) + sum(write times)` instead of `sum(all steps × N)`.

---

## Inbound workflow (employer contacted you)

When the employer reaches out first, there is no CV to generate. The workflow is agentic — no slash command needed.

1. **Gather materials** — hiring guide PDF, job email, any JD the employer shared
2. **Register in `jobs.md`** with status `interviewing`
3. **Create `findings/{ID}/`** — Claude's working folder for this opportunity
4. **Tell Claude what you have** — paste the email, share the PDF. Claude reads everything and produces:
   - `findings/{ID}/analysis.md` — company facts, tech stack, interview process, decisions (e.g. minimal tech stack for the call)
   - `findings/{ID}/prep_screening.md` — prep for the first call, or equivalent stage file

As the process progresses, add new prep files for each stage (`prep_build_it.md`, `prep_system_design.md`, etc.).

> `findings/{ID}/` is where Claude reads and writes between sessions. `cv/` is read-blocked for privacy reasons — `findings/` is the workaround that keeps analysis accessible.

---

## Before sending to the employer

Open `cv/{ID}/CV.pdf`, read it in full, and re-save or re-export it before attaching to any application. This ensures you have reviewed the final content — Claude generates from your profile data, but you are responsible for what goes out.

---

## Step 4 — Recompile (if needed)

If you edit `CV.tex` manually and need to recompile:

```
/recompile_cv ENG-A01
```

---

## Step 5 — End the session

```
/stop_jh
```

This stops the Docker container and saves a session handoff so `/start_jh` can resume next time.

---

## Privacy boundary

```
Claude ──writes──▶ CV.tex  (YOUR NAME placeholder)
                      │
compile.sh ──reads──▶ .env.my  (real details, never seen by Claude)
                      │
              substitutes + pdflatex ×2
                      │
                   CV.pdf  (real details, local only)
```

Your real name, email, and phone never appear in any file Claude reads or writes. The job ID lives in the folder path only (`cv/ENG-A01/CV.pdf`).

---

## File convention

| Suffix | Meaning | Tracked in git |
|---|---|---|
| `*.sample.*` | Committed template — safe placeholder content | Yes |
| `*.my.*` | Your personal file — real content, gitignored | No |

| File | Fallback behaviour |
|---|---|
| `profile.my.md` | **Required** — `/generate_cv_jh` blocks if missing |
| `skills.my.md` | **Required** — `/generate_cv_jh` blocks if missing |
| `template.my.tex` | **Required before first CV** — sample fallback is not production-ready; ask Claude to format it |
| `.env.my` | Optional at write time — required to compile PDF |

## Structure

| File / Folder | Purpose |
|---|---|
| `profile.my.md` | Your work history (gitignored) |
| `skills.my.md` | Your canonical skills gate — only skills here appear in CVs (gitignored) |
| `template.my.tex` | Your personal CV format (gitignored) |
| `.env.my` | Your personal details — **never read by Claude** (gitignored) |
| `profile.sample.md` | Sample work history — copy to `profile.my.md` to get started |
| `skills.sample.md` | Sample skills inventory — copy to `skills.my.md` to get started |
| `template.sample.tex` | Sample CV format — copy to `template.my.tex` to customise |
| `.env.sample` | Sample env file — copy to `.env.my` and fill in your details |
| `jobs.md` | Job register: index table + detail sections (gitignored) |
| `cv/{ID}/` | One folder per job — `CV.tex`, `CV.pdf`, LaTeX aux files (gitignored) |
| `findings/{ID}/` | Claude's read/write working space per job — `analysis.md`, stage prep files (gitignored) |
| `cv/.pending/{slug}/` | Temporary analysis output from `/analyze_job_description_jh` — moved to `cv/{ID}/` after compile (gitignored) |
| `compile.sh` | Substitutes `.env.my` values and compiles via the Docker container |
| `CLAUDE.md` | Full CV generation workflow — `/generate_cv_jh` follows this spec |
| `.claude/commands/` | Slash commands: `start_jh`, `stop_jh`, `analyze_job_description_jh`, `generate_cv_jh`, `recompile_cv` |

Job ID format: `{DEPT}-{ALPHA}{NN}` — e.g. `ENG-A01`, `DAT-B03`.

---

## Dependencies

- **Docker** — must be running; `texlive/texlive:latest` image pulled on first `/start_jh`
- **Claude Code** — all commands are Claude Code slash commands
- **Bash** — required by `compile.sh`

| Platform | Supported | Notes |
|---|---|---|
| Linux | Yes | — |
| Mac | Yes | — |
| Windows | WSL2 only | Install [WSL2](https://learn.microsoft.com/en-us/windows/wsl/install) + [Docker Desktop](https://www.docker.com/products/docker-desktop/) and run everything inside the WSL2 terminal |

No API keys required. All CV content comes from local files.

---

## Stay updated

Updates are announced in the Telegram channel: [t.me/DoneOps](https://t.me/DoneOps)

---

## License

Personal use only while in alpha. Commercial use is not permitted without explicit permission from the author.

---

## Security disclaimer

`.env.my` is gitignored, Claude is explicitly prohibited from reading it, and substitution happens entirely inside `compile.sh` at compile time.

Before pushing any fork, verify no personal file was ever accidentally committed:

```bash
git log --all --oneline -- .env.my profile.my.md skills.my.md template.my.tex jobs.md
```

This should return no output. If it does, the listed commits contain personal data and must be purged from history before the repo is made public.

If you find a personal data handling issue, raise a pull request with a clear description of the problem and the proposed fix.
