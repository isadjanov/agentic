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

For each file, the convention is: `*.my.*` is the user's personal file (gitignored); `*.sample.*` is the committed fallback. Commands use the personal file if present, otherwise the sample.

Check the following:

**Profile** — check for `profile.my.md`:
```bash
test -f profile.my.md && echo "personal" || (test -f profile.sample.md && echo "sample-fallback" || echo "missing")
```
- `personal` — ready, using user's own work history
- `sample-fallback` — warn: "Using sample profile. Copy `profile.sample.md` to `profile.my.md` and replace with your real work history."
- `missing` — error: "profile.sample.md not found. Repository may be incomplete."

**Skills** — check for `skills.my.md`:
```bash
test -f skills.my.md && echo "personal" || (test -f skills.sample.md && echo "sample-fallback" || echo "missing")
```
- Same reporting pattern as profile above, substituting skills file names.

**Template** — check for `template.my.tex`:
```bash
test -f template.my.tex && echo "personal" || echo "sample-fallback"
```
- `personal` — user has a customised template, report as active
- `sample-fallback` — using `template.sample.tex`; tell user: "To customise: `cp template.sample.tex template.my.tex`"

**Personal details** — check for `.env.my`:
```bash
test -f .env.my && echo "exists" || echo "missing"
```
- `missing` — warn: "`.env.my` not found — CVs will compile with placeholder text. Copy `.env.sample` to `.env.my` and fill in your details."

### 3 — Check last session

Read `last_session.md` in the current working directory.

If the file exists, show the **Next step** section so the user knows where they left off.

If the file does not exist, tell the user this is a fresh session.

### 4 — Print session summary

```
Latex container:  running / ERROR: <message>
profile.my.md:    personal / sample-fallback (copy profile.sample.md to profile.my.md) / missing
skills.my.md:     personal / sample-fallback (copy skills.sample.md to skills.my.md) / missing
template.my.tex:  personal / sample-fallback (cp template.sample.tex template.my.tex to customise)
.env.my:          exists / missing (copy .env.sample to .env.my and fill in details)
Last session:     <summary or "fresh session">
```

Remind the user to run `/stopJH` when finished.
