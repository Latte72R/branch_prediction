#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <time.h>

#define N 100000000

uint8_t data[N];

double now_sec(void) {
  struct timespec ts;
  clock_gettime(CLOCK_MONOTONIC, &ts);
  return (double)ts.tv_sec + (double)ts.tv_nsec * 1e-9;
}

uint64_t branch_test(void) {
  uint64_t sum = 0;

  for (size_t i = 0; i < N; i++) {
    if (data[i]) {
      sum += 1;
    }
  }

  return sum;
}

void fill_predictable(int n) {
  static uint8_t p[1 << 20];
  
  size_t period = 1ull << n;
  uint32_t x = 12345u;

  if (n == 0) {
    for (size_t i = 0; i < N; i++) {
      data[i] = 0;
    }
    return;
  }

  for (size_t i = 0; i < period; i++) {
    p[i] = i < period / 2 ? 0 : 1;
  }

  for (size_t i = period - 1; i > 0; i--) {
    x ^= x << 13;
    x ^= x >> 17;
    x ^= x << 5;

    size_t j = x & (period - 1);

    uint8_t tmp = p[i];
    p[i] = p[j];
    p[j] = tmp;
  }

  for (size_t i = 0; i < N; i++) {
    data[i] = p[i & (period - 1)];
  }
}

int main(int argc, char **argv) {
  if (argc < 2 || argc > 3) {
    fprintf(stderr, "usage: %s n [repeat]\n", argv[0]);
    return 1;
  }

  int n = atoi(argv[1]);
  int repeat = argc >= 3 ? atoi(argv[2]) : 1;

  if (n < 0 || n > 20) {
    fprintf(stderr, "n must be 0..20\n");
    return 1;
  }

  if (repeat <= 0) {
    fprintf(stderr, "repeat must be positive\n");
    return 1;
  }

  fill_predictable(n);

  uint64_t total = 0;
  double start = now_sec();

  for (int r = 0; r < repeat; r++) {
    total += branch_test();
  }

  double end = now_sec();

  printf("period: 2^%d, repeat = %d, result = %llu, time = %.6f sec\n",
         n, repeat, (unsigned long long)total, end - start);

  return 0;
}
