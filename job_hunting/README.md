# job_hunting

Produces tailored, one-page LaTeX CVs for specific job positions. Each CV is derived from `profile.my.md` and `skills.my.md`, then optimised against a parsed job description using Claude Code.

Each file has a `*.sample.*` committed template and a `*.my.*` personal version (gitignored). **`profile.my.md` and `skills.my.md` are required** — `/generateJH` will refuse to run without them. `template.my.tex` and `.env.my` have acceptable fallbacks and can be set up later.

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

`/generateJH` will not run if this file is missing.

### 1.3 Skills inventory (required)

```bash
cp skills.sample.md skills.my.md
```

Open `skills.my.md` and replace the sample content with your real skills, grouped by category. Only skills listed here may appear in any generated CV — this is the canonical gate.

`/generateJH` will not run if this file is missing.

### 1.4 CV template (optional)

```bash
cp template.sample.tex template.my.tex
```

Edit `template.my.tex` to customise font, margins, or section order. If you skip this step, `template.sample.tex` is used as the fallback.

### 1.5 Docker

Docker must be running. The `latex-jh` container is started automatically by `/startJH` — no manual setup needed.

---

## Step 2 — Start a session

Run in Claude Code:

```
/startJH
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

Run in Claude Code:

```
/generateJH <job URL>
```

or paste the full job description text directly after `/generateJH`.

If `profile.my.md` or `skills.my.md` are missing, the command stops immediately with setup instructions before doing any work.

Claude will:
1. Parse the job description and extract ATS keywords
2. Score the fit against your skills (flags if below 60%)
3. **Stop and show you the planned tech stack — you confirm or adjust before anything is written**
4. Register the job in `jobs.md` with a generated ID (e.g. `ENG-A01`)
5. Write `cv/ENG-A01/CV.tex` using your template and profile — personal details are placeholders
6. Run quality checks (1-page fit, ATS coverage, no floating skills, no banned words)
7. Compile to `cv/ENG-A01/CV.pdf` with your real details substituted from `.env.my`

If the PDF comes out at 2 pages, Claude will tighten spacing and recompile automatically.

---

## Step 4 — Recompile (if needed)

If you edit `CV.tex` manually and need to recompile:

```
/compileJH ENG-A01
```

---

## Step 5 — End the session

```
/stopJH
```

This stops the Docker container and saves a session handoff so `/startJH` can resume next time.

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
| `profile.my.md` | **Required** — `/generateJH` blocks if missing |
| `skills.my.md` | **Required** — `/generateJH` blocks if missing |
| `template.my.tex` | Optional — falls back to `template.sample.tex` |
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
| `compile.sh` | Substitutes `.env.my` values and compiles via the Docker container |
| `CLAUDE.md` | Full CV generation workflow — `/generateJH` follows this spec |
| `.claude/commands/` | Slash commands: `startJH`, `stopJH`, `generateJH`, `compileJH` |

Job ID format: `{DEPT}-{ALPHA}{NN}` — e.g. `ENG-A01`, `DAT-B03`.

---

## Dependencies

- **Docker** — must be running; `texlive/texlive:latest` image pulled on first `/startJH`
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
