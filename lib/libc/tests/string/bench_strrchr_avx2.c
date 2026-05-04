#include <stdio.h>
#include <string.h>
#include <time.h>
#include <stdlib.h>

#define N     10000000
#define SIZE  4096

static char buf[SIZE];

static inline double
now(void)
{
    struct timespec ts;
    clock_gettime(CLOCK_MONOTONIC, &ts);
    return ts.tv_sec + ts.tv_nsec * 1e-9;
}

int
main(void)
{
    /* initialize buffer with pseudo-random data */
    for (int i = 0; i < SIZE - 1; i++)
        buf[i] = 'a' + (rand() % 23);

    buf[SIZE - 1] = '\0';

    volatile char *p;
    volatile int sink = 0;

    double t1, t2;

    /* -------- test 1: char exists near end -------- */
    buf[SIZE - 2] = 'Z';

    t1 = now();
    for (int i = 0; i < N; i++) {
        p = strrchr(buf, 'Z');
        sink += (p != NULL);
    }
    t2 = now();

    printf("case1 (hit near end):   %f sec\n", t2 - t1);

    /* -------- test 2: char does NOT exist -------- */
    t1 = now();
    for (int i = 0; i < N; i++) {
        p = strrchr(buf, '!');
        sink += (p != NULL);
    }
    t2 = now();

    printf("case2 (no match):       %f sec\n", t2 - t1);

    /* -------- test 3: char near beginning -------- */
    buf[5] = 'X';

    t1 = now();
    for (int i = 0; i < N; i++) {
        p = strrchr(buf, 'X');
        sink += (p != NULL);
    }
    t2 = now();

    printf("case3 (hit early):      %f sec\n", t2 - t1);

    /* -------- test 4: random char each iter -------- */
    t1 = now();
    for (int i = 0; i < N; i++) {
        char c = 'a' + (i % 23);
        p = strrchr(buf, c);
        sink += (p != NULL);
    }
    t2 = now();

    printf("case4 (mixed):          %f sec\n", t2 - t1);

    /* prevent optimization */
    if (sink == 123456)
        printf("ignore: %d\n", sink);

    return 0;
}
