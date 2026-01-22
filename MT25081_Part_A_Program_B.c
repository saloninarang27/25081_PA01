#include <stdio.h>
#include <stdlib.h>
#include <pthread.h>
#include <string.h>
#include <unistd.h>
#include "MT25081_Part_B_workers.h"

/**
 * PURPOSE:
 *   Demonstrates thread-based parallelism using POSIX threads (pthreads).
 *   Creates N lightweight threads that execute a specified workload
 *   (CPU-intensive, Memory-intensive, or I/O-intensive).
 * 
 * USAGE:
 *   ./progB <worker_type> <num_threads>
 *   
 *   Parameters:
 *   - worker_type: Type of workload ("cpu", "mem", or "io")
 *   - num_threads: Number of threads to create (1-100)
 * 
 * EXAMPLES:
 *   ./progB cpu 2    # Create 2 threads, each doing CPU work
 *   ./progB mem 4    # Create 4 threads, each doing memory work
 *   ./progB io 8     # Create 8 threads, each doing I/O work
 * 
 * KEY FEATURES:
 *   - All threads share the same memory space (lighter weight than processes)
 *   - Uses pthread_create() to create threads
 *   - Uses pthread_join() to synchronize threads
 *   - Lower creation/context switching overhead compared to processes
 *   - Better for workloads with shared data access
 * 
 * PERFORMANCE NOTES:
 *   - Threads have lower overhead due to shared memory space
 *   - Suitable for scaling to higher concurrency levels (8+ workers)
 *   - Context switching is faster than with processes
 *   - All threads can efficiently access shared data
 * 
 */

/**
 * Thread argument structure
 * Used to pass parameters to worker threads
 */
typedef struct {
    int thread_id;           // Thread identifier (1..N)
    char *worker_type;       // Type of worker: "cpu", "mem", or "io"
} thread_args_t;

/**
 * thread_function() - Worker function executed by each thread
 * 
 * WHAT IT DOES:
 *   1. Receives thread arguments (ID and worker type)
 *   2. Prints thread start message with thread ID
 *   3. Executes the appropriate worker function based on type
 *   4. Prints thread completion message
 *   5. Cleans up and exits
 * 
 * 
 * WORKER TYPES:
 *   - "cpu": cpu_worker() - CPU-bound calculations
 *   - "mem": mem_worker() - Memory-intensive array operations
 *   - "io": io_worker() - I/O-intensive file operations
 * ============================================================================
 */
void *thread_function(void *arg) {
    // Extract thread arguments from void pointer
    thread_args_t *args = (thread_args_t *)arg;
    int thread_id = args->thread_id;
    char *worker_type = args->worker_type;
    
    // Print thread startup message with unique thread ID
    printf("[progB] Thread %d (TID: %lu) started\n", thread_id, pthread_self());
    fflush(stdout);
    
    // Execute the appropriate worker function based on worker_type parameter
    // All threads share memory, so this can be CPU/memory/I/O bound
    if (strcmp(worker_type, "cpu") == 0) {
        cpu_worker();      // CPU-intensive: Mathematical calculations
    } else if (strcmp(worker_type, "mem") == 0) {
        mem_worker();      // Memory-intensive: Large array allocation and access
    } else if (strcmp(worker_type, "io") == 0) {
        io_worker();       // I/O-intensive: Repeated file operations
    }
    
    // Print thread completion message
    printf("[progB] Thread %d (TID: %lu) completed\n", thread_id, pthread_self());
    fflush(stdout);
    
    // Clean up allocated arguments
    free(args);
    
    // Thread exits (allows main to pthread_join() on this thread)
    pthread_exit(NULL);
}

/**
 * main() - Entry point for thread-based benchmark program
 * 
 * WHAT IT DOES:
 *   1. Parses and validates command-line arguments
 *   2. Creates N threads using pthread_create()
 *   3. Each thread executes the specified worker function
 *   4. Main thread waits for all threads using pthread_join()
 *   5. Prints final status
 
 * 
 * THREAD CREATION STRATEGY:
 *   - Parent thread creates N worker threads
 *   - Each thread receives its own thread_args_t structure
 *   - All threads share the same process memory and resources
 * 
 */
int main(int argc, char *argv[]) {
    // Input validation: Check for correct number of arguments
    if (argc != 3) {
        fprintf(stderr, "Usage: %s <worker_type> <num_threads>\n", argv[0]);
        fprintf(stderr, "worker_type: cpu, mem, or io\n");
        fprintf(stderr, "num_threads: number of threads to create\n");
        exit(EXIT_FAILURE);
    }
    
    // Parse command-line arguments
    char *worker_type = argv[1];
    int num_threads = atoi(argv[2]);
    
    // Validate thread count (reasonable bounds to prevent resource exhaustion)
    if (num_threads < 1 || num_threads > 100) {
        fprintf(stderr, "Error: num_threads must be between 1 and 100\n");
        exit(EXIT_FAILURE);
    }
    
    // Validate worker type (must be one of the three supported types)
    if (strcmp(worker_type, "cpu") != 0 && 
        strcmp(worker_type, "mem") != 0 && 
        strcmp(worker_type, "io") != 0) {
        fprintf(stderr, "Error: worker_type must be 'cpu', 'mem', or 'io'\n");
        exit(EXIT_FAILURE);
    }
    
    printf("[progB] Starting %d threads with worker type: %s\n", num_threads, worker_type);
    fflush(stdout);
    
    // Array to store thread handles for later synchronization
    pthread_t threads[num_threads];
    int thread_status[num_threads];
    
    // THREAD CREATION PHASE
    // Create N worker threads in a loop, each with its own arguments
    for (int i = 0; i < num_threads; i++) {
        // Allocate memory for thread arguments (each thread gets its own copy)
        thread_args_t *args = (thread_args_t *)malloc(sizeof(thread_args_t));
        if (args == NULL) {
            fprintf(stderr, "Memory allocation failed for thread args\n");
            exit(EXIT_FAILURE);
        }
        
        // Initialize thread arguments
        args->thread_id = i + 1;                    // Thread number (1..N)
        args->worker_type = worker_type;            // Copy of worker type
        
        // Create a new thread that will execute thread_function()
        // All threads share the same process memory space
        thread_status[i] = pthread_create(&threads[i], NULL, thread_function, (void *)args);
        
        if (thread_status[i] != 0) {
            fprintf(stderr, "Failed to create thread %d\n", i + 1);
            exit(EXIT_FAILURE);
        }
    }
    
    // SYNCHRONIZATION PHASE
    // Main thread waits for all worker threads to complete
    printf("[progB] Main thread waiting for %d threads to finish...\n", num_threads);
    fflush(stdout);
    
    // Join all threads (blocking wait for each thread to finish)
    int completed = 0;
    for (int i = 0; i < num_threads; i++) {
        // pthread_join() blocks until the thread terminates
        thread_status[i] = pthread_join(threads[i], NULL);
        
        if (thread_status[i] != 0) {
            fprintf(stderr, "Failed to join thread %d\n", i + 1);
        } else {
            completed++;
            printf("[progB] Thread %d joined successfully\n", i + 1);
        }
    }
    
    // All threads have completed - program is done
    printf("[progB] All %d threads completed. Main thread exiting.\n", completed);
    fflush(stdout);
    
    return EXIT_SUCCESS;
}


