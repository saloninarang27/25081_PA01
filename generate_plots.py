# PLOTS EXPLANATION:                                                          
#                                                                              
#   Plot 1: MT25081_cpu_vs_components.png                                      
#   ├─ Purpose: Show CPU utilization scaling for CPU-bound workload           
#   ├─ X-axis: Scale (2, 3, 4, 5, 6, 7, 8 processes/threads)                
#   ├─ Y-axis: CPU Utilization (%)                                            
#   ├─ Line 1: progA (processes) - CPU% increases slowly (process overhead)   
#   ├─ Line 2: progB (threads) - CPU% increases much faster (better sharing)  
#   └─ Insight: Threads utilize CPU more efficiently (408% at scale 8)        
#               vs processes (76% at scale 8)                                
#                                                                              
#   Plot 2: MT25081_mem_vs_components.png                                      
#   ├─ Purpose: Show memory utilization scaling for memory-bound workload     
#   ├─ X-axis: Scale (2, 3, 4, 5, 6, 7, 8 processes/threads)                
#   ├─ Y-axis: Memory Utilization (%)                                         
#   ├─ Line 1: progA (processes) - Memory% increases linearly                 
#   │           (separate 200MB per process)                                  
#   ├─ Line 2: progB (threads) - Memory% plateaus                             
#   │           (shared 200MB allocation)                                     
#   └─ Insight: progB more efficient (0.77% at scale 8)                       
#               vs progA (3.08% at scale 8)                                  
#                                                                              
#   Plot 3: MT25081_io_vs_components.png                                       
#   ├─ Purpose: Show CPU utilization during I/O-bound workload                
#   ├─ X-axis: Scale (2, 3, 4, 5, 6, 7, 8 processes/threads)                
#   ├─ Y-axis: CPU Utilization (%)                                            
#   ├─ Line 1: progA (processes) - Low CPU%, I/O-bound                        
#   ├─ Line 2: progB (threads) - Higher CPU%, better parallelism              
#   └─ Insight: Threads better parallelize I/O operations                    
#                                                                              
#   Plot 4: MT25081_time_vs_components.png                                     
#   ├─ Purpose: Compare execution times across all worker types               
#   ├─ Contains: 3 subplots (one for each worker type)                       
#   ├─ Subplot 1: Execution time - CPU worker                                 
#   ├─ Subplot 2: Execution time - Memory worker                              
#   ├─ Subplot 3: Execution time - I/O worker                                 
#   └─ Insight: Shows how execution time varies with scale and model         


# INTERPRETATION GUIDE:                                                        
#   1. Steep line = Better scaling (more CPU cores utilized)                  
#   2. Flat line = Poor scaling (overhead dominates)                          
#   3. Parallel lines = Consistent offset (one model always faster)           
#   4. Intersecting lines = Crossover point (one model better at low scale,  
#                            other better at high scale)                      
                                                                             

# Import required libraries
import pandas as pd                # For reading CSV and data manipulation
import matplotlib.pyplot as plt    # For plotting and visualization
import sys                         # For system exit on errors
from pathlib import Path           # For file path operations
import numpy as np                 # For numerical operations

