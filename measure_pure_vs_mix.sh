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

run_perf() {
  local n=$1
  local mode=$2
  local perf_file
  perf_file=$(mktemp)

  out=$(
    perf stat \
      -x, \
      -e cycles,instructions,branch-misses \
      -o "$perf_file" \
      ./"$BIN" "$n" "$REPEAT" "$mode" 2>&1
  )

  time_sec=$(awk -F'time = ' '
    /time = / {
      split($2, a, " ");
      sum += a[1];
      count++;
    }
    END {
      if (count > 0) printf "%.6f", sum / count;
      else printf "nan";
    }
  ' <<< "$out")

  cycles=$(awk -F, '$3 ~ /^cycles/ {print $1}' "$perf_file")
  instructions=$(awk -F, '$3 ~ /^instructions/ {print $1}' "$perf_file")
  misses=$(awk -F, '$3 ~ /^branch-misses/ {print $1}' "$perf_file")

  rm -f "$perf_file"
}

run_perf 0 pure
pure_base=$misses

run_perf 0 mix
mix_base=$misses

printf "%6s %8s %9s %10s %10s %6s\n" \
  "period" "mode" "time[s]" "misses" "p-miss" "IPC"

printf "%6s %8s %9s %10s %10s %6s\n" \
  "------" "--------" "---------" "----------" "----------" "------"

for mode in pure mix; do
  for n in $(seq 0 4 16); do
    run_perf "$n" "$mode"

    if [[ "$mode" == "pure" ]]; then
      mode_label="[pure]"
      p_misses=$((misses - pure_base))
      denom=$((N * REPEAT * 2))
    else
      mode_label="[ mix]"
      p_misses=$((misses - mix_base))
      denom=$((N * REPEAT))
    fi

    if (( p_misses < 0 )); then
      p_misses=0
    fi

    p_miss=$(awk -v m="$p_misses" -v b="$denom" \
      'BEGIN { printf "%.2f%%", 100.0 * m / b }')

    ipc=$(awk -v i="$instructions" -v c="$cycles" \
      'BEGIN { printf "%.2f", i / c }')

    printf "%6s %8s %9s %10s %10s %6s\n" \
      "2^$n" "$mode_label" "$time_sec" "$misses" "$p_miss" "$ipc"
  done

  if [[ "$mode" == "pure" ]]; then
    echo
  fi
done
