Compile a CV to PDF with personal details substituted from `.env.my`. Usage: `/compile ENG-A01`

The job ID comes from `$ARGUMENTS`. If no ID is provided, list available CVs and ask the user which to compile.

## Steps

### 1 — Resolve job ID

If `$ARGUMENTS` is non-empty, use it as the ID directly.

If `$ARGUMENTS` is empty:
```bash
ls cv/
```
List the available IDs and ask the user which one to compile. Stop here until they reply.

### 2 — Check `.env.my` exists

```bash
test -f .env.my && echo "exists" || echo "missing"
```

If missing, tell the user:
```
.env.my not found. Run this once to set it up:
  cp .env.sample .env.my
  # then edit .env.my with your real name, email, phone, city, and LinkedIn
```
Stop here until they confirm it is created.

### 3 — Run compile script

```bash
bash compile.sh {ID}
```

Stream the output. If the command exits non-zero, report the error verbatim and stop.

### 4 — Check page count

Scan the pdflatex output for the page count line:
- If it says `(1 page, ...)` → report success
- If it says `(2 pages, ...)` or more → warn the user: "CV is N pages — tighten margins, spacing, or bullets and re-run `/compile {ID}`"
- If the page count line is absent → report that the log was inconclusive and ask the user to open the PDF

### 5 — Confirm to user

```
Compiled: cv/{ID}/CV.pdf   [1 page ✓  or  ⚠ N pages — needs trimming]
```
