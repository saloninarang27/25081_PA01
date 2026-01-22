set -e
# Get project directory (where this script is located)
PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Output CSV filename for storing all scaling benchmark results
OUTPUT_CSV="MT25081_Part_D_CSV.csv"

# Log directory for temporary metric files
LOG_DIR="logs"

# Detect number of CPU cores (for reference only)
CPU_CORES=$(nproc)

# Color codes for terminal output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

# Create log directory if it doesn't exist
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


# Initializes the CSV file with headers matching the new data collection format.
init_csv() {
    # This header includes absolute memory in KB and I/O in KB.
    echo "Program,Worker_Type,Scale,AvgCPU_Percent,AvgMemory_KB,TotalIO_KB,ExecutionTime_Sec" > "$OUTPUT_CSV"
}

# Runs a single scaling benchmark test.
run_scaling_benchmark() {
    local program=$1
    local worker=$2
    local scale=$3
    local program_path="$PROJECT_DIR/$program"
    
    # ====== PHASE 1: VALIDATION ======
    if [[ ! -f "$program_path" ]]; then
        echo -e "${RED}ERROR: $program_path not found${NC}"
        return 1
    fi
    
    echo -e "${CYAN}  Running: $program $worker scale=$scale${NC}"
    
    # ====== PHASE 2: CPU PINNING ======
    # Pin to a SINGLE CORE ('0') to analyze contention and scaling on a fixed resource.
    # This is critical for comparing thread vs. process efficiency under constraint.
    local cpu_list="0"

    # ====== PHASE 3: MONITORING & EXECUTION ======
    # Start background I/O monitoring with iostat.
    iostat -dx 1 > "$LOG_DIR/io_${program}_${worker}_${scale}.tmp" &
    local io_pid=$!

    # Use /usr/bin/time to measure wall-clock time and taskset to pin the process.
    local time_file="$LOG_DIR/time_${program}_${worker}_${scale}.tmp"
    /usr/bin/time -f "%e" taskset -c "$cpu_list" "$program_path" "$worker" "$scale" 2> "$time_file" &
    local program_pid=$!
    echo "DEBUG: Started $program_path ($worker) with PID: $program_pid"
    
    # Wait for child processes/threads to spawn.
    sleep 0.4
    # Get the process group ID to monitor all related processes.
    local pgid=$(ps -o pgid= "$program_pid" | tr -d ' ')
    echo "DEBUG: PGID for PID $program_pid is $pgid"
    
    # Initialize metric accumulators.
    local cpu_sum=0
    local mem_max=0
    local samples=0

    # Loop to sample metrics while the program is running.
    while kill -0 "$program_pid" 2>/dev/null; do
        # Find all PIDs in the process group.
        local pids=$(pgrep -g "$pgid" | paste -sd "," -)
        if [[ -n "$pids" ]]; then
            echo "DEBUG: Monitoring PIDs: $pids"
            local top_output=$(top -b -n 1 -p "$pids" -w 512)
            echo "DEBUG: Raw top output for PIDs $pids:"
            echo "$top_output" # Print raw top output for debugging
            # Use top to get CPU % and Resident Memory (KB) for all PIDs.
            read cpu mem <<< $(
                echo "$top_output" | awk '
                    NR>7 { cpu+=$9; mem+=$6 }
                    END   { print cpu+0, mem+0 }'
            )
            echo "DEBUG: Parsed CPU: $cpu, Parsed MEM: $mem"
            # Accumulate CPU for averaging.
            cpu_sum=$(echo "$cpu_sum + $cpu" | bc)
            # Track maximum memory usage.
            if (( $(echo "$mem > $mem_max" | bc -l) )); then
                mem_max=$mem
            fi
            samples=$((samples+1))
        else
            echo "DEBUG: No PIDs found in PGID $pgid. Program still running?"
        fi
        sleep 1 # Sample rate of 1 second.
    done
    echo "DEBUG: Program with PID $program_pid terminated."

    # ====== PHASE 4: COLLECT METRICS ======
    # Stop the iostat monitor.
    kill $io_pid 2>/dev/null || true
    wait $io_pid 2>/dev/null || true

    # Calculate average CPU usage.
    local avg_cpu=0.00
    if [[ $samples -gt 0 ]]; then
        avg_cpu=$(echo "scale=2; $cpu_sum / $samples" | bc)
    fi

    # Calculate total I/O writes (in KB) from the iostat log.
    # Column 6 corresponds to 'kB_wrtn/s' in this version of iostat.
    local total_io=$(grep -v "^Linux" "$LOG_DIR/io_${program}_${worker}_${scale}.tmp" | awk '{sum+=$6} END {print sum+0}')
    # Read execution time.
    local exec_time=$(cat "$time_file")

    # ====== PHASE 5: APPEND TO CSV ======
    # Append the collected metrics to the main CSV file.
    echo "$program,$worker,$scale,$avg_cpu,$mem_max,$total_io,$exec_time" >> "$OUTPUT_CSV"
    
    # ====== PHASE 6: CLEANUP ======
    # Remove temporary metric files for this run.
    rm -f "$LOG_DIR/io_${program}_${worker}_${scale}.tmp" "$LOG_DIR/time_${program}_${worker}_${scale}.tmp"
}

