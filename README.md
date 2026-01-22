# PA01: Processes and Threads Benchmarking Project

**Roll Number:** 25081  
**Course:** CSE638 - Graduate Systems  
**Deadline:** January 23, 2026

## Project Overview

This project implements a comprehensive benchmark suite to analyze and compare the performance characteristics of process-based and thread-based concurrency models in Linux. The implementation includes:

1. **Part A:** Two C programs (`progA.c` and `progB.c`) demonstrating process and thread creation
2. **Part B:** Three worker functions (CPU, Memory, I/O-intensive) for system stress testing
3. **Part C:** Automated benchmarking with system metrics collection
4. **Part D:** Scaling analysis with performance visualization

## Directory Structure

```
25081_PA01/
├── MT25081_Part_A_Program_A.c    # Program A: Multi-process implementation
├── MT25081_Part_A_Program_B.c    # Program B: Multi-threaded implementation
├── MT25081_Part_B_workers.c      # Worker function implementations
├── MT25081_Part_B_workers.h      # Worker function declarations
├── Makefile                      # Build configuration
├── MT25081_Part_C_benchmark.sh   # Part C: Benchmarking automation script
├── MT25081_Part_D_scaling.sh     # Part D: Scaling analysis script
├── generate_plots.py             # Python script for plot generation
├── README.md                     # This file
├── MT25081_Part_C_CSV.csv        # Part C benchmark results
├── MT25081_Part_D_CSV.csv        # Part D scaling results
├── MT25081_Report.pdf            # Analysis and findings report
└── MT25081_AI_DECLARATION.txt    # AI usage declaration
```

## Building the Project

### Prerequisites
- GCC compiler with C99 support
- GNU Make
- Linux operating system with `top`, `iostat`, and `taskset` utilities
- Python 3 with pandas and matplotlib (for plot generation)

### Compilation

```bash
# Build all programs
make

# Build only progA (process-based)
make progA

# Build only progB (thread-based)
make progB

# Clean build artifacts
make clean

# Rebuild from scratch
make rebuild
```

This generates two executable binaries:
- `progA`: Process-based benchmark
- `progB`: Thread-based benchmark

## Usage

### Part A: Basic Execution

#### Program A (Processes)
```bash
./progA <worker_type> <num_processes>
```

Examples:
```bash
./progA cpu 2      # Create 2 processes, run CPU-intensive worker
./progA mem 3      # Create 3 processes, run memory-intensive worker
./progA io 2       # Create 2 processes, run I/O-intensive worker
```

#### Program B (Threads)
```bash
./progB <worker_type> <num_threads>
```

Examples:
```bash
./progB cpu 4      # Create 4 threads, run CPU-intensive worker
./progB mem 4      # Create 4 threads, run memory-intensive worker
./progB io 2       # Create 2 threads, run I/O-intensive worker
```

### Part C: Automated Benchmarking

Run all six combinations of programs and workers with metrics collection:

```bash
chmod +x MT25081_Part_C_benchmark.sh
./MT25081_Part_C_benchmark.sh
```

This script:
- Executes all combinations: A+cpu, A+mem, A+io, B+cpu, B+mem, B+io
- Uses `taskset` to pin processes/threads to specific CPU cores
- Monitors CPU and memory usage with `top`
- Collects disk I/O statistics with `iostat`
- Measures execution time
- Outputs results to `MT25081_Part_C_CSV.csv`

### Part D: Scaling Analysis

Run scaling experiments with varying process and thread counts:

```bash
chmod +x MT25081_Part_D_scaling.sh
./MT25081_Part_D_scaling.sh
```

This script:
- Tests Program A with 2, 3, 4, 5, 6, 7, 8 processes
- Tests Program B with 2, 3, 4, 5, 6, 7, 8 threads
- Collects metrics for each configuration
- Generates 4 performance analysis plots:
  - `MT25081_cpu_vs_components.png` - CPU utilization scaling (CPU worker)
  - `MT25081_mem_vs_components.png` - Memory utilization scaling (Memory worker)
  - `MT25081_io_vs_components.png` - I/O worker CPU utilization scaling
  - `MT25081_time_vs_components.png` - Execution time comparison (3 subplots)

## Implementation Details

### Worker Functions

#### CPU Worker (`cpu_worker`)
- Implements formula for PI approximation
- Performs 1,000 iterations of mathematical calculations
- Each iteration executes 1,000,000 arithmetic operations
- Total: ~1 billion floating-point operations
- Purpose: Maximum CPU utilization with minimal memory/I/O

#### Memory Worker (`mem_worker`)
- Allocates 200MB arrays per process/thread
- Performs sequential writes (64-byte stride) and random reads (256-byte stride)
- Uses cache-aware access patterns to induce cache misses
- 1,000 iterations with varying array access patterns
- Purpose: Stress the memory and cache subsystems

#### I/O Worker (`io_worker`)
- Performs file write/read operations
- Writes 10MB of data per iteration
- Reads data back for verification
- 1,000 iterations total
- Purpose: Saturate disk I/O subsystem

### Program A (Processes)
- Uses `fork()` to create child processes
- Parent waits for all children to complete
- Each process independently runs the selected worker
- IPC handled through file system (I/O worker) and process exit codes
- Process isolation provides strong fault tolerance

### Program B (Threads)
- Uses `pthread_create()` to spawn threads
- Main thread waits for all worker threads with `pthread_join()`
- Shared memory space between threads
- Synchronization through join operations
- Lower context switching overhead than processes

## Performance Metrics

The benchmark collects the following metrics:

