#include "MT25081_Part_B_workers.h"
#include <unistd.h>

/**
 * 
 * These three worker functions represent different types of computational
 * workloads commonly found in real applications:
 * 
 * 1. cpu_worker()  - CPU-bound: Intensive mathematical calculations
 * 2. mem_worker()  - Memory-bound: Large data structure access patterns
 * 3. io_worker()   - I/O-bound: Disk read/write operations
 * 
 * CPU and Memory workers execute CPU_MEM_LOOP_COUNT times.
 * I/O worker executes IO_LOOP_COUNT times (reduced for practical benchmarking).
 *
 * The CPU_MEM_LOOP_COUNT is derived from roll no (25081),
 * where CPU_MEM_LOOP_COUNT = (last_digit) * 10^3 = 1 * 1000 = 1000 iterations.
 * ============================================================================
 */

/**
 * cpu_worker() - CPU-intensive workload
 * 
 * WHAT IT DOES:
 *   Performs mathematical approximation of PI using the Leibniz formula.
 *   This creates sustained CPU load without significant memory or I/O demands.
 
 */
void cpu_worker(void) {
    volatile double pi = 0.0;      // Volatile prevents compiler optimization
    volatile int i;                // Volatile loop counter
    
    // Outer loop: CPU_MEM_LOOP_COUNT times (1000 iterations from roll number 25081)
    // Each iteration completes the inner approximation loop
    for (int iter = 0; iter < CPU_MEM_LOOP_COUNT; iter++) {
        // Inner loop: 1 million iterations per outer loop iteration
        // Applies formula to approximate PI
        for (i = 0; i < 1000000; i++) {
            if (i % 2 == 0) {
                pi += 1.0 / (2.0 * i + 1.0);  // Add term for even indices
            } else {
                pi -= 1.0 / (2.0 * i + 1.0);  // Subtract term for odd indices
            }
        }
    }
    // Final approximation: pi ≈ 4 * (calculated value)
    // But we don't need to compute it - the loop work is what matters
}

/**
 * mem_worker() - Memory-intensive workload
 * 
 * WHAT IT DOES:
 *   Allocates large memory blocks and performs both sequential and random
 *   access patterns to stress memory bandwidth and cache subsystem.

 */
void mem_worker(void) {
    // Allocate 200MB of heap memory (increased from 100MB for better measurement)
    // Size calculation: 200 * 1024 * 1024 / 4 bytes per int ≈ 52.4 million integers
    size_t array_size = 200 * 1024 * 1024 / sizeof(int);
    int *array = (int *)malloc(array_size * sizeof(int));
    
    // Validate memory allocation
    if (array == NULL) {
        fprintf(stderr, "Memory allocation failed\n");
        return;
    }
    
    // Repeat CPU_MEM_LOOP_COUNT times (1000 iterations) to create sustained memory pressure
    for (int iter = 0; iter < CPU_MEM_LOOP_COUNT; iter++) {
        // PHASE 1: Sequential writes to all memory pages
        // Stride of 64 bytes = cache line size (forces memory access, not cache hits)
        // This ensures all allocated memory is physically resident
        for (size_t i = 0; i < array_size; i += 64) {  // 64-byte cache line stride
            array[i] = i + iter;  // Write different value each iteration
        }
        
        // PHASE 2: Random read pattern to stress cache misses
        // Stride of 256 bytes = 4 cache lines apart
        // This creates unpredictable access patterns that defeat prefetch
        for (size_t i = 0; i < array_size; i += 256) {  // 256-byte stride
            volatile int val = array[i];  // Read value (volatile prevents optimization)
            (void)val;                    // Mark as used to prevent compiler elimination
        }
    }
    
    // Free allocated memory
    free(array);
}

/**
 * io_worker() - I/O-intensive workload
 * 
 * WHAT IT DOES:
 *   Performs repeated disk write and read operations to stress the I/O subsystem.
 *   Each iteration writes 10MB of data to disk, then reads it back.
 *   Repeats LOOP_COUNT times (1000 iterations) = 10GB total I/O.
 
 */
void io_worker(void) {
    // Use /tmp for temporary file (usually fast: ramdisk, local disk, or SSD)
    const char *filename = "io_worker_temp_file.txt";
    char buffer[4096];              // Standard page size buffer for I/O
    size_t bytes_written;
    
    // Initialize buffer with test data
    memset(buffer, 'A', sizeof(buffer));  // Fill with 'A' characters
    
    // Main I/O loop: IO_LOOP_COUNT iterations (reduced for practical benchmarking)
    for (int iter = 0; iter < IO_LOOP_COUNT; iter++) {
        
        // ===== WRITE PHASE =====
        // Open file for writing (truncate if exists)
        FILE *fp = fopen(filename, "w");
        if (fp == NULL) {
            fprintf(stderr, "Failed to open file for writing\n");
            return;
        }
        
        // Write 10MB of data to file (2500 writes × 4KB = 10MB)
        for (int i = 0; i < 2500; i++) {
            bytes_written = fwrite(buffer, 1, sizeof(buffer), fp);
            if (bytes_written != sizeof(buffer)) {
                fprintf(stderr, "Write error\n");
                fclose(fp);
                return;
            }
        }
        // Close file to ensure data is flushed to disk
        fflush(fp);
        int fd = fileno(fp);
        fsync(fd);
        fclose(fp);
        
        // ===== READ PHASE =====
        // Open file for reading to stress I/O subsystem
        fp = fopen(filename, "r");
        if (fp == NULL) {
            fprintf(stderr, "Failed to open file for reading\n");
            return;
        }
        
        // Read entire file back into memory to stress I/O bandwidth
        while (fread(buffer, 1, sizeof(buffer), fp) > 0) {
            // Just read the data, don't process it
            volatile char c = buffer[0];  // Volatile prevents optimization
            (void)c;                      // Mark as used
        }
        // Close file after reading
        fclose(fp);
    }
    
    // Cleanup: Remove temporary file after all iterations complete
    remove(filename);
}

