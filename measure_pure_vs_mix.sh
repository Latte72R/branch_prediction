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

printf "%6s %8s %9s %14s %10s %6s\n" \
  "period" "mode" "time[s]" "misses" "p-miss" "IPC"

printf "%6s %8s %9s %14s %10s %6s\n" \
  "------" "--------" "---------" "--------------" "----------" "------"

for mode in pure mix; do
  for n in $(seq 0 4 16); do
    perf_file=$(mktemp)

    out=$(
      perf stat \
        -x, \
        -e cycles,instructions,branch-misses \
        -o "$perf_file" \
        ./"$BIN" "$n" "$REPEAT" "$mode" 2>&1
    )

    cycles=$(awk -F, '$3 ~ /^cycles/ {print $1}' "$perf_file")
    instructions=$(awk -F, '$3 ~ /^instructions/ {print $1}' "$perf_file")
    misses=$(awk -F, '$3 ~ /^branch-misses/ {print $1}' "$perf_file")

    rm -f "$perf_file"

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

    if [[ "$mode" == "pure" ]]; then
      mode_label="[pure]"
      p_miss=$(awk -v m="$misses" -v n="$N" -v r="$REPEAT" '
        BEGIN { printf "%.2f%%", 100.0 * m / (n * r * 2) }
      ')
    else
      mode_label="[ mix]"
      p_miss=$(awk -v m="$misses" -v n="$N" -v r="$REPEAT" '
        BEGIN {
          pm = m - n * r * 0.5;
          if (pm < 0) pm = 0;
          printf "%.2f%%", 100.0 * pm / (n * r);
        }
      ')
    fi

    ipc=$(awk -v i="$instructions" -v c="$cycles" \
      'BEGIN { printf "%.2f", i / c }')

    printf "%6s %8s %9s %14s %10s %6s\n" \
      "2^$n" "$mode_label" "$time_sec" "$misses" "$p_miss" "$ipc"
  done

  if [[ "$mode" == "pure" ]]; then
    echo
  fi
done