| Metric             | Description                | Tool |
|--------------------|----------------------------|------|
| CPU %              | Average CPU utilization    | `top` |
| Memory %           | Average memory consumption | `top` |
| Disk Read (KB)     | Total disk read volume     | `iostat` |
| Disk Write (KB)    | Total disk write volume    | `iostat` |
| Execution Time (s) | Program runtime            | `time` |

## Expected Behavior

### CPU Worker Results
- **progA (Processes):** Linear CPU scaling up to core count
- **progB (Threads):** Near-linear CPU scaling with lower overhead

### Memory Worker Results
- **progA:** Memory grows linearly with process count
- **progB:** Memory shared between threads; slower growth

### I/O Worker Results
- **progA:** I/O can be parallelized well with separate processes
- **progB:** I/O may contend on shared file system

## Output Files

### CSV Files
- `MT25081_Part_C_CSV.csv`: Baseline benchmarks with 2 processes/threads
- `MT25081_Part_D_CSV.csv`: Scaling data with varying counts (2-8)

CSV Format:
```
Program,Worker_Type,Scale,AvgCPU_Percent,AvgMemory_Percent,ExecutionTime_Sec
progA,cpu,2,95.50,12.30,45.23
...
```

### Plot Files (PNG)
- Thread scaling: CPU utilization and execution time
- Process scaling: Memory utilization and execution time
- Direct comparison plots between processes and threads

## System Requirements

- **CPU Cores:** Tested on systems with 2-8+ cores
- **RAM:** Minimum 2GB (memory worker allocates 200MB per process/thread)
- **Disk Space:** ~500MB for I/O worker operations (/tmp)
- **Linux Kernel:** 2.6+

## Troubleshooting

### "taskset: command not found"
The script will automatically fall back to running without CPU pinning. To install:
```bash
sudo apt install util-linux  # Debian/Ubuntu
sudo yum install util-linux  # RedHat/CentOS
```

### Memory allocation failures
The memory worker allocates 200MB per process/thread. If allocation fails, modify `workers.c`:
```c
size_t array_size = 100 * 1024 * 1024 / sizeof(int);  // 100MB instead of 200MB
```

### I/O performance issues
The I/O worker uses `/tmp`. On systems with limited `/tmp` space, modify `workers.c`:
```c
const char *filename = "/var/tmp/io_worker_temp_file.txt";  // Use alternate location
```

### Plot generation fails
Install required Python packages:
```bash
pip install pandas matplotlib
python3 generate_plots.py
```

## References

1. **POSIX Processes:** `fork()`, `waitpid()`, `exit()` [man pages]
2. **POSIX Threads:** `pthread_create()`, `pthread_join()` [man pages]
3. **System Monitoring:** `top`, `iostat`, `taskset` [man pages]
4. **Performance Analysis:** Modern CPUs, memory hierarchies, I/O scheduling

## Notes 

Key points to understand:

### Q1: Why processes have higher memory overhead than threads?
**Answer:** Each process gets its own independent memory space (address space, stack, heap) with a separate page table. The kernel must allocate and maintain these structures for every process. Threads, in contrast, share the same memory space and only have separate stacks. At 8 processes with 200MB each = 1.6GB total, while 8 threads with shared 200MB ≈ 0.77% RAM. Data shows progA uses 3.08% vs progB uses 0.77% at scale 8 - approximately 4x more efficient with threads.

### Q2: How context switching affects CPU-bound workloads?
**Answer:** Context switching is expensive because the OS must save/restore CPU registers, update memory management structures, and flush CPU caches. For CPU-bound workloads, more processes mean more context switches. progA caps at 76% CPU (process overhead limits utilization) while progB reaches 408% (threads have minimal overhead). Threads are 5-6x more efficient because they have lower context switching costs and share memory directly without address space switching overhead.

### Q3: I/O parallelization potential with multiple processes vs threads?
**Answer:** Threads parallelize I/O better because they share file descriptors and can schedule I/O operations concurrently. With processes, each process has independent I/O and must wait for its operations to complete sequentially. Our I/O worker shows: progA takes ~45 seconds with 2 processes vs progB takes ~32 seconds with 2 threads (1.4x faster). This advantage grows with more workers because threads can submit multiple I/O requests simultaneously while processes serialize them.

### Q4: Cache effects on memory-intensive workloads?
**Answer:** The memory worker alternates sequential writes (64-byte stride - cache-friendly) with random reads (256-byte stride - cache-hostile) to induce cache misses. With threads sharing memory, cache lines are shared efficiently; with processes, each has isolated caches and memory, causing more cache invalidations. Memory scaling shows: progA grows linearly (each process gets 200MB), progB plateaus (all share one 200MB). Shared memory allows better cache locality.

### Q5: Trade-offs between process isolation and thread efficiency?
**Answer:**

**Process Advantages:**
- Strong isolation: If one process crashes, others unaffected
- Security: Separate address spaces prevent one process affecting another's memory
- Suitable for independent, long-running tasks

**Process Disadvantages:**
- High memory overhead (4x more at scale 8)
- Slow context switching
- Inter-process communication is complex
- Limited I/O parallelism

**Thread Advantages:**
- Low memory overhead (shared allocation)
- Fast context switching (same memory space)
- Efficient I/O parallelism (1.4x faster in benchmarks)
- High CPU utilization (5-6x better for CPU-bound)
- Easy communication (shared memory)

**Thread Disadvantages:**
- Less isolation: One thread crash can affect all
- Security concerns with shared memory
- Race conditions possible without proper synchronization
- Debugging is more complex

**Recommendation:** Use threads for CPU-bound and I/O-bound workloads on multi-core systems. Use processes for independent, long-running services or when fault isolation is critical.

