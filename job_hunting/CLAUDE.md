# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Module purpose

Handles two workflows:
- **Outbound** — produces tailored, one-page LaTeX CVs for positions you apply to, derived from `profile.my.md` and optimised against a parsed job description.
- **Inbound** — interview preparation for positions where the employer contacted you first. No CV generation; goes straight to analysis and stage-by-stage prep files.

---

## Hard rules

**NEVER read `.env.my`.** This file contains real personal data and must never be passed to Claude.
If any step requires personal details, use the placeholders (`YOUR NAME`, `YOUR@EMAIL.COM`, `+00 000 000 0000`, `Your City`) and let `compile.sh` substitute them at compile time.

---

## Session commands

| Command | When to use |
|---|---|
| `/start_jh` | Start of every session — boots `latex-jh` container, validates files, shows pending analyses and last session state |
| `/stop_jh` | End of session — stops container, writes `last_session.md` handoff |
| `/analyze_job_description_jh {url\|text}` | Phase 1 of batch workflow — parallel-safe, runs Steps 1–3, saves result to `cv/.pending/{slug}/analysis.md` |
| `/generate_cv_jh [{url\|text}]` | Phase 2 — picks up pending analysis (or takes fresh input), runs Steps 4–8, compiles PDF |
| `/recompile_cv {ID}` | Re-runs `compile.sh` on an existing `CV.tex` without regenerating content |

**Outbound batch workflow (run multiple JDs in parallel):**
```
/analyze_job_description_jh <url1>   # run N of these first
/analyze_job_description_jh <url2>
/generate_cv_jh                       # then run sequentially, one per job
```

**Inbound workflow (employer contacted you — no CV needed):**
```
1. Gather materials — hiring guide PDF, job email, any JD the employer shared
2. Register in jobs.md with status: interviewing
3. mkdir findings/{ID}/
4. Agentic analysis — read all materials, create findings/{ID}/analysis.md
   (company facts, tech stack, interview process, decisions e.g. minimal stack)
5. Create stage-specific prep files as needed:
   findings/{ID}/prep_screening.md, prep_build_it.md, prep_system_design.md, etc.
```
No slash command — this is pure agentic work driven by what the employer sends.

---

## File convention

`*.sample.*` files are committed templates. Users copy them to `*.my.*` and fill in real content. Commands use `*.my.*` if present, fall back to `*.sample.*` otherwise.

## File structure

| File / Folder | Purpose |
|---|---|
| `profile.my.md` | Your experience stories and STAR narratives (gitignored) |
| `skills.my.md` | **Canonical skills inventory** — only skills listed here may appear in a CV (gitignored) |
| `jobs.md` | Job register — index table + full detail section per position (gitignored) |
| `cv/{ID}/` | One folder per job; contains `CV.tex`, `CV.pdf`, and LaTeX aux files (gitignored) |
| `findings/{ID}/` | Claude's read/write working space per job — analysis and prep files. Exists because `cv/` is read-blocked for Claude. Used for both workflows. |
| `.env.my` | Personal details (name, email, phone, city) — **gitignored, never read by Claude** |
| `.env.sample` | Template to copy to `.env.my` |
| `profile.sample.md` | Sample work history — copy to `profile.my.md` to get started |
| `skills.sample.md` | Sample skills inventory — copy to `skills.my.md` to get started |
| `template.sample.tex` | Sample CV format — copy to `template.my.tex` to customise |
| `compile.sh` | Substitutes `.env.my` values into placeholders and compiles to PDF |

CV file naming: `CV.tex` / `CV.pdf` — job ID lives in the folder name only, never in the filename.

**`profile.my.md` is not exhaustive.** Always cross-reference against `skills.my.md` before deciding a technology is absent. When the user confirms a new skill, add it to `skills.my.md` immediately before writing the CV.

---

## Docker setup (one-time)

A long-running container named `latex-jh` eliminates cold-start overhead (~60s → ~5s per compile).

