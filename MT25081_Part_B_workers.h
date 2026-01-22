#ifndef WORKERS_H
#define WORKERS_H

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <time.h>

#define LOOP_COUNT 1000  // Roll number 25081: last digit 1 × 10^3 = 1000

/**
 * CPU-intensive worker function
 * Performs complex mathematical calculations to stress the CPU
 */
void cpu_worker(void);

/**
 * Memory-intensive worker function
 * Allocates and processes large arrays to stress the memory subsystem
 */
void mem_worker(void);

/**
 * I/O-intensive worker function
 * Performs disk read/write operations to stress I/O subsystem
 */
void io_worker(void);

#endif /* WORKERS_H */
