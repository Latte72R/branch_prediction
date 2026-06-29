#!/usr/bin/env bash
set -euo pipefail

SRC=bp_single_branch.c
BIN=bp_single_branch
N=100000000
REPEAT=${1:-3}

gcc -O2 \
  -fno-tree-vectorize \
  -fno-if-conversion \
  -fno-if-conversion2 \
  "$SRC" -o "$BIN"

printf "%3s %7s %9s %14s %10s %6s\n" \
  "n" "period" "time[s]" "misses" "if-miss" "IPC"

printf "%3s %7s %9s %14s %10s %6s\n" \
  "---" "-------" "---------" "--------------" "----------" "------"

for n in $(seq 0 2 20); do
  perf_file=$(mktemp)

  out=$(
    perf stat \
      -x, \
      -e cycles,instructions,branch-misses \
      -o "$perf_file" \
      ./"$BIN" "$n" "$REPEAT"
  )

  time_sec=$(awk -F'time = ' '{print $2}' <<< "$out" | awk '{print $1}')

  cycles=$(awk -F, '$3 ~ /^cycles/ {print $1}' "$perf_file")
  instructions=$(awk -F, '$3 ~ /^instructions/ {print $1}' "$perf_file")
  misses=$(awk -F, '$3 ~ /^branch-misses/ {print $1}' "$perf_file")

  rm -f "$perf_file"

  target_branches=$((N * REPEAT))

  if_miss=$(awk -v m="$misses" -v b="$target_branches" \
    'BEGIN { printf "%.2f%%", 100.0 * m / b }')

  ipc=$(awk -v i="$instructions" -v c="$cycles" \
    'BEGIN { printf "%.2f", i / c }')

  printf "%3d %7s %9s %14s %10s %6s\n" \
    "$n" "2^$n" "$time_sec" "$misses" "$if_miss" "$ipc"
done