```bash
docker run -d --name latex-jh --restart unless-stopped \
  -v "$(pwd)":/workspace \
  --entrypoint tail \
  texlive/texlive:latest -f /dev/null
```

Start at the beginning of each CV session:
```bash
docker start latex-jh
```

Stop at the end:
```bash
docker stop latex-jh
```

---

## Personal details setup (one-time)

Personal details are stored in `.env.my` and substituted at compile time by `compile.sh`.
Claude never reads `.env.my` — the privacy boundary is enforced by the script.

```bash
cp .env.sample .env.my
# edit .env.my: set CV_NAME, CV_EMAIL, CV_PHONE, CV_CITY, CV_LINKEDIN

cp profile.sample.md profile.my.md
# replace with your real work history

cp skills.sample.md skills.my.md
# replace with your real skill inventory
```

## Compile command

Use `/recompile_cv {ID}` — it runs `compile.sh`, which:
1. Loads `.env.my`
2. Substitutes `YOUR NAME`, `YOUR@EMAIL.COM`, `+00 000 000 0000`, `Your City` in a temp copy
3. Runs `pdflatex` twice inside the `latex-jh` container
4. Moves the output to `cv/{ID}/CV.pdf` and removes the temp files

Always runs **twice** — first pass builds aux/outline files, second resolves references.
Output must say `(1 page, ...)` — if 2 pages, tighten margins/spacing/bullets.

---

## Job ID format: `{DEPT}-{ALPHA}{NN}`

- `DEPT` — `ENG`, `SLS`, `MKT`, `DSG`, `OPS`, `DAT`, `PRD`, `OTH`
- `ALPHA` — A–Z batch letter
- `NN` — 01–99 sequence

Example: `ENG-A01`, `DAT-B03`

---

## `/generate_cv_jh` command — CV production workflow

When the user runs `/generate_cv_jh` or provides a job URL/description, execute the following steps in order.

---

### Step 1 — Fetch and parse job listing

```bash
curl -s '{url}' -A "Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 Chrome/120.0.0.0 Safari/537.36"
```

For Next.js pages (Greenhouse, most career sites), extract from `__NEXT_DATA__` script tag.

**Greenhouse widget pages** — any URL containing `gh_jid=` will not render via WebFetch.
Fetch directly from the Greenhouse API instead:
```
https://boards-api.greenhouse.io/v1/boards/{company_slug}/jobs/{job_id}
```

---

### Step 2 — JD analysis (before writing anything)

**A. Extract ATS keywords** — exact spelling/casing from JD:
- Hard skills: languages, frameworks, tools
- Seniority signals: "lead", "senior", "8+ years"
- Domain vocabulary: industry-specific terms
- Role keywords: "architecture", "modernisation", "mentoring"

**B. Define JD Spirit** — one sentence: what kind of engineer does this role actually want?
(e.g. "A Java architect who can own a complex codebase and grow a team")

**C. Identify Profile ID** — select one:
- `backend` — Backend Engineer, Software Engineer, API Engineer
- `techlead` — Tech Lead, Staff, Senior+ with mentoring emphasis
- `platform` — DevOps/SRE, Infrastructure, Platform Engineer
- `fullstack` — Full-Stack, Product Engineer
- `ai` — AI/ML Engineer, AI-native role

**D. Recruiter Priority Stack** — rank the top 3–5 filters the recruiter uses to screen CVs.
These are the only terms bolded in the Summary. Metrics are bolded freely in bullets.

**E. Anti-signals** — identify any elements in the profile that could be misread for this role.
Flag them — they must be suppressed or reframed in the CV.

**F. Gap analysis** — map every JD hard requirement against `skills.my.md`:

| JD requirement | In skills.md? | Action |
|---|---|---|
| Kubernetes | Yes | Include |
| GraphQL | No | **Ask user before omitting** |

Rules:
- Do NOT silently drop a requirement.
- If a skill is plausible given the user's background, ask — `profile.md` is incomplete.
- Get confirmation on all unknowns before writing.

---

### Step 3 — Fit score + go/no-go decision

