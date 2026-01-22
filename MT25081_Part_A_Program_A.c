#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>
#include <sys/wait.h>
#include <string.h>
#include "MT25081_Part_B_workers.h"

/**
 * PURPOSE:
 *   Demonstrates process-based parallelism using fork() system call.
 *   Creates N independent child processes that execute a specified workload
 *   (CPU-intensive, Memory-intensive, or I/O-intensive).
 * 
 * USAGE:
 *   ./progA <worker_type> <num_processes>
 *   
 *   Parameters:
 *   - worker_type: Type of workload ("cpu", "mem", or "io")
 *   - num_processes: Number of child processes to create (1-100)
 * 
 * 
 * KEY FEATURES:
 *   - Each process is independent with separate memory space
 *   - Uses fork() to create child processes
 *   - Uses waitpid() to synchronize and collect all children
 *   - Measures overall execution time for scaling analysis
 * 
 * PERFORMANCE NOTES:
 *   - Processes have larger overhead due to memory isolation
 *   - Context switching cost increases with process count
 *   - Suitable for CPU-bound and I/O-bound workloads
 * ============================================================================
 */

/**
 * main() - Entry point for process-based benchmark program
 * 
 * WHAT IT DOES:
 *   1. Parses and validates command-line arguments
 *   2. Creates N child processes using fork()
 *   3. Each child executes the specified worker function
 *   4. Parent process waits for all children to complete
 *   5. Prints timing and status information
 * 
 * 
 * PROCESS FLOW:
 *   - Validate: Check arguments, worker type, and process count
 *   - Fork: Create N child processes in a loop
 *   - Execute: Each child runs the appropriate worker function
 *   - Synchronize: Parent waits for all children using waitpid()
 * 
 */
int main(int argc, char *argv[]) {
    // Input validation: Check for correct number of arguments
    if (argc != 3) {
        fprintf(stderr, "Usage: %s <worker_type> <num_processes>\n", argv[0]);
        fprintf(stderr, "worker_type: cpu, mem, or io\n");
        fprintf(stderr, "num_processes: number of processes to create\n");
        exit(EXIT_FAILURE);
    }
    
    // Parse command-line arguments
    char *worker_type = argv[1];
    int num_processes = atoi(argv[2]);
    
    // Validate process count (reasonable bounds to prevent system overload)
    if (num_processes < 1 || num_processes > 100) {
        fprintf(stderr, "Error: num_processes must be between 1 and 100\n");
        exit(EXIT_FAILURE);
    }
    
    // Validate worker type (must be one of the three supported types)
    if (strcmp(worker_type, "cpu") != 0 && 
        strcmp(worker_type, "mem") != 0 && 
        strcmp(worker_type, "io") != 0) {
        fprintf(stderr, "Error: worker_type must be 'cpu', 'mem', or 'io'\n");
        exit(EXIT_FAILURE);
    }
    
    printf("[progA] Starting %d processes with worker type: %s\n", num_processes, worker_type);
    fflush(stdout);
    
    // Array to store child process IDs for later synchronization
    pid_t pids[num_processes];
    
    // FORK PHASE: Create N child processes
    // Each child will execute one of the worker functions independently
    for (int i = 0; i < num_processes; i++) {
        pid_t pid = fork();
        
        if (pid < 0) {
            // Fork failed - critical error, cannot continue
            perror("fork");
            exit(EXIT_FAILURE);
        } else if (pid == 0) {
            // CHILD PROCESS EXECUTION
            // This code runs in the context of a new child process
            printf("[progA] Child process %d (PID: %d) started\n", i + 1, getpid());
            fflush(stdout);
            
            // Execute the appropriate worker function based on worker_type
            // Each worker performs different type of workload for LOOP_COUNT iterations
            if (strcmp(worker_type, "cpu") == 0) {
                cpu_worker();  // CPU-intensive: Mathematical calculations
            } else if (strcmp(worker_type, "mem") == 0) {
                mem_worker();  // Memory-intensive: Large array allocation and access
            } else if (strcmp(worker_type, "io") == 0) {
                io_worker();   // I/O-intensive: Repeated file operations
            }
            
            printf("[progA] Child process %d (PID: %d) completed\n", i + 1, getpid());
            fflush(stdout);
            exit(EXIT_SUCCESS);  // Child process terminates here
        } else {
            // PARENT PROCESS EXECUTION
            // Store the child's PID for later synchronization
            pids[i] = pid;
        }
    }
    
    // SYNCHRONIZATION PHASE: Parent waits for all children to complete
    printf("[progA] Parent waiting for %d children to finish...\n", num_processes);
    fflush(stdout);
    
    
    // SYNCHRONIZATION: Wait for all children to finish
    // waitpid() blocks until the specified child process terminates
    int completed = 0;
    for (int i = 0; i < num_processes; i++) {
        int status;
        pid_t wpid = waitpid(pids[i], &status, 0);
        
        if (wpid < 0) {
            perror("waitpid");
        } else {
            completed++;
            if (WIFEXITED(status)) {
                // Child exited normally - check exit status
                printf("[progA] Child %d exited with status: %d\n", i + 1, WEXITSTATUS(status));
            } else {
                // Child terminated abnormally (signal, etc.)
                printf("[progA] Child %d terminated abnormally\n", i + 1);
            }
        }
    }
    
    // All children have completed - program is done
    printf("[progA] All %d children completed. Parent exiting.\n", completed);
    fflush(stdout);
    
    return EXIT_SUCCESS;
}
