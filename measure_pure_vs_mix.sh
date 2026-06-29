#!/usr/bin/env bash
set -euo pipefail

SRC=pure_vs_mix.c
BIN=pure_vs_mix
N=100000000
REPEAT=${1:-3}

gcc -O2 \
  -fno-tree-vectorize \
  -fno-if-conversion \
  -fno-if-conversion2 \
  "$SRC" -o "$BIN"

target_branches=$((N * REPEAT * 2))

run_one() {
  local n=$1
  local mode=$2
  local label=$3
  local perf_file
  perf_file=$(mktemp)

  local out
  out=$(
    perf stat \
      -x, \
      -e cycles,instructions,branch-misses \
      -o "$perf_file" \
      ./"$BIN" "$n" "$REPEAT" "$mode" 2>&1
  )

  local cycles instructions misses
  cycles=$(awk -F, '$3 ~ /^cycles/ {print $1}' "$perf_file")
  instructions=$(awk -F, '$3 ~ /^instructions/ {print $1}' "$perf_file")
  misses=$(awk -F, '$3 ~ /^branch-misses/ {print $1}' "$perf_file")

  rm -f "$perf_file"

  local time_sec
  time_sec=$(awk -v lbl="$label" '$0 ~ ("^" lbl "[: ]") { sub(/.*time = /, ""); sub(/ sec$/, ""); print; exit }' <<< "$out")

  local if_miss ipc
  if_miss=$(awk -v m="$misses" -v b="$target_branches" \
    'BEGIN { printf "%.2f%%", 100.0 * m / b }')
  ipc=$(awk -v i="$instructions" -v c="$cycles" \
    'BEGIN { printf "%.2f", i / c }')

  printf "    [%-4s] time: %8s sec, misses: %10s, if-miss: %6s, IPC: %4s\n" \
    "$label" "$time_sec" "$misses" "$if_miss" "$ipc"
}

for n in $(seq 0 4 16); do
  echo "period: 2^$n"
  run_one "$n" pure "pure"
  run_one "$n" mix  "mix "
done
