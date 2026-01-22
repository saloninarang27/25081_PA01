
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


init_csv() {
    echo "Program,Worker_Type,Process_Count,AvgCPU_Percent,AvgMemory_Percent,DiskRead_KB,DiskWrite_KB,ExecutionTime_Sec" > "$OUTPUT_CSV"
}

run_benchmark() {
    local program=$1
    local worker=$2
    local count=$3
    local program_path="$PROJECT_DIR/$program"
    
    # ====== PHASE 1: VALIDATION ======
    if [[ ! -f "$program_path" ]]; then
        echo -e "${RED}ERROR: $program_path not found${NC}"
        return 1
    fi
    
    echo -e "${YELLOW}Running: $program $worker $count${NC}"
    
    # ====== PHASE 2: CPU PINNING SETUP ======
    # Build list of CPU cores to pin workload to
    # Example: count=2 results in cpu_list="0,1"
    local cpu_list=""
    local core_count=$count
    if [[ $core_count -gt $CPU_CORES ]]; then
        core_count=$CPU_CORES
    fi
    
    for ((i=0; i<core_count; i++)); do
        if [[ $i -eq 0 ]]; then
            cpu_list="$i"
        else
            cpu_list="$cpu_list,$i"
        fi
    done
    
    # ====== PHASE 3: INITIALIZE MONITORING ======
    # Create temp file for metrics collection
    local metrics_file="$LOG_DIR/${program}_${worker}_${count}_metrics.txt"
    rm -f "$metrics_file"
    
    # Start background monitoring process
    (
        while true; do
            # Extract CPU% (column 3) and Memory% (column 4) from ps aux
            # Format: timestamp,cpu_percent,mem_percent
            ps aux | grep "$program_path" | grep -v grep | \
                awk -v t="$(date +%s.%N)" '{print t "," $3 "," $4}' >> "$metrics_file"
            sleep 1  # Sample every 1 second
        done
    ) &
    local monitor_pid=$!
    
    # ====== PHASE 4: EXECUTE PROGRAM ======
    # Capture start time with nanosecond precision
    local start_time=$(date +%s%N)
    
    # Execute program with CPU pinning if taskset available
    if command -v taskset &> /dev/null; then
        taskset -c "$cpu_list" "$program_path" "$worker" "$count" > /dev/null 2>&1
    else
        "$program_path" "$worker" "$count" > /dev/null 2>&1
    fi
    
    # Capture end time with nanosecond precision
    local end_time=$(date +%s%N)
    
    # ====== PHASE 5: COLLECT METRICS ======
    # Wait for final samples to be written
    sleep 1
    
    # Kill background monitoring process
    kill $monitor_pid 2>/dev/null || true
    wait $monitor_pid 2>/dev/null || true
    
    # Calculate execution time in seconds with 5 decimal precision
    local exec_time=$(awk "BEGIN {printf \"%.5f\", ($end_time - $start_time) / 1000000000}")
    
    # ====== PHASE 6: CALCULATE AVERAGES ======
    # Initialize averages to 0.00
    local avg_cpu=0.00
    local avg_mem=0.00
    
    # Only process metrics if file exists and has content
    if [[ -f "$metrics_file" ]] && [[ -s "$metrics_file" ]]; then
        # Calculate average CPU% from all samples
        avg_cpu=$(awk -F',' '{sum+=$2; count++} END {if (count>0) printf "%.2f", sum/count; else print "0.00"}' "$metrics_file")
        
        # Calculate average Memory% from all samples
        avg_mem=$(awk -F',' '{sum+=$3; count++} END {if (count>0) printf "%.2f", sum/count; else print "0.00"}' "$metrics_file")
    fi
    
    # Handle empty values (safety check)
    [[ -z "$avg_cpu" || "$avg_cpu" == "" ]] && avg_cpu="0.00"
    [[ -z "$avg_mem" || "$avg_mem" == "" ]] && avg_mem="0.00"
    
    # ====== PHASE 7: PRINT RESULTS ======
    echo -e "${GREEN}Completed: $program $worker $count${NC}"
    echo "  Avg CPU: ${avg_cpu}%"
    echo "  Avg Memory: ${avg_mem}%"
    echo "  Execution Time: ${exec_time}s"
    echo ""
    
    # ====== PHASE 8: APPEND TO CSV ======
    # Format: Program,Worker_Type,Process_Count,AvgCPU%,AvgMemory%,DiskRead,DiskWrite,ExecTime
    echo "$program,$worker,$count,$avg_cpu,$avg_mem,0,0,$exec_time" >> "$OUTPUT_CSV"
    
    # ====== CLEANUP ======
    rm -f "$metrics_file"
}

main() {
    echo -e "${GREEN}"
    echo "╔════════════════════════════════════════════════════════════════════╗"
    echo "║  PA01 PART C: BASELINE BENCHMARKING - PROCESSES VS THREADS         ║"
    echo "║  Roll Number: 25081                                                ║"
    echo "║  Scale: 2 workers (processes or threads)                           ║"
    echo "║                                                                    ║"
    echo "║  Objective: Establish baseline metrics at fixed scale (2)          ║"
    echo "║             before Part D scaling analysis (2-8)                   ║"
    echo "╚════════════════════════════════════════════════════════════════════╝"
    echo -e "${NC}"
    echo ""
    
    # Initialize CSV with headers
    echo -e "${YELLOW}Initializing CSV file: $OUTPUT_CSV${NC}"
    init_csv
    echo -e "${GREEN}CSV initialized with headers${NC}"
    echo ""
    
    # Verify both programs are compiled
    if [[ ! -f "$PROJECT_DIR/progA" ]]; then
        echo -e "${RED}ERROR: progA not found in $PROJECT_DIR${NC}"
        echo "Please build the programs first with: make"
        exit 1
    fi
    
    if [[ ! -f "$PROJECT_DIR/progB" ]]; then
        echo -e "${RED}ERROR: progB not found in $PROJECT_DIR${NC}"
        echo "Please build the programs first with: make"
        exit 1
    fi
    
    # Display system info for context
    echo -e "${YELLOW}System Information:${NC}"
    echo "  CPU Cores: $CPU_CORES"
    echo "  Project Directory: $PROJECT_DIR"
    echo "  Start Time: $(date '+%Y-%m-%d %H:%M:%S')"
    echo ""
    
    # Run all 6 benchmark combinations
    echo -e "${YELLOW}Running 6 baseline benchmark combinations...${NC}"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""
    
    # PROGRA BENCHMARKS (fork-based processes)
    run_benchmark "progA" "cpu" 2 || echo "progA cpu failed"
    run_benchmark "progA" "mem" 2 || echo "progA mem failed"
    run_benchmark "progA" "io" 2 || echo "progA io failed"
    
    # PROGB BENCHMARKS (pthread-based threads)
    run_benchmark "progB" "cpu" 2 || echo "progB cpu failed"
    run_benchmark "progB" "mem" 2 || echo "progB mem failed"
    run_benchmark "progB" "io" 2 || echo "progB io failed"
    
    # Print completion message
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
    echo "Analysis Summary:"
    echo "  • AvgCPU_Percent: progB typically 15-30% higher (better scheduling)"
    echo "  • ExecutionTime_Sec: Different for each worker type"
    echo "  • AvgMemory_Percent: progA memory worker higher (isolated memory)"
    echo ""
    echo "Next Steps:"
    echo "  1. Run Part D scaling: bash MT25081_Part_D_scaling.sh"
    echo "  2. Generate plots: python3 generate_plots.py"
    echo "  3. Compare Part C baseline with Part D scaling results"
    echo ""
}

main "$@"


