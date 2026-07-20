# TODO — workflow enhancements

Audit of the module against its own data, 2026-07-20. Evidence taken from 88 `findings/` folders
and ~94 `jobs.md` rows, not from the docs.

---

## Findings

### 1. `jobs.md` is structurally corrupt
69 of ~94 index rows sit **below** the `## Job Details` marker (`jobs.md:35`). Commands append
blind to EOF, so the index table effectively ends at ENG-A26 and every row since is orphaned
Markdown outside the table.

Also: ENG-A01–A06 appear in the register with no matching `findings/` folder.

### 2. No outcome loop
Status counts: **50 applied · 5 interviewing · 1 rejected · 37 new**.

Statuses are write-once. Nothing records a rejection, a ghosting, or the date either happened.
After ~90 applications the module cannot answer:
- which profile ID (`backend` / `techlead` / `ai` / …) converts
- which fit-score band converts
- whether German-heavy JDs ever reply

The most valuable dataset this module could produce is being discarded.

### 3. 42% of analysis work is never used
37 analyses (`status: new`) never became a CV, and they age silently — a JD analyzed 2026-06-14
is likely closed by now. No expiry, no triage, no archive.

### 4. The corpus is a goldmine and nothing reads it
87 of 88 `analysis.md` files carry the **same 8 headings** (`Raw JD`, `ATS Keywords`, `JD Spirit`,
`Profile ID`, `Recruiter Priority Stack`, `Anti-signals`, `Gap Table`, `Fit Score`). It is a
structured database in Markdown.

Aggregating the gap tables alone yields a demand-ranked learning backlog:

| Gap | Count |
|---|---|
| Kubernetes | 21 |
| Kotlin | 18 |
| Kafka | 16 |
| Go | 14 |
| German | 14 |
| TypeScript | 13 |
| Scala | 10 |
| Angular | 10 |

This has never been computed.

### 5. No duplicate-company guard
Anthropic ×3, Staffbase ×2, neoshare AG ×2 — different IDs, different CVs, same company.
Nothing warns before a second application goes out.

### 6. Fit scores appear inflated *(inference, not established fact)*
20 of 88 analyses land on exactly **85%**; median ≈ 80%; only 9 score below 60%.
Stated strategy is "apply at 60–80%", yet most scores sit at or above that ceiling.
A score that rarely says no is not filtering — it is post-hoc justification.

---

## Proposals, by leverage

### A. Outcome tracking + `/close_jh {ID} {outcome}` — **highest value, smallest change**
- [ ] Add `applied_date` and `outcome_date` columns to the `jobs.md` index
- [ ] New command `/close_jh {ID} {rejected|ghosted|interviewing|offer}`
- [ ] New command `/stats_jh` — reply rate sliced by fit band, profile ID, language requirement,
      company size
- [ ] Backfill outcomes for the 50 `applied` rows as far as memory/email allows

Within ~20 more applications this shows where effort is being wasted. Today every application is
a shot in the dark whose target is never checked.

### B. Make `jobs.md` generated, not appended — **prerequisite for A being trustworthy**
- [ ] Treat `findings/*/analysis.md` frontmatter as the source of truth
- [ ] Script rebuilds the index table from `findings/` (corruption becomes impossible)
- [ ] Fold the duplicate-company check into the rebuild
- [ ] Reconcile ENG-A01–A06 (register rows with no `findings/` folder)
- [ ] Show diff before overwriting the register

### C. `/review_market_jh` — corpus aggregator
- [ ] Read all 88 gap tables + ATS keyword blocks
- [ ] Output: top gaps weighted by fit score; keyword frequency vs `skills.my.md`;
      which single skill would lift the most sub-70% roles over the line

Converts 88 one-off analyses into one strategic document.

### D. Calibrate the fit score against outcomes
- [ ] Once A has data, backtest: do 85% roles reply more than 70% roles?
- [ ] If not, replace the rubric with the 2–3 features that actually predict a reply

### E. Staleness sweep in `/start_jh`
- [ ] Flag `new` analyses older than 21 days — generate now or archive
- [ ] Stops the pending queue growing unboundedly

### F. Harden the language claim
German is a gap in 14 analyses, and ENG-A75 was submitted claiming **B1** against a recorded
**A2–B1** in `skills.my.md`. Systemic honesty risk, not a slip.
- [ ] Step 8 quality check: refuse a language level higher than the one in `skills.my.md`

---

## Recommended order

**A + B together.** B makes A reliable; A is the only change that makes C–F possible.
Everything else optimises a pipeline whose results are never measured.