Score the role against confirmed skills only.
- **80–90%** — proceed, strong fit
- **60–80%** — proceed if core matches (language family, cloud, domain); gaps must be tooling-level
- **Below 60%** — flag to user before investing time in the CV

Classify gaps by severity:
- **T1** — must address; blocks the application if absent
- **T2** — addressable; tooling-level gap, bridgeable during interview prep
- **T3** — nice-to-have; low risk if absent

---

### Step 4 — Tech stack confirmation (STOP and wait for user)

Before writing anything, present the planned CV tech stack:

```
Planned Skills section:
  Languages:          [list]
  Frameworks:         [list]
  Distributed/Infra:  [list]
  Databases:          [list]
  Practices:          [list]

Suppressed (anti-signals): [list]
Dropped (not in skills.md / not JD-matched): [list]
```

**Do not proceed to Step 5 until the user confirms the stack.**
If user confirms a new skill, add it to `skills.my.md` before writing the CV.

---

### Step 5 — Register job in jobs.md

Add **index table row only** (ID, date, title, company, location, model, status, URL).
Status lifecycle: `new → applied → interviewing → offer / rejected`.

Defer until interview is arranged: full detail section, `prep_todos.md`, `companies.md` entry.

---

### Step 6 — Create LaTeX CV

Base on `profile.my.md` (or `profile.sample.md` if absent) and `skills.my.md` (or `skills.sample.md` if absent). One folder per job: `cv/{ID}/CV.tex`.

**Read the active template first** — use `template.my.tex` if it exists, otherwise fall back to `template.sample.tex`. Use its preamble (font, packages, margins, formatting) verbatim and follow the section order defined by the `% ── SECTION ──` markers. Never override it.

```bash
test -f template.my.tex && echo "template.my.tex" || echo "template.sample.tex"
```

**Personal details — always use placeholders. Never write real names, emails, or phone numbers.**

The header placeholders must be preserved exactly — `compile.sh` substitutes them from `.env.my` at compile time:

| Placeholder | Substituted from |
|---|---|
| `YOUR NAME` | `CV_NAME` |
| `YOUR@EMAIL.COM` | `CV_EMAIL` |
| `+00 000 000 0000` | `CV_PHONE` |
| `Your City` | `CV_CITY` |
| `YOURLINKEDIN` | `CV_LINKEDIN` |

**`YOUR SUBTITLE` is different** — it is JD-specific role positioning (e.g. `Senior Java Engineer · Microservices & AWS`) written by Claude directly into `CV.tex`. It is not a compile.sh placeholder and not from `.env.my`.

**Mapping profile → JD:**
- Match language *family* first (JVM, Python) — exact language is secondary
- List every cloud service in the JD explicitly by name — no generic "AWS experience"
- Only list skills that appear in Experience bullets — no floating skills
- Skills section order: Recruiter Priority Stack first, then remaining JD-matched skills
- Include all STAR stories from `profile.my.md` relevant to the role's implied values
- Suppress anti-signals identified in Step 2E
- Batch all edits before compiling — do not compile after every small change

**Bullet concreteness test — every bullet must have all three:**
1. **Starting condition** — specific state before the action (include a number if available)
2. **Specific mechanism** — what exactly was done; if a choice was made between options, state what was rejected and why
3. **Observable change** — before → after, or specific measurable behaviour that changed

**Evidence Gate — before writing the Summary:**
Every claim in the Summary must trace to a finalised experience bullet.
"Currently learning" or extra-curricular items are NOT evidence.

**JD Spirit check — before finalising:**
Re-read the complete CV draft as a recruiter. Does it match the JD Spirit from Step 2B?
If not, reorder bullets or reframe the Summary.

**Experience years rules:**
- Calculate durations exactly from start/end months — do not round up
- Summary years must be derivable from the experience section dates
- "Backend engineering" covers pure backend roles only; use "software engineering" when including non-backend technical roles in the count

---

### Step 6b — Experience review (STOP and wait for user)

After writing `CV.tex`, present all experience bullets in plain text (not LaTeX) for review:

