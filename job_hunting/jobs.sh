#!/usr/bin/env bash
# Serialised mutations of jobs.md.
#
# Every write to jobs.md must go through this script. It holds an exclusive lock
# on .jobs.lock — a separate, never-rewritten file — for the whole read/modify/write
# cycle, so concurrent sessions cannot lose each other's rows.
#
# Why a separate lock file: `flock -x jobs.md` locks that file's *inode*, but any
# in-place rewrite (sed -i, awk > tmp && mv) replaces the inode. A second session
# would then lock a different object and both would proceed. .jobs.lock is only ever
# opened, never replaced, so its inode is stable.
#
# Usage:
#   ./jobs.sh reserve                       -> prints new ID, appends placeholder row, mkdir findings/ID
#   ./jobs.sh update ID DATE TITLE COMPANY LOCATION MODEL STATUS URL
#   ./jobs.sh status ID NEW_STATUS
#   ./jobs.sh get ID                        -> prints the row (no lock needed, read-only)
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
JOBS="${SCRIPT_DIR}/jobs.md"
LOCK="${SCRIPT_DIR}/.jobs.lock"

touch "${LOCK}"
[[ -f "${JOBS}" ]] || { echo "ERROR: jobs.md not found at ${JOBS}" >&2; exit 1; }

cmd="${1:?Usage: jobs.sh reserve | update | status | get}"
shift

# Rewrite the single row whose prefix is "| ID |". Uses awk with -v so titles and
# companies containing &, /, or \ are never interpreted as replacement syntax.
replace_row() {
  local id="$1" row="$2" tmp
  tmp="$(mktemp "${SCRIPT_DIR}/.jobs.md.XXXXXX")"
  awk -v prefix="| ${id} |" -v row="${row}" '
    substr($0, 1, length(prefix)) == prefix { print row; found = 1; next }
    { print }
    END { if (!found) exit 3 }
  ' "${JOBS}" > "${tmp}" || { rm -f "${tmp}"; echo "ERROR: row for ${id} not found in jobs.md" >&2; exit 3; }
  mv "${tmp}" "${JOBS}"
}

case "${cmd}" in
  reserve)
    exec 9>"${LOCK}"
    flock -x 9
    last=$(grep -oE '^\| ENG-A[0-9]+' "${JOBS}" | grep -oE '[0-9]+$' | sort -n | tail -1 || true)
    # 10# forces base 10 — bare 08/09 are parsed as invalid octal by $(( )) and abort.
    n=$(printf "%02d" $(( 10#${last:-0} + 1 )))
    id="ENG-A${n}"
    printf '| %s | %s | RESERVED | RESERVED | — | — | reserved | — |\n' \
      "${id}" "$(date +%Y-%m-%d)" >> "${JOBS}"
    mkdir -p "${SCRIPT_DIR}/findings/${id}"
    flock -u 9
    echo "${id}"
    ;;

  update)
    id="${1:?ID required}"; date="${2:?date required}"; title="${3:?title required}"
    company="${4:?company required}"; location="${5:-—}"; model="${6:-—}"
    status="${7:-new}"; url="${8:-—}"
    exec 9>"${LOCK}"
    flock -x 9
    replace_row "${id}" "| ${id} | ${date} | ${title} | ${company} | ${location} | ${model} | ${status} | ${url} |"
    flock -u 9
    echo "${id} updated"
    ;;

  status)
    id="${1:?ID required}"; st="${2:?status required}"
    exec 9>"${LOCK}"
    flock -x 9
    tmp="$(mktemp "${SCRIPT_DIR}/.jobs.md.XXXXXX")"
    awk -v prefix="| ${id} |" -v st="${st}" 'BEGIN { FS = OFS = "|" }
      substr($0, 1, length(prefix)) == prefix && NF >= 9 { $8 = " " st " "; found = 1 }
      { print }
      END { if (!found) exit 3 }
    ' "${JOBS}" > "${tmp}" || { rm -f "${tmp}"; flock -u 9; echo "ERROR: row for ${id} not found" >&2; exit 3; }
    mv "${tmp}" "${JOBS}"
    flock -u 9
    echo "${id} -> ${st}"
    ;;

  get)
    grep -E "^\| ${1:?ID required} \|" "${JOBS}" || { echo "ERROR: ${1} not in jobs.md" >&2; exit 3; }
    ;;

  *)
    echo "ERROR: unknown command '${cmd}' (expected reserve|update|status|get)" >&2
    exit 2
    ;;
esac
