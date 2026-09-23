#!/usr/bin/env bash
# Rebuild published tables from the S3 DuckDB archives: download, backfill,
# build to CSV + Parquet, verify the two agree.
#
# Restartable at stage level, and within the build stage at table level. Every
# stage appends to logs/BUILD_LOG.tsv and is skipped when already logged OK, so
# re-running after any interruption resumes rather than repeats.
#
# The build tries extract_csv_tables() -- the documented entry point -- and
# falls back to rebuilding 15 tables at a time in short-lived processes. That
# fallback exists because extract_csv_tables() dies intermittently mid-build:
# 2 failures in 14 full-year invocations, not reproducible, cause unknown.
# See dev/UPSTREAM-ISSUES.md EF2-10. When the entry point fails, this script
# logs its exit status and signal -- read those before theorising.
#
# Usage:
#   YEARS="2009 2010" bash dev/run_efile_build.sh
#   EFILE_ROOT=/path/to/build bash dev/run_efile_build.sh
#
# On Windows, Rscript is usually not on PATH under Git Bash -- pass it:
#   RSCRIPT="/c/Program Files/R/R-4.5.3/bin/Rscript.exe" bash dev/run_efile_build.sh
set -uo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
EF2_PKG="${EF2_PKG:-$(cd "$HERE/.." && pwd)}"; export EF2_PKG
ROOT="${EFILE_ROOT:-C:/Users/jlecy/Documents/EFILE_BUILD_SEPT_2026}"; export EFILE_ROOT="$ROOT"
RSCRIPT="${RSCRIPT:-Rscript}"
YEARS="${YEARS:-2009 2010 2011 2012 2013 2014 2015 2016 2017 2018 2019 2020 2021 2022 2023 2024}"
NCHUNK="${NCHUNK:-12}"
BATCH="${BATCH:-15}"
MAXBATCH="${MAXBATCH:-40}"

LOG="$ROOT/logs/BUILD_LOG.tsv"
RCFILE="$ROOT/logs/.last_rc"
mkdir -p "$ROOT/logs" "$ROOT/NEW_TABLES" "$ROOT/duckdb_tmp"

logit() { printf '%s\t%s\t%s\t%s\t%s\n' "$(date '+%Y-%m-%d %H:%M:%S')" "$1" "$2" "$3" "$4" >> "$LOG"; }
done_stage() { [ -f "$LOG" ] && grep -qP "\t$1\t$2\tOK\t" "$LOG"; }

# Run one stage, recording the child's real exit status. Command substitution
# runs this in a subshell, so the status goes through a file rather than a
# variable. A process killed by signal N exits 128+N.
runstage() {
  "$RSCRIPT" "$HERE/build_stage.R" "$1" "$2" "${3:-}" 2>&1 | tr '\r' '\n' \
    | grep -vE "duckdb keeps|^ℹ|^•|temporary directory|removed when the R session"
  local rc="${PIPESTATUS[0]}"
  echo "$rc" > "$RCFILE"
  return "$rc"
}

describe_rc() {
  local rc="$1"
  if [ "$rc" -eq 0 ]; then echo "exit=0"
  elif [ "$rc" -gt 128 ]; then
    local sig=$(( rc - 128 ))
    echo "KILLED_BY_SIGNAL=$sig($(kill -l "$sig" 2>/dev/null || echo unknown)) rc=$rc"
  else echo "exit=$rc"
  fi
}

for Y in $YEARS; do
  if done_stage "$Y" "year"; then echo "== $Y already complete =="; continue; fi
  echo "===================== YEAR $Y ====================="

  # ---- download ----
  if done_stage "$Y" "download"; then echo "-- download already OK"; else
    T0=$(date +%s); OUT=$(bash "$HERE/download_efile_db.sh" "$Y" "$ROOT" "$NCHUNK" 2>&1); RC=$?; T1=$(date +%s)
    echo "$OUT"
    if [ $RC -ne 0 ]; then logit "$Y" download FAIL "$(echo "$OUT" | tail -1)"; exit 1; fi
    logit "$Y" download OK "bytes=$(stat -c %s "$ROOT/$Y/EFILE$Y.duckdb") secs=$((T1-T0))"
  fi

  # ---- backfill ----
  if done_stage "$Y" "backfill"; then echo "-- backfill already OK"; else
    OUT=$(runstage "$Y" backfill); RC=$(cat "$RCFILE"); echo "$OUT"
    if [ "$RC" -ne 0 ]; then logit "$Y" backfill FAIL "$(describe_rc "$RC")"; exit 1; fi
  fi

  # ---- build: documented entry point first, batches as fallback ----
  if done_stage "$Y" "build"; then echo "-- build already OK"; else
    echo "-- attempt 1: extract_csv_tables() in one process"
    OUT=$(runstage "$Y" buildall); RC=$(cat "$RCFILE"); echo "$OUT"
    pend=$(echo "$OUT" | grep -oP 'PENDING=\K[0-9]+' | tail -1); [ -z "$pend" ] && pend=999

    if [ "$pend" -ne 0 ]; then
      # This is the EF2-10 crash. Record how the process died -- that detail was
      # missing on the TY2016 occurrence and made it undiagnosable.
      logit "$Y" buildall WARN "pending=$pend $(describe_rc "$RC")"
      echo "-- entry point did not finish ($(describe_rc "$RC")); falling back to batches"
    fi

    i=0
    while [ "$pend" -ne 0 ] && [ "$i" -lt "$MAXBATCH" ]; do
      i=$((i+1))
      OUT=$(runstage "$Y" build "$BATCH"); RC=$(cat "$RCFILE"); echo "$OUT"
      NEWPEND=$(echo "$OUT" | grep -oP 'PENDING=\K[0-9]+' | tail -1)
      if [ -z "$NEWPEND" ]; then
        logit "$Y" build WARN "batch $i died: $(describe_rc "$RC")"
        NEWPEND=$pend
      fi
      if [ "$NEWPEND" = "$pend" ] && [ "$i" -gt 1 ]; then
        logit "$Y" build FAIL "no progress, pending=$NEWPEND $(describe_rc "$RC")"; exit 1
      fi
      pend=$NEWPEND
    done
    if [ "$pend" -ne 0 ]; then logit "$Y" build FAIL "pending=$pend after $i batches"; exit 1; fi
  fi

  # ---- move + verify ----
  done_stage "$Y" "move"   || { runstage "$Y" move   || { logit "$Y" move   FAIL "$(describe_rc "$(cat "$RCFILE")")"; exit 1; }; }
  done_stage "$Y" "verify" || { runstage "$Y" verify || { logit "$Y" verify FAIL "$(describe_rc "$(cat "$RCFILE")")"; exit 1; }; }
done

echo "===================== ALL YEARS DONE ====================="
grep -P "\tyear\tOK\t" "$LOG" | tail -20
