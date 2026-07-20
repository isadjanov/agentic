#!/usr/bin/env bash
# Compiles findings/{ID}/CV.tex with personal details substituted from .env.my.
# Output PDF is written to cv/{ID}/CV.pdf. Claude never touches the cv/ folder.
# Claude never reads .env.my — substitution happens entirely in this script.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ID="${1:?Usage: ./compile.sh <JOB_ID>  e.g. ./compile.sh ENG-A01}"

ENV_FILE="${SCRIPT_DIR}/.env.my"
if [[ ! -f "${ENV_FILE}" ]]; then
  echo "ERROR: .env.my not found. Copy .env.sample to .env.my and fill in your details."
  exit 1
fi

# shellcheck source=/dev/null
source "${ENV_FILE}"

: "${CV_NAME:?CV_NAME not set in .env.my}"
: "${CV_EMAIL:?CV_EMAIL not set in .env.my}"
: "${CV_PHONE:?CV_PHONE not set in .env.my}"
: "${CV_CITY:?CV_CITY not set in .env.my}"
CV_LINKEDIN="${CV_LINKEDIN:-}"

TEX_DIR="${SCRIPT_DIR}/findings/${ID}"
TEX_FILE="${TEX_DIR}/CV.tex"

if [[ ! -f "${TEX_FILE}" ]]; then
  echo "ERROR: ${TEX_FILE} not found. Run /generate_cv_jh first to generate the CV."
  exit 1
fi

if ! docker ps --filter name=latex-jh --filter status=running --format "{{.Names}}" | grep -q latex-jh; then
  echo "ERROR: latex-jh container is not running. Run /start first."
  exit 1
fi

# Escape &, \, and the | delimiter so sed handles special chars in values safely
escape_sed() { printf '%s' "$1" | sed 's/[&\|]/\\&/g'; }

TMP_TEX="${TEX_DIR}/_CV_build.tex"
trap 'rm -f "${TEX_DIR}/_CV_build."*' EXIT

sed \
  -e "s|YOUR NAME|$(escape_sed "${CV_NAME}")|g" \
  -e "s|YOUR@EMAIL\.COM|$(escape_sed "${CV_EMAIL}")|g" \
  -e "s|+00 000 000 0000|$(escape_sed "${CV_PHONE}")|g" \
  -e "s|Your City|$(escape_sed "${CV_CITY}")|g" \
  -e "s|YOURLINKEDIN|$(escape_sed "${CV_LINKEDIN}")|g" \
  "${TEX_FILE}" > "${TMP_TEX}"

BUILD_LOG="$(docker exec -w "/workspace/findings/${ID}" latex-jh \
  bash -c "pdflatex -interaction=nonstopmode _CV_build.tex && \
           pdflatex -interaction=nonstopmode _CV_build.tex")"
echo "${BUILD_LOG}"

# "Output written on _CV_build.pdf (1 page, 52341 bytes)." -> 1
PAGES="$(printf '%s' "${BUILD_LOG}" | grep -oE 'Output written on [^(]*\([0-9]+ page' | grep -oE '[0-9]+ page' | grep -oE '[0-9]+' | tail -1 || true)"

OUT_DIR="${SCRIPT_DIR}/cv/${ID}"
mkdir -p "${OUT_DIR}"
mv "${TEX_DIR}/_CV_build.pdf" "${OUT_DIR}/CV.pdf"
rm -f "${TEX_DIR}/_CV_build."*

# Compile stamp. Claude is denied Read(cv/**), so this is how the workflow knows a
# PDF exists without reaching into the private folder. Contains no personal data.
cat > "${TEX_DIR}/.compiled" <<STAMP
id=${ID}
compiled=$(date +%Y-%m-%dT%H:%M:%S%z)
pages=${PAGES:-unknown}
STAMP

echo ""
echo "Done: cv/${ID}/CV.pdf (${PAGES:-?} page(s))"
if [[ "${PAGES:-}" != "1" ]]; then
  echo "WARNING: expected 1 page, got ${PAGES:-unknown} — tighten margins/spacing/bullets and recompile."
fi
