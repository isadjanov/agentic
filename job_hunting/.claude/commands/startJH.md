Start the CV generation session: ensure the latex container is up, validate required files are ready, and remind the user where they left off.

## Steps

### 1 — Start the latex container

```bash
docker start latex-jh 2>/dev/null || docker run -d --name latex-jh --restart unless-stopped \
  -v "$(pwd)":/workspace \
  --entrypoint tail \
  texlive/texlive:latest -f /dev/null
```

Verify it is running:
```bash
docker ps --filter name=latex-jh --format "{{.Names}}\t{{.Status}}"
```

If the container is not running after both attempts, report the error and stop — the session cannot proceed without it.

Note: the container is named `latex-jh` (separate from the `latex` container used by the `lnkd` module).

### 2 — Validate required files

The convention: `*.my.*` is the user's personal file (gitignored); `*.sample.*` is the committed template.
`profile.my.md` and `skills.my.md` are **required** — falling back to sample data produces a CV for a
fictional person, not the user. `/generateJH` will refuse to run without them.

Check the following:

**Profile** — check for `profile.my.md`:
```bash
test -f profile.my.md && echo "personal" || (test -f profile.sample.md && echo "sample-fallback" || echo "missing")
```
- `personal` — ✅ ready
- `sample-fallback` — ❌ BLOCKED: "`profile.my.md` not found. `/generateJH` will not run until you create it:
  `cp profile.sample.md profile.my.md` — then replace with your real work history and STAR stories."
- `missing` — ❌ ERROR: "`profile.sample.md` not found. Repository may be incomplete."

**Skills** — check for `skills.my.md`:
```bash
test -f skills.my.md && echo "personal" || (test -f skills.sample.md && echo "sample-fallback" || echo "missing")
```
- `personal` — ✅ ready
- `sample-fallback` — ❌ BLOCKED: "`skills.my.md` not found. `/generateJH` will not run until you create it:
  `cp skills.sample.md skills.my.md` — then replace with your real canonical skills list."
- `missing` — ❌ ERROR: "`skills.sample.md` not found. Repository may be incomplete."

**Template** — check for `template.my.tex`:
```bash
test -f template.my.tex && echo "personal" || echo "sample-fallback"
```
- `personal` — ✅ using customised template
- `sample-fallback` — ⚠ using `template.sample.tex`; optional: `cp template.sample.tex template.my.tex` to customise layout

**Personal details** — check for `.env.my`:
```bash
test -f .env.my && echo "exists" || echo "missing"
```
- `exists` — ✅ ready
- `missing` — ⚠ CVs will compile with placeholder text. `cp .env.sample .env.my` and fill in your details.

### 3 — Check last session

Read `last_session.md` in the current working directory.

If the file exists, show the **Next step** section so the user knows where they left off.

If the file does not exist, tell the user this is a fresh session.

### 4 — Print session summary

```
Latex container:  running / ERROR: <message>
profile.my.md:    ✅ personal  /  ❌ MISSING — cp profile.sample.md profile.my.md then edit
skills.my.md:     ✅ personal  /  ❌ MISSING — cp skills.sample.md skills.my.md then edit
template.my.tex:  ✅ personal  /  ⚠ sample (cp template.sample.tex template.my.tex to customise)
.env.my:          ✅ exists    /  ⚠ missing — cp .env.sample .env.my then fill in details
Last session:     <Next step content or "fresh session">
```

If any ❌ items are present, end with:
```
Session NOT ready — fix the ❌ items above before running /generateJH.
```

Otherwise end with:
```
Session ready. Run /stopJH when finished.
```
