#!/usr/bin/env bash
# Derives workflow state for a job from artifacts on disk, so /apply can resume
# where it stopped instead of restarting. No separate state file is kept — every
# stage already leaves a distinct artifact, and derived state cannot go stale.
#
# Usage:
#   ./state.sh state ID     -> fresh | analysis_incomplete | gaps_unresolved | need_cv | need_review | done
#   ./state.sh hash FILE    -> normalised SHA-256 of a raw JD (whitespace/case collapsed)
#   ./state.sh find-dup FILE-> IDs whose stored jd_hash matches FILE (one per line, may be empty)
#   ./state.sh detail ID    -> human-readable one-liner for the resume banner
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "${SCRIPT_DIR}"

REQUIRED_SECTIONS=('## Raw JD' '## Fit Score' '## Planned Stack' '## Gap Table' '## Recruiter Priority Stack')

# Collapse formatting noise so a re-paste of the same listing hashes identically:
# lowercase, strip all non-alphanumerics. Survives whitespace, bullet and quote changes.
normalise_hash() {
  tr '[:upper:]' '[:lower:]' < "$1" | tr -cd '[:alnum:]' | sha256sum | cut -d' ' -f1
}

missing_sections() {
  local f="$1" s out=""
  for s in "${REQUIRED_SECTIONS[@]}"; do
    grep -qF "${s}" "${f}" || out="${out}${s}, "
  done
  printf '%s' "${out%, }"
}

# Unresolved = the Confirmed? cell carries no answer at all.
# Deliberately permissive: the existing corpus uses free text there — "—" for rows
# that need no answer (already in skills.md) and things like "known gap" for rows
# answered in prose. Only a blank/?/unknown/tbd cell counts as an open question.
unresolved_gaps() {
  awk -F'|' '
    /^## Gap Table/      { in_table = 1; next }
    in_table && /^## /   { in_table = 0 }
    in_table && /^\|/ {
      conf = tolower($4)
      gsub(/^[ \t]+|[ \t]+$/, "", conf)
      req = $2
      gsub(/^[ \t]+|[ \t]+$/, "", req)
      if (req == "JD requirement" || req ~ /^-+$/ || req == "") next
      if (conf == "" || conf == "?" || conf == "unknown" || conf == "tbd") n++
    }
    END { print n + 0 }
  ' "$1"
}

cmd="${1:?Usage: state.sh state | hash | find-dup | detail}"

case "${cmd}" in
  state)
    id="${2:?ID required}"
    d="findings/${id}"
    a="${d}/analysis.md"
    # Latest artifact wins. Progress is monotonic: a compiled PDF means every earlier
    # stage was passed, so a later artifact must never be overridden by an earlier check.
    [[ -f "${d}/.compiled" ]]  && { echo done;                exit 0; }
    [[ -f "${d}/CV.tex" ]]     && { echo need_review;         exit 0; }
    [[ -f "${a}" ]]            || { echo fresh;               exit 0; }
    [[ -z "$(missing_sections "${a}")" ]] || { echo analysis_incomplete; exit 0; }
    [[ "$(unresolved_gaps "${a}")" == "0" ]] || { echo gaps_unresolved;  exit 0; }
    echo need_cv
    ;;

  detail)
    id="${2:?ID required}"
    a="findings/${id}/analysis.md"
    st="$("${SCRIPT_DIR}/state.sh" state "${id}")"
    hdr="—"; [[ -f "${a}" ]] && hdr="$(head -1 "${a}" | sed 's/^# //')"
    case "${st}" in
      fresh)              msg="no analysis yet — starting from scratch" ;;
      analysis_incomplete) msg="analysis incomplete (missing: $(missing_sections "${a}")) — re-running analysis" ;;
      gaps_unresolved)    msg="$(unresolved_gaps "${a}") gap question(s) open — resuming at Stop 1" ;;
      need_cv)            msg="analysis confirmed, no CV.tex — resuming at CV writing" ;;
      need_review)        msg="CV.tex written, not compiled — resuming at Stop 2 (bullet review)" ;;
      done)               msg="complete — CV compiled $(grep -oE '^compiled=.*' "findings/${id}/.compiled" | cut -d= -f2-), $(grep -oE '^pages=.*' "findings/${id}/.compiled" | cut -d= -f2-) page(s)" ;;
    esac
    echo "${id} — ${hdr} — ${msg}"
    ;;

  hash)
    normalise_hash "${2:?file required}"
    ;;

  find-dup)
    h="$(normalise_hash "${2:?file required}")"
    grep -l "^jd_hash: ${h}$" findings/*/analysis.md 2>/dev/null \
      | sed 's|^findings/||; s|/analysis.md$||' || true
    ;;

  *)
    echo "ERROR: unknown command '${cmd}' (expected state|hash|find-dup|detail)" >&2
    exit 2
    ;;
esac
