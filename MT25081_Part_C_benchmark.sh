
set -e

# Get project directory (where this script is located)
PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Output CSV filename for storing benchmark results
OUTPUT_CSV="MT25081_Part_C_CSV.csv"

# Log directory for temporary files and debugging info
LOG_DIR="logs"

# Detect number of CPU cores available on this system
CPU_CORES=$(nproc)

# Color codes for terminal output formatting
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Create necessary directories
mkdir -p "$LOG_DIR"

# Checks for the presence of required command-line tools.
# Exits with an error message if any critical tool is missing.
check_commands() {
    echo -e "${YELLOW}Checking for required tools...${NC}"
    local required_commands=("iostat" "top" "taskset" "pgrep" "bc" "nproc")
    local missing_commands=()

    for cmd in "${required_commands[@]}"; do
        if ! command -v "$cmd" &> /dev/null; then
            missing_commands+=("$cmd")
        fi
    done

    if [[ ${#missing_commands[@]} -gt 0 ]]; then
        echo -e "${RED}ERROR: The following required tools are not installed or not in your PATH:${NC}"
        for cmd in "${missing_commands[@]}"; do
            echo -e "${RED}  - $cmd${NC}"
        done
        echo ""
        echo -e "${YELLOW}Please install these tools to continue. Common installation commands:${NC}"
        echo "  - Debian/Ubuntu: sudo apt-get install procps sysstat util-linux bsdmainutils"
        echo "  - CentOS/RHEL: sudo yum install procps-ng sysstat util-linux-ng"
        echo -e "${YELLOW}If you are on Windows using Git Bash, some tools (like taskset, iostat) might require WSL (Windows Subsystem for Linux) or a Linux environment.${NC}"
        exit 1
    fi
    echo -e "${GREEN}All required tools found.${NC}"
    echo ""
}



# Initializes the CSV file with the correct headers for the new data format.
init_csv() {
    echo "Program+Worker,CPU%,Memory(KB),IO,Time(s)" > "$OUTPUT_CSV"
}

# Runs a single benchmark test for a given program, worker, and scale.
run_benchmark() {
    local program=$1
    local worker=$2
    local count=$3
    local label=$4
    local program_path="$PROJECT_DIR/$program"

    # ====== PHASE 1: VALIDATION ======
    if [[ ! -f "$program_path" ]]; then
        echo -e "${RED}ERROR: $program_path not found${NC}"
        return 1
    fi

    echo -e "${YELLOW}Running: $label+$worker${NC}"

    # ====== PHASE 2: CPU PINNING SETUP ======
    # Pin to a single core '0' to create contention and match the reference benchmark.
    # This ensures a consistent environment for comparing process vs. thread efficiency.
    local cpu_list="0"

    # ====== PHASE 3: INITIALIZE MONITORING ======
    # Start background disk I/O monitoring with iostat, sampling every second.
    # The output is saved to a temporary file for later processing.
    iostat -dx 1 > "$LOG_DIR/io.tmp" &
    local io_pid=$!

    # ====== PHASE 4: EXECUTE PROGRAM ======
    # Use /usr/bin/time to capture wall-clock execution time (%e).
    # Use taskset to pin the program to the specified CPU core(s).
    # Stderr is redirected to a temp file to capture the time output.
    local time_file="$LOG_DIR/time.tmp"
    /usr/bin/time -f "%e" taskset -c "$cpu_list" "$program_path" "$worker" "$count" 2> "$time_file" &
    local program_pid=$!
    echo "DEBUG: Started $program_path ($worker) with PID: $program_pid"

    # Allow a moment for child processes or threads to spawn.
    sleep 0.4

    # Get the process group ID (pgid) of the main program.
    # This allows us to monitor all related processes/threads together.
    local pgid=$(ps -o pgid= "$program_pid" | tr -d ' ')
    echo "DEBUG: PGID for PID $program_pid is $pgid"
    
    # Initialize metric accumulators.
    local cpu_sum=0
    local mem_max=0
    local samples=0

    # Monitor the program's resource usage in a loop while it is running.
    while kill -0 "$program_pid" 2>/dev/null; do
        # Get all process IDs (PIDs) belonging to the program's process group.
        local pids=$(pgrep -g "$pgid" | paste -sd "," -)

        if [[ -n "$pids" ]]; then
            echo "DEBUG: Monitoring PIDs: $pids"
            local top_output=$(top -b -n 1 -p "$pids" -w 512)
            echo "DEBUG: Raw top output for PIDs $pids:"
            echo "$top_output" # Print raw top output for debugging
            # Use top in batch mode to get CPU (%CPU) and Resident Memory (RES in KB).
            # awk sums the values for all PIDs in the process group.
            read cpu mem <<< $(
                echo "$top_output" | awk '
                    NR>7 { cpu+=$9; mem+=$6 }
                    END   { print cpu+0, mem+0 }
                '
            )
            echo "DEBUG: Parsed CPU: $cpu, Parsed MEM: $mem"
            
            # Accumulate CPU usage for averaging later.
            cpu_sum=$(echo "$cpu_sum + $cpu" | bc)
            
            # Track the maximum resident memory usage encountered.
            if (( $(echo "$mem > $mem_max" | bc -l) )); then
                mem_max=$mem
            fi
            
            samples=$((samples+1))
        else
            echo "DEBUG: No PIDs found in PGID $pgid. Program still running?"
        fi
        sleep 1 # Sample every second.
    done
    echo "DEBUG: Program with PID $program_pid terminated."
    # ====== PHASE 5: COLLECT AND PROCESS METRICS ======

    # Stop the background I/O monitoring.
    kill $io_pid 2>/dev/null || true
    wait $io_pid 2>/dev/null || true

    # Calculate the average CPU usage across all samples.
    local avg_cpu=0.00
    if [[ $samples -gt 0 ]]; then
        avg_cpu=$(echo "scale=2; $cpu_sum / $samples" | bc)
    fi

    # Sum the total kilobytes written from the iostat log.
    # For this iostat version, column 6 is 'kB_wrtn/s'.
    local total_io=$(grep -v "^Linux" "$LOG_DIR/io.tmp" | awk '{sum+=$6} END {print sum+0}')

    # Read the execution time from the temp file.
    local exec_time=$(cat "$time_file")

    # ====== PHASE 6: PRINT AND SAVE RESULTS ======
    echo -e "${GREEN}Completed: $label+$worker${NC}"
    echo "  Avg CPU: ${avg_cpu}%"
    echo "  Max Memory: ${mem_max} KB"
    echo "  Total I/O Writes: ${total_io} KB"
    echo "  Execution Time: ${exec_time}s"
    echo ""

    # Append the results to the CSV file in the new, correct format.
    echo "$label+$worker,$avg_cpu,$mem_max,$total_io,$exec_time" >> "$OUTPUT_CSV"

    # ====== CLEANUP ======
    rm -f "$LOG_DIR/io.tmp" "$LOG_DIR/time.tmp"
}

main() {
    # First, check if all required external commands are available.
    check_commands
    
    echo -e "${GREEN}"
    echo "╔════════════════════════════════════════════════════════════════════╗"
    echo "║  PA01 PART C: BASELINE BENCHMARKING - PROCESSES VS THREADS         ║"
    echo "║  Roll Number: 25081                                                ║"
    echo "║  Scale: 2 workers (pinned to a single CPU core)                    ║"
    echo "║                                                                    ║"
    echo "║  Objective: Establish baseline metrics with a fixed scale (2)      ║"
    echo "║             to compare single-core process vs. thread performance. ║"
    echo "╚════════════════════════════════════════════════════════════════════╝"
    echo -e "${NC}"
    echo ""
    
    # Initialize CSV with the correct headers.
    echo -e "${YELLOW}Initializing CSV file: $OUTPUT_CSV${NC}"
    init_csv
    echo -e "${GREEN}CSV initialized with headers${NC}"
    echo ""
    
    # Verify both programs are compiled.
    if [[ ! -f "$PROJECT_DIR/progA" || ! -f "$PROJECT_DIR/progB" ]]; then
        echo -e "${RED}ERROR: progA or progB not found. Build with 'make'${NC}"
        exit 1
    fi
    
    # Display system info for context.
    echo -e "${YELLOW}System Information:${NC}"
    echo "  CPU Cores: $CPU_CORES"
    echo "  Start Time: $(date '+%Y-%m-%d %H:%M:%S')"
    echo ""
    
    # Define programs and workers to be tested.
    local programs=("progA" "progB")
    local workers=("cpu" "mem" "io")

    # Run all 6 benchmark combinations.
    echo -e "${YELLOW}Running 6 baseline benchmark combinations...${NC}"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    
    for prog in "${programs[@]}"; do
        for worker in "${workers[@]}"; do
            run_benchmark "$prog" "$worker" 2 "$prog" || echo "$prog $worker failed"
        done
    done
    
    # Print completion message.
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo -e "${GREEN}✓ All baseline benchmarks completed successfully!${NC}"
    echo ""
    echo "Results saved to: $OUTPUT_CSV"
    echo ""
    echo "CSV Contents:"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    cat "$OUTPUT_CSV"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""
    echo "Next Steps:"
    echo "  1. Run Part D scaling: bash MT25081_Part_D_scaling.sh"
    echo "  2. Update and run generate_plots.py to match the new CSV format"
    echo ""
}

main "$@"

main "$@"


