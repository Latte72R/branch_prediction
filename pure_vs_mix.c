#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <time.h>

#define N 100000000

uint8_t data1[N], data2[N];

double now_sec(void) {
  struct timespec ts;
  clock_gettime(CLOCK_MONOTONIC, &ts);
  return (double)ts.tv_sec + (double)ts.tv_nsec * 1e-9;
}

uint64_t branch_test2() {
  uint64_t sum = 0;

  for (size_t i = 0; i < N; i++) {
    if (data1[i]) {
      sum += 1;
    }
    if (data2[i]) {
      sum += 1;
    }
  }
  return sum;
}

uint64_t branch_test1() {
  uint64_t sum = 0;

  for (size_t i = 0; i < N; i++) {
    if (data1[i]) {
      sum += 1;
    }
    if (data1[i]) {
      sum += 1;
    }
  }
  return sum;
}

void fill_predictable(int n) {
  uint8_t p[1 << 20];
  uint32_t x = 3456u;

  for (size_t i = 0; i < (1u << n); i++) {
    x ^= x << 13;
    x ^= x >> 17;
    x ^= x << 5;
    p[i] = x & 1;
  }

  for (size_t i = 0; i < N; i++) {
    data1[i] = p[i & ((1u << n) - 1)];
  }
}

void fill_unpredictable(void) {
  uint32_t x = 1234u;

  for (size_t i = 0; i < N; i++) {
    x ^= x << 13;
    x ^= x >> 17;
    x ^= x << 5;
    data2[i] = x & 1;
  }
}

int main(int argc, char **argv) {
  if (argc < 2 || argc > 4) {
    fprintf(stderr, "usage: %s n [repeat] [pure|mix|both]\n", argv[0]);
    return 1;
  }

  int n = atoi(argv[1]);
  int repeat = argc >= 3 ? atoi(argv[2]) : 1;
  const char *mode = argc >= 4 ? argv[3] : "both";

  if (n < 0 || n > 20) {
    fprintf(stderr, "n must be 0..20\n");
    return 1;
  }

  if (repeat <= 0) {
    fprintf(stderr, "repeat must be positive\n");
    return 1;
  }

  if (strcmp(mode, "pure") != 0 && strcmp(mode, "mix") != 0 && strcmp(mode, "both") != 0) {
    fprintf(stderr, "mode must be pure, mix, or both\n");
    return 1;
  }

  double start, end;
  uint64_t result = 0;

  fill_predictable(n);
  fill_unpredictable();

  for (int r = 0; r < repeat; r++) {
    start = now_sec();
    if (strcmp(mode, "pure") == 0) {
      result += branch_test1();
    } else {
      result += branch_test2();
    }
    end = now_sec();
    printf("result = %10llu, time = %.6f sec\n",
           (unsigned long long)result, end - start);
  }

  return 0;
}