```
EPAM Systems — Lead Developer (May 2021 – Present)
  • [bullet 1]
  • [bullet 2]
  ...

Sber — Java Backend Developer (Sep 2019 – May 2021)
  • [bullet 1]
  ...
```

Ask: "Do the bullets look correct? Confirm or tell me what to change."

**Do not compile until the user confirms the experience section.**
Apply all requested edits in one batch, then proceed to Step 8.

---

### Step 7 — First interview (when user says "first interview with [company]")

Output a **company positioning block** immediately, before anything else:

```
[Company] is [one sentence: what they do, scale/stage, domain].
I'm applying because [one sentence: why this role fits — connect to candidate's background].
```

Then update `jobs.md` status to `interviewing` and create `findings/{ID}/prep_todos.md` with:
- **CV claims that need defending** — technologies cited in the CV where interview questions are likely
- **Self-learning items** — skills cited from partial experience that need deepening
- **Company/product knowledge** — minimum viable understanding of what the company builds

Format: grouped by topic, each item as a `- [ ]` checkbox with a specific question or task.

---

### Step 8 — Quality checks (run all before compiling final PDF)

| Check | What to look for |
|---|---|
| LaTeX errors | `Overfull`, `Undefined control sequence`, missing `&` in tabularx |
| 1-page fit | Output must say `(1 page, ...)` |
| ATS coverage | Every ATS keyword from Step 2A appears verbatim in the CV |
| Skills audit | Every skill in Skills section appears in an Experience bullet |
| JD coverage | Every JD hard requirement appears in Skills or an Experience bullet |
| Floating skills | Skills section contains only technologies backed by experience bullets |
| Anti-signals | No suppressed element appears in the CV |
| Years consistency | Summary years match date arithmetic from experience section |
| Evidence gate | Every Summary claim traces to a finalised bullet |
| Bullet priority | Order by descending relevance to this role's JD |
| Banned words | No banned words, adjectives, or generic verbs (see Writing Rules below) |

---

## Writing rules

### Banned words — never use
`proactively`, `leveraged`, `spearheaded`, `real-world`, `accelerate velocity`, `production-grade`

### Banned adjectives — never use
`strong`, `deep expertise`, `thrives`, `passionate`, `proven track record`, `extensive experience`,
`highly skilled`, `proficient`, `exceptional`

### Banned generic verbs — replace with specifics

| Banned | Replace with |
|---|---|
| `improved` | `reduced from N to M`, `restructured`, `cut` |
| `maintained`, `ensured`, `supported` | `diagnosed`, `defended`, `kept X below Y` |
| `worked on`, `contributed to`, `helped` | state ownership directly |
| `leveraged`, `utilised` | name the thing used directly |
| `built`, `developed`, `created` | keep, but follow with specific mechanism + why |

### Bolding rules
- **Summary**: bold only Recruiter Priority Stack terms (top 3–5 from Step 2D)
- **Bullets**: bold metrics freely; bold technical terms only if they appear in JD

---

## Established rules

| Rule | Why |
|---|---|
| Platform SLAs → `"contributing to 99.99% SLA"` not `"achieved X% uptime"` | Uptime is a team metric, not personal |
| Replace OOP/SOLID/KISS with specific architectural actions | Baseline expectations, not differentiators |
| Run pdflatex twice | First pass builds aux, second resolves outlines |
| Every technology named = interview prep overhead | Only name technologies explicitly asked for in the JD |
| Only include experience entries that add JD task coverage | Drop roles already covered by more recent entries |
| Subtitle = positioning, not job title | Change per role: `Senior Backend Engineer` vs `Engineer · Founder · AI` |
| Academic metrics (MRR@10) → replace with operational ones | Reviewers will ask how you computed ground truth — if you can't answer precisely, it reads as fabricated |

---

## Application strategy

Apply to positions matching **60–80%** of the profile.
Core must match: language family (JVM, Python, Go), cloud provider, system design depth.
Gaps acceptable if tooling/framework-level. Gaps are blockers if foundational.
