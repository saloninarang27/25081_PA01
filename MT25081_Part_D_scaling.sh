set -e
# Get project directory (where this script is located)
PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Output CSV filename for storing all scaling benchmark results
OUTPUT_CSV="MT25081_Part_D_CSV.csv"

# Log directory for temporary metric files
LOG_DIR="logs"

# Detect number of CPU cores (for reference, we'll still test beyond this)
CPU_CORES=$(nproc)

# Color codes for terminal output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

# Create log directory for temporary files
mkdir -p "$LOG_DIR"

# Scaling levels to test (7 different scales from 2 to 8)
declare -a SCALES=(2 3 4 5 6 7 8)

# Worker types to test (3 different workload types)
declare -a WORKERS=("cpu" "mem" "io")

# Programs to test (2 parallelism models)
declare -a PROGRAMS=("progA" "progB")

# Timeout for individual benchmarks (seconds)
# Prevents tests from running indefinitely if they hang
BENCHMARK_TIMEOUT=180

init_csv() {
    echo "Program,Worker_Type,Scale,AvgCPU_Percent,AvgMemory_Percent,ExecutionTime_Sec" > "$OUTPUT_CSV"
}
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
    
    # ====== PHASE 2: CPU PINNING SETUP ======
    # Determine which CPU cores to use for this scale
    local cpu_list=""
    local core_count=$scale
    
    # Cap core_count at available CPU_CORES
    if [[ $core_count -gt $CPU_CORES ]]; then
        core_count=$CPU_CORES
    fi
    
    # Build comma-separated list of cores (e.g., "0,1,2,3" for scale=4)
    for ((i=0; i<core_count; i++)); do
        if [[ $i -eq 0 ]]; then
            cpu_list="$i"
        else
            cpu_list="$cpu_list,$i"
        fi
    done
    
    # ====== PHASE 3: INITIALIZE MONITORING ======
    local metrics_file="$LOG_DIR/${program}_${worker}_${scale}_metrics.txt"
    rm -f "$metrics_file"
    
    # Start background monitoring process
    (
        while true; do
            # Sample CPU% and Memory% every second
            ps aux | grep "$program_path" | grep -v grep | \
                awk -v t="$(date +%s.%N)" '{print t "," $3 "," $4}' >> "$metrics_file"
            sleep 1
        done
    ) &
    local monitor_pid=$!
    
    # ====== PHASE 4: EXECUTE PROGRAM WITH TIMEOUT ======
    # Record start time with nanosecond precision
    local start_time=$(date +%s%N)
    
    # Execute program with timeout protection
    # timeout BENCHMARK_TIMEOUT = 180 seconds max
    # taskset -c = pin to specific cores
    # 2>/dev/null = suppress stderr
    if command -v taskset &> /dev/null; then
        timeout $BENCHMARK_TIMEOUT taskset -c "$cpu_list" "$program_path" "$worker" "$scale" > /dev/null 2>&1 || true
    else
        timeout $BENCHMARK_TIMEOUT "$program_path" "$worker" "$scale" > /dev/null 2>&1 || true
    fi
    
    # Record end time with nanosecond precision
    local end_time=$(date +%s%N)
    
    # ====== PHASE 5: COLLECT AND CALCULATE METRICS ======
    # Wait for final samples to be written
    sleep 1
    
    # Kill background monitoring process
    kill $monitor_pid 2>/dev/null || true
    wait $monitor_pid 2>/dev/null || true
    
    # Calculate execution time in seconds (5 decimal places)
    local exec_time=$(awk "BEGIN {printf \"%.5f\", ($end_time - $start_time) / 1000000000}")
    
    # Extract average CPU and memory percentages from metrics file
    local avg_cpu=0.00
    local avg_mem=0.00
    
    if [[ -f "$metrics_file" ]] && [[ -s "$metrics_file" ]]; then
        # Calculate average CPU% (column 2 after comma)
        avg_cpu=$(awk -F',' '{sum+=$2; count++} END {if (count>0) printf "%.2f", sum/count; else print "0.00"}' "$metrics_file")
        
        # Calculate average Memory% (column 3 after comma)
        avg_mem=$(awk -F',' '{sum+=$3; count++} END {if (count>0) printf "%.2f", sum/count; else print "0.00"}' "$metrics_file")
    fi
    
    # Handle empty values (safety check)
    [[ -z "$avg_cpu" || "$avg_cpu" == "" ]] && avg_cpu="0.00"
    [[ -z "$avg_mem" || "$avg_mem" == "" ]] && avg_mem="0.00"
    
    # ====== PHASE 6: APPEND TO CSV ======
    # Format: Program,Worker,Scale,AvgCPU,AvgMem,ExecTime
    echo "$program,$worker,$scale,$avg_cpu,$avg_mem,$exec_time" >> "$OUTPUT_CSV"
    
    # ====== PHASE 7: CLEANUP ======
    rm -f "$metrics_file"
}


