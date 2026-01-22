#ifndef WORKERS_H
#define WORKERS_H

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <time.h>

#define CPU_MEM_LOOP_COUNT 1000  // Original loop count for CPU and Memory workers
#define IO_LOOP_COUNT 10         // Reduced loop count for I/O worker for practical benchmarking on WSL

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
