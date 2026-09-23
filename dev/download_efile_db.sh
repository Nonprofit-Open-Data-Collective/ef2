#!/usr/bin/env bash
# Download one published EFILE<year>.duckdb with parallel range requests.
#
# A single stream managed ~5 MB/s against this bucket; 12 concurrent ranges
# reached 25-100 MB/s, which is the difference between a 4.7-hour and a
# ~35-minute transfer for the full TY2009-2024 panel (~280 GB).
#
# Skips the download when the local file already matches Content-Length, so it
# is safe to re-run after an interruption.
#
# Usage: download_efile_db.sh <year> <destdir> [nchunks]
#   writes <destdir>/<year>/EFILE<year>.duckdb
set -uo pipefail

YEAR="${1:?year required}"; DEST="${2:?destdir required}"; N="${3:-12}"
VERSION="${EFILE_VERSION:-efile_v2_2}"
BASE="${EFILE_S3_BASE:-https://nccs-efile.s3.us-east-1.amazonaws.com/duckdb}"

URL="$BASE/$VERSION/EFILE${YEAR}.duckdb"
OUT="$DEST/$YEAR/EFILE${YEAR}.duckdb"
mkdir -p "$DEST/$YEAR"

SIZE=$(curl -sI --max-time 120 "$URL" | tr -d '\r' | awk 'tolower($1)=="content-length:"{print $2}')
if [ -z "$SIZE" ]; then echo "FAIL $YEAR: no Content-Length from $URL"; exit 1; fi

if [ -f "$OUT" ] && [ "$(stat -c %s "$OUT")" = "$SIZE" ]; then
  echo "SKIP $YEAR already complete ($SIZE bytes)"; exit 0
fi

TMP="$DEST/$YEAR/.parts"
rm -rf "$TMP"; mkdir -p "$TMP"
CHUNK=$(( (SIZE + N - 1) / N ))

echo "DOWNLOAD $YEAR size=$SIZE chunks=$N"
pids=()
for i in $(seq 0 $((N-1))); do
  START=$(( i * CHUNK ))
  END=$(( START + CHUNK - 1 ))
  [ "$END" -ge "$SIZE" ] && END=$(( SIZE - 1 ))
  curl -s --fail --max-time 14400 --retry 5 --retry-delay 5 \
       -r "${START}-${END}" -o "$TMP/part.$(printf '%03d' $i)" "$URL" &
  pids+=($!)
done

rc=0
for p in "${pids[@]}"; do wait "$p" || rc=1; done
if [ "$rc" -ne 0 ]; then echo "FAIL $YEAR: one or more chunks failed"; exit 1; fi

cat "$TMP"/part.* > "$OUT"
rm -rf "$TMP"

GOT=$(stat -c %s "$OUT")
if [ "$GOT" != "$SIZE" ]; then
  echo "FAIL $YEAR: size mismatch, got $GOT expected $SIZE"; exit 1
fi
echo "OK $YEAR downloaded $GOT bytes"