main() {
    echo -e "${GREEN}"
    echo "╔════════════════════════════════════════════════════════════════════╗"
    echo "║  PA01 PART D: SCALING ANALYSIS - PROCESSES VS THREADS              ║"
    echo "║  Roll Number: 25081                                                ║"
    echo "║                                                                    ║"
    echo "║  Objective: Analyze performance scaling from 2 to 8 workers        ║"
    echo "║             across 3 workload types                                ║"
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
    
    # Display system information
    echo -e "${YELLOW}System Information:${NC}"
    echo "  CPU Cores: $CPU_CORES"
    echo "  Project Directory: $PROJECT_DIR"
    echo "  Benchmark Timeout: ${BENCHMARK_TIMEOUT}s per test"
    echo ""
    
    # Display scaling configuration
    echo -e "${YELLOW}Scaling Configuration:${NC}"
    echo "  Scales to test: ${SCALES[@]}"
    echo "  Programs: ${PROGRAMS[@]}"
    echo "  Workers: ${WORKERS[@]}"
    echo "  Total benchmarks: $((${#SCALES[@]} * ${#PROGRAMS[@]} * ${#WORKERS[@]}))"
    echo "  Estimated duration: 15-20 minutes"
    echo ""
    
    # Print start time
    echo -e "${YELLOW}Start Time: $(date '+%Y-%m-%d %H:%M:%S')${NC}"
    echo ""

    
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo -e "${CYAN}Running scaling analysis benchmarks...${NC}"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""
    
    # Iterate through each scale level
    for scale in "${SCALES[@]}"; do
        echo -e "${YELLOW}Scale $scale:${NC}"
        
        # Iterate through each program (progA, progB)
        for program in "${PROGRAMS[@]}"; do
            
            # Iterate through each worker type (cpu, mem, io)
            for worker in "${WORKERS[@]}"; do
                
                # Run benchmark for this combination
                # If benchmark fails, continue with next test
                run_scaling_benchmark "$program" "$worker" "$scale" || true
            done
        done
        echo ""
    done
    
    # Print completion message
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo -e "${GREEN}✓ All scaling benchmarks completed successfully!${NC}"
    echo ""
    echo -e "${YELLOW}End Time: $(date '+%Y-%m-%d %H:%M:%S')${NC}"
    echo ""
    echo "Results saved to: $OUTPUT_CSV"
    echo ""
    echo "CSV Contents (42 rows + header):"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    cat "$OUTPUT_CSV"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""
    echo "Data Analysis Insights:"
    echo "  • CPU%: Compare scaling efficiency (linear vs exponential)"
    echo "  • Memory%: Compare isolation (progA) vs sharing (progB)"
    echo "  • Time: Compare execution time across scales"
    echo ""
    echo "Next Steps:"
    echo "  1. Generate plots: python3 generate_plots.py"
    echo "  2. Compare Part C (baseline) with Part D (scaling) results"
    echo "  3. Analyze efficiency: CPU%/Time for each scale"
    echo "  4. Identify optimal scale for each workload type"
    echo ""
}

main "$@"

