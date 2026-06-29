#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <time.h>

#define N 100000000

static uint8_t data[N];

static double now_sec(void) {
  struct timespec ts;
  clock_gettime(CLOCK_MONOTONIC, &ts);
  return (double)ts.tv_sec + (double)ts.tv_nsec * 1e-9;
}

__attribute__((noinline)) uint64_t branch_test(void) {
  uint64_t sum = 0;

  for (size_t i = 0; i < N; i++) {
    if (data[i]) {
      sum += 1;
    } else {
      sum += 2;
    }
  }

  return sum;
}

static void fill_predictable(void) {
  for (size_t i = 0; i < N; i++) {
    data[i] = 1;
  }
}

static void fill_unpredictable(void) {
  uint32_t x = 2463534242u;

  for (size_t i = 0; i < N; i++) {
    x ^= x << 13;
    x ^= x >> 17;
    x ^= x << 5;
    data[i] = x & 1;
  }
}

int main(void) {
  double start, end;
  uint64_t result;

  fill_predictable();

  start = now_sec();
  result = branch_test();
  end = now_sec();

  printf("predictable:   result = %llu, time = %.6f sec\n",
         (unsigned long long)result, end - start);

  fill_unpredictable();

  start = now_sec();
  result = branch_test();
  end = now_sec();

  printf("unpredictable: result = %llu, time = %.6f sec\n",
         (unsigned long long)result, end - start);

  return 0;
}