main() {
    # First, check if all required external commands are available.
    check_commands
    
    echo -e "${GREEN}"
    echo "╔════════════════════════════════════════════════════════════════════╗"
    echo "║  PA01 PART D: SCALING ANALYSIS - PROCESSES VS THREADS              ║"
    echo "║  Roll Number: 25081                                                ║"
    echo "║                                                                    ║"
    echo "║  Objective: Analyze performance scaling from 2-8 workers on a      ║"
    echo "║             SINGLE CPU CORE to measure contention and efficiency.  ║"
    echo "╚════════════════════════════════════════════════════════════════════╝"
    echo -e "${NC}"
    echo ""
    
    # Initialize the CSV file with the correct headers.
    echo -e "${YELLOW}Initializing CSV file: $OUTPUT_CSV${NC}"
    init_csv
    echo -e "${GREEN}CSV initialized with new headers${NC}"
    echo ""
    
    # Check that programs are compiled.
    if [[ ! -f "$PROJECT_DIR/progA" || ! -f "$PROJECT_DIR/progB" ]]; then
        echo -e "${RED}ERROR: progA or progB not found. Build with 'make'${NC}"
        exit 1
    fi
    
    echo -e "${YELLOW}System Information:${NC}"
    echo "  CPU Cores Available: $CPU_CORES (All tests pinned to Core 0)"
    echo ""
    
    # Define worker types and scaling ranges.
    declare -a workers=("cpu" "mem" "io")
    # Define scaling range for progA (processes), matching reference.
    declare -a scales_progA=(2 3 4 5)
    # Define scaling range for progB (threads), matching reference.
    declare -a scales_progB=(2 3 4 5 6 7 8)
    
    echo -e "${YELLOW}Start Time: $(date '+%Y-%m-%d %H:%M:%S')${NC}"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    
    # Run scaling benchmarks for progA (processes).
    echo -e "${CYAN}Running scaling analysis for progA (Processes)...${NC}"
    for scale in "${scales_progA[@]}"; do
        for worker in "${workers[@]}"; do
            run_scaling_benchmark "progA" "$worker" "$scale" || true
        done
    done
    
    # Run scaling benchmarks for progB (threads).
    echo -e "${CYAN}Running scaling analysis for progB (Threads)...${NC}"
    for scale in "${scales_progB[@]}"; do
        for worker in "${workers[@]}"; do
            run_scaling_benchmark "progB" "$worker" "$scale" || true
        done
    done
    
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo -e "${GREEN}✓ All scaling benchmarks completed successfully!${NC}"
    echo ""
    echo -e "${YELLOW}End Time: $(date '+%Y-%m-%d %H:%M:%S')${NC}"
    echo ""
    echo "Results saved to: $OUTPUT_CSV"
    echo ""
    echo "Next Steps:"
    echo "  1. Run 'python3 generate_plots.py' to create the graphs from the new CSV data."
    echo ""
}

main "$@"

main "$@"