def main():
    """
    Main function to read CSV and generate all 4 plots.
    """
    
    # ====== PHASE 1: FILE VALIDATION ======
    # Define CSV filename
    csv_file = "MT25081_Part_D_CSV.csv"
    
    # Check if CSV file exists before attempting to read
    if not Path(csv_file).exists():
        print(f"Error: {csv_file} not found")
        print("Please run Part D benchmark first: bash MT25081_Part_D_scaling.sh")
        sys.exit(1)
    
    # ====== PHASE 2: READ CSV DATA ======
    # Read CSV file into pandas DataFrame for easy manipulation
    print("Reading benchmark data...")
    try:
        df = pd.read_csv(csv_file)
    except Exception as e:
        print(f"Error reading CSV: {e}")
        sys.exit(1)
    
    # Validate that required columns exist
    required_columns = ['Program', 'Worker_Type', 'Scale', 'AvgCPU_Percent', 
                        'AvgMemory_Percent', 'ExecutionTime_Sec']
    if not all(col in df.columns for col in required_columns):
        print(f"Error: CSV missing required columns: {required_columns}")
        sys.exit(1)
    
    # Print data summary
    print(f"  Loaded {len(df)} data rows")
    print(f"  Programs: {df['Program'].unique()}")
    print(f"  Worker types: {df['Worker_Type'].unique()}")
    print(f"  Scales: {sorted(df['Scale'].unique())}")
    print("")
    
    # ====== PHASE 3: CONFIGURE PLOTTING ======
    # Set matplotlib style for professional appearance
    plt.style.use('seaborn-v0_8-darkgrid')
    
    # Standard figure size for main plots
    fig_size = (14, 8)
    
    # ====== PHASE 4: PLOT 1 - CPU UTILIZATION (CPU WORKER) ======
    # Purpose: Analyze how CPU utilization scales for CPU-bound workload
    #
    # WHAT IT SHOWS:
    #   - X-axis: Number of processes/threads (2-8)
    #   - Y-axis: Measured CPU utilization (%)
    #   - progA line (circles): Processes - limited by process overhead
    #   - progB line (squares): Threads - better CPU utilization
    #
    # ANALYSIS:
    #   - progA: CPU% caps around 76% (8 cores × ~10% overhead per process)
    #   - progB: CPU% reaches 408% (8 threads × 50% each, utilizing multiple cores)
    #   - Ratio: progB is 5-6x better at high scales due to shared memory efficiency
    #
    print("Generating performance analysis plots...")
    
    # Create figure and axis for plot 1
    fig, ax = plt.subplots(figsize=fig_size)
    
    # Extract CPU worker data only
    cpu_data = df[df['Worker_Type'] == 'cpu']
    
    # Separate by program and sort by scale
    progA_cpu = cpu_data[cpu_data['Program'] == 'progA'].sort_values('Scale')
    progB_cpu = cpu_data[cpu_data['Program'] == 'progB'].sort_values('Scale')
    
    # Plot line for progA (processes)
    # marker='o' = circle markers
    # linewidth=2.5 = thick line for visibility
    # markersize=8 = large markers to see data points clearly
    ax.plot(progA_cpu['Scale'], progA_cpu['AvgCPU_Percent'], 
            marker='o', label='Program A (Processes)', 
            linewidth=2.5, markersize=8, color='#2E86AB')
    
    # Plot line for progB (threads)
    # marker='s' = square markers (different from circles for distinction)
    ax.plot(progB_cpu['Scale'], progB_cpu['AvgCPU_Percent'], 
            marker='s', label='Program B (Threads)', 
            linewidth=2.5, markersize=8, color='#A23B72')
    
    # Configure axes labels and title
    ax.set_xlabel('Scale (Count)', fontsize=12, fontweight='bold')
    ax.set_ylabel('CPU Utilization (%)', fontsize=12, fontweight='bold')
    ax.set_title('CPU Utilization vs Scale - CPU Worker', 
                 fontsize=14, fontweight='bold')
    
    # Add legend and grid
    ax.legend(fontsize=11, loc='best')
    ax.grid(True, alpha=0.3)
    
    # Save high-resolution PNG
    plt.tight_layout()
    plt.savefig('MT25081_cpu_vs_components.png', dpi=300, bbox_inches='tight')
    print("  Generated: MT25081_cpu_vs_components.png")
    plt.close()
    
    # ====== PHASE 5: PLOT 2 - MEMORY UTILIZATION (MEMORY WORKER) ======
    # Purpose: Analyze how memory utilization scales for memory-bound workload
    #
    # WHAT IT SHOWS:
    #   - X-axis: Number of processes/threads (2-8)
    #   - Y-axis: Measured memory utilization (%)
    #   - progA line (circles): Processes - linear growth (separate 200MB allocation)
    #   - progB line (squares): Threads - plateaus (shared 200MB allocation)
    #
    # ANALYSIS:
    #   - progA: Memory% increases linearly (each process gets own 200MB)
    #   - progB: Memory% stays low (all threads share single 200MB allocation)
    #   - At scale 8: progA uses 3.08%, progB uses 0.77%
    #   - Insight: Threads are 4x more memory efficient for this workload
    
    fig, ax = plt.subplots(figsize=fig_size)
    
    # Extract memory worker data only
    mem_data = df[df['Worker_Type'] == 'mem']
    
    # Separate by program and sort by scale
    progA_mem = mem_data[mem_data['Program'] == 'progA'].sort_values('Scale')
    progB_mem = mem_data[mem_data['Program'] == 'progB'].sort_values('Scale')
    
    # Plot lines
    ax.plot(progA_mem['Scale'], progA_mem['AvgMemory_Percent'], 
            marker='o', label='Program A (Processes)', 
            linewidth=2.5, markersize=8, color='#2E86AB')
    ax.plot(progB_mem['Scale'], progB_mem['AvgMemory_Percent'], 
            marker='s', label='Program B (Threads)', 
            linewidth=2.5, markersize=8, color='#A23B72')
    
    # Configure axes
    ax.set_xlabel('Scale (Count)', fontsize=12, fontweight='bold')
    ax.set_ylabel('Memory Utilization (%)', fontsize=12, fontweight='bold')
    ax.set_title('Memory Utilization vs Scale - Memory Worker', 
                 fontsize=14, fontweight='bold')
    ax.legend(fontsize=11, loc='best')
    ax.grid(True, alpha=0.3)
    
    # Save
    plt.tight_layout()
    plt.savefig('MT25081_mem_vs_components.png', dpi=300, bbox_inches='tight')
    print("  Generated: MT25081_mem_vs_components.png")
    plt.close()
    
    # ====== PHASE 6: PLOT 3 - CPU UTILIZATION (I/O WORKER) ======
    # Purpose: Analyze how CPU utilization scales during I/O-bound workload
    #
    # WHAT IT SHOWS:
    #   - X-axis: Number of processes/threads (2-8)
    #   - Y-axis: CPU utilization during I/O operations (%)
    #   - progA line (circles): Processes - low CPU%, limited I/O parallelism
    #   - progB line (squares): Threads - higher CPU%, better I/O scheduling
    #
    # ANALYSIS:
    #   - progA: CPU% stays low (11-66%) because processes serialize I/O
    #   - progB: CPU% higher (40-302%) because threads parallelize I/O
    #   - Insight: Threads allow concurrent I/O while processes wait sequentially
    
    fig, ax = plt.subplots(figsize=fig_size)
    
    # Extract I/O worker data
    io_data = df[df['Worker_Type'] == 'io']
    
    # Separate by program and sort by scale
    progA_io = io_data[io_data['Program'] == 'progA'].sort_values('Scale')
    progB_io = io_data[io_data['Program'] == 'progB'].sort_values('Scale')
    
    # Plot lines
    ax.plot(progA_io['Scale'], progA_io['AvgCPU_Percent'], 
            marker='o', label='Program A (Processes)', 
            linewidth=2.5, markersize=8, color='#2E86AB')
    ax.plot(progB_io['Scale'], progB_io['AvgCPU_Percent'], 
            marker='s', label='Program B (Threads)', 
            linewidth=2.5, markersize=8, color='#A23B72')
    
    # Configure axes
    ax.set_xlabel('Scale (Count)', fontsize=12, fontweight='bold')
    ax.set_ylabel('CPU Utilization (%)', fontsize=12, fontweight='bold')
    ax.set_title('CPU Utilization vs Scale - I/O Worker', 
                 fontsize=14, fontweight='bold')
    ax.legend(fontsize=11, loc='best')
    ax.grid(True, alpha=0.3)
    
    # Save
    plt.tight_layout()
    plt.savefig('MT25081_io_vs_components.png', dpi=300, bbox_inches='tight')
    print("  Generated: MT25081_io_vs_components.png")
    plt.close()
    
    # ====== PHASE 7: PLOT 4 - EXECUTION TIME (ALL WORKER TYPES) ======
    # Purpose: Compare execution time scaling for all three worker types
    #
    # WHAT IT SHOWS:
    #   - Contains 3 subplots (one per worker type: cpu, mem, io)
    #   - X-axis: Number of processes/threads (2-8)
    #   - Y-axis: Execution time in seconds
    #   - Each subplot compares progA vs progB for that worker type
    #
    # ANALYSIS BY WORKER:
    #
    #   CPU Worker:
    #   - progA: Time increases slightly (more processes = more overhead)
    #   - progB: Time increases slightly (more threads = more scheduling)
    #   - Both similar (2-4 seconds) because workload parallelizes well
    #
    #   Memory Worker:
    #   - progA: Time similar across scales (memory access patterns don't scale)
    #   - progB: Time similar across scales (shared memory is fast)
    #   - Both similar (8-10 seconds) because workload is CPU-bound after allocation
    #
    #   I/O Worker:
    #   - progA: Time stays high (~45 seconds) due to serialized I/O
    #   - progB: Time lower (~32 seconds) due to parallel I/O
    #   - Significant difference shows threading advantage for I/O
    
    fig, axes = plt.subplots(1, 3, figsize=(18, 5))
    
    # Iterate through each worker type
    for idx, worker in enumerate(['cpu', 'mem', 'io']):
        ax = axes[idx]
        
        # Extract data for this worker type
        progA_subset = df[(df['Program'] == 'progA') & 
                          (df['Worker_Type'] == worker)].sort_values('Scale')
        progB_subset = df[(df['Program'] == 'progB') & 
                          (df['Worker_Type'] == worker)].sort_values('Scale')
        
        # Plot execution time for progA
        ax.plot(progA_subset['Scale'], progA_subset['ExecutionTime_Sec'], 
                marker='o', label='Processes', 
                linewidth=2.5, markersize=8, color='#2E86AB')
        
        # Plot execution time for progB
        ax.plot(progB_subset['Scale'], progB_subset['ExecutionTime_Sec'], 
                marker='s', label='Threads', 
                linewidth=2.5, markersize=8, color='#A23B72')
        
        # Configure this subplot
        ax.set_xlabel('Scale', fontsize=11, fontweight='bold')
        ax.set_ylabel('Time (seconds)', fontsize=11, fontweight='bold')
        ax.set_title(f'Execution Time - {worker.upper()} Worker', 
                     fontsize=12, fontweight='bold')
        ax.legend(fontsize=10, loc='best')
        ax.grid(True, alpha=0.3)
    
    # Save all 3 subplots as single figure
    plt.tight_layout()
    plt.savefig('MT25081_time_vs_components.png', dpi=300, bbox_inches='tight')
    print("  Generated: MT25081_time_vs_components.png")
    plt.close()
    
    # ====== PHASE 8: COMPLETION MESSAGE ======
    print("")
    print("All 4 plots generated successfully!")
    print("")
    print("Plot Files:")
    print("  1. MT25081_cpu_vs_components.png  (CPU utilization scaling)")
    print("  2. MT25081_mem_vs_components.png  (Memory utilization scaling)")
    print("  3. MT25081_io_vs_components.png   (I/O CPU utilization scaling)")
    print("  4. MT25081_time_vs_components.png (Execution time comparison)")
    print("")
    print("Next Steps:")
    print("  1. Open plots to verify data visualization")
    print("  2. Analyze trends and identify optimal scale for each workload")
    print("  3. Compare Part C baseline with Part D scaling results")
    print("  4. Include plots in PA01 report")
    print("")

# ============================================================================
# SCRIPT ENTRY POINT
# ============================================================================
# This is executed when script is run directly (not imported)

if __name__ == '__main__':
    main()



