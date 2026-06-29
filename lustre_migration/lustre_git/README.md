# HPC Data Migration Script (Git + /tmp Launcher Compatible)

## Overview

`data_mig_git.sh` is a high-performance, parallel data migration script designed for HPC environments. It efficiently transfers data from a source directory to a destination directory with built-in retry logic, progress tracking, and comprehensive logging.

## Workflow Diagram

```
                           START SCRIPT
                                 │
                                 ▼
                        ┌─────────────────┐
                        │ Validate Args?  │
                        └────┬────────┬───┘
                             │        │
                        Yes  │        │  No
                             ▼        ▼
                        Continue   EXIT ERROR
                             │
                             ▼
                        ┌─────────────────┐
                        │ Source Exists?  │
                        └────┬────────┬───┘
                             │        │
                        Yes  │        │  No
                             ▼        ▼
                        Continue   EXIT ERROR
                             │
                             ▼
                    ┌──────────────────────┐
                    │ Create Destination   │
                    │ (if needed)          │
                    └──────────┬───────────┘
                               │
                               ▼
                    ┌──────────────────────┐
                    │ Clean Up Partials    │
                    └──────────┬───────────┘
                               │
                               ▼
                    ┌──────────────────────┐
                    │ Init Logging &       │
                    │ Timestamp            │
                    └──────────┬───────────┘
                               │
                               ▼
                    ┌──────────────────────┐
                    │ Discover Items in    │
                    │ Source Directory     │
                    └──────────┬───────────┘
                               │
                               ▼
                    ┌──────────────────────┐
                    │ Build File List      │
                    └──────────┬───────────┘
                               │
                               ▼
                    ┌──────────────────────┐
                    │ Start Parallel Jobs  │
                    │ (xargs -P N)         │
                    └──────────┬───────────┘
                               │
              ┌────────────────┼────────────────┐
              │                │                │
              ▼                ▼                ▼
         ┌────────┐       ┌────────┐       ┌────────┐
         │Job 1   │       │Job 2   │  ...  │Job N   │
         │ rsync  │       │ rsync  │       │ rsync  │
         └────┬───┘       └────┬───┘       └────┬───┘
              │                │                │
              └────────────────┼────────────────┘
                               │
                    ┌──────────▼──────────┐
                    │ Transfer Success?   │
                    └────┬────────────┬───┘
                         │            │
                    Yes  │            │  No
                         ▼            ▼
                   ┌──────────┐  ┌──────────────┐
                   │Record    │  │Retry < 3?    │
                   │Size      │  └┬─────────┬───┘
                   └────┬─────┘   │         │
                        │    Yes  │         │ No
                        │         ▼         ▼
                        │    ┌────────┐ ┌───────┐
                        │    │Retry   │ │ERROR  │
                        │    │Job     │ │Log    │
                        │    └────┬───┘ └─┬─────┘
                        │         │       │
                        └─────────┼───────┘
                                  │
                        ┌─────────▼──────────┐
                        │ More Items?        │
                        └────┬────────────┬──┘
                             │            │
                        Yes  │            │  No
                             ▼            ▼
                      ┌────────────┐  ┌──────────────┐
                      │Continue    │  │Calculate     │
                      │Transfer    │  │Statistics    │
                      └────┬───────┘  └────┬─────────┘
                           │               │
                           └───────┬───────┘
                                   │
                        ┌──────────▼──────────┐
                        │ Generate Report &   │
                        │ Save Log File       │
                        └────────┬────────────┘
                                 │
                        ┌────────▼─────────┐
                        │ EXIT SUCCESS (0) │
                        └──────────────────┘

    ┌─ Signal Handling ─────────────────────┐
    │ Ctrl+C Interrupt                      │
    │ ↓                                     │
    │ Set INTERRUPTED flag                 │
    │ Jump to: Calculate Statistics        │
    │ Result: EXIT (130) after cleanup     │
    └───────────────────────────────────────┘
```

## High-Level Process Flow

```
USER PERSPECTIVE:
┌────────────────────────────────────────────────────────────────┐
│                   data_mig_git.sh Execution                   │
└────────────────────────────────────────────────────────────────┘

  User                  Migration Script        Source Dir        Destination
    │                         │                    │                  │
    │ Execute Script          │                    │                  │
    ├────────────────────────>│                    │                  │
    │                         │                    │                  │
    │                         │ Validate Args      │                  │
    │                         ├──────────────────> │                  │
    │                         │                    │                  │
    │                         │ Check if exists    │                  │
    │                         │<──────────────────┤                  │
    │                         │                    │                  │
    │                         │ Create Dest        │                  │
    │                         ├──────────────────────────────────────>│
    │                         │                    │                  │
    │                         │ Initialize Log     │                  │
    │                         ├─────────────────────────────────────>│
    │                         │                    │                  │
    │                         │ Discover Items     │                  │
    │                         ├──────────────────> │                  │
    │                         │                    │                  │
    │                         │ Receive Item List  │                  │
    │                         │<──────────────────┤                  │
    │                         │                    │                  │
    │                         │ ┌─ Parallel Rsync Jobs ─┐            │
    │                         │ │  Job1  Job2 ... JobN  │            │
    │                         │ │   │     │        │     │            │
    │                         │ │   ├─────┼────────┤     │            │
    │                         │ └──>│     │        │<────┘────────────>│
    │                         │     │ Transfer Data (Parallel)        │
    │                         │     │     │        │                  │
    │                         │<────┤─────┼────────┤                  │
    │                         │ Status & Size Info │                  │
    │                         │                    │                  │
    │                         │ Record Stats       │                  │
    │                         ├─────────────────────────────────────>│
    │                         │                    │                  │
    │                         │ Calculate Stats    │                  │
    │                         ├──────────────────────────────────────>│
    │                         │                    │                  │
    │ Display Summary         │                    │                  │
    │<────────────────────────┤                    │                  │
    │                         │                    │                  │
    │ Exit Code: 0/1/130      │                    │                  │
    │                         │                    │                  │
```

PARALLEL EXECUTION DETAIL:
```
    Time    Parallel Job Manager
            │
    t=0s    ├─> Job1: rsync source/item1 dest/ ─┐
            ├─> Job2: rsync source/item2 dest/ ─┤
            ├─> Job3: rsync source/item3 dest/ ─┤ (All run simultaneously)
            ├─> ... (up to N jobs)              ─┤
            └─> JobN: rsync source/itemN dest/ ─┘
                      │
                      ├─ Aggregate Results
                      ├─ Log Progress
                      └─ Return Stats

    t=Ts    All transfers complete
            ├─ Collect final stats
            ├─ Calculate average speed
            └─ Generate report
```

## Migration Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                    HPC Data Migration System                     │
└─────────────────────────────────────────────────────────────────┘

                          Migration Script
                          (data_mig_git.sh)
                                 │
                ┌────────────────┼────────────────┐
                │                │                │
                ▼                ▼                ▼
         ┌────────────┐   ┌────────────┐   ┌────────────┐
         │ Validation │   │ File List  │   │ Logging    │
         │ Module     │   │ Builder    │   │ System     │
         └────────────┘   └────────────┘   └────────────┘
                │                │                │
                └────────────────┼────────────────┘
                                 │
                    ┌────────────────────────┐
                    │ Parallel Job Manager   │
                    │ (xargs -P N)           │
                    └────────────────────────┘
                    │         │         │
         ┌──────────┴─────────┴─────────┴──────────┐
         │                                          │
    ┌────▼─────┐  ┌────▼─────┐  ...  ┌────▼─────┐
    │ rsync    │  │ rsync    │       │ rsync    │
    │ Job 1    │  │ Job 2    │       │ Job N    │
    └────┬─────┘  └────┬─────┘       └────┬─────┘
         │             │                   │
         │  ┌──────────┴───────────────────┤
         │  │                              │
    ┌────▼──▼──────┐              ┌──────▼───────┐
    │ SOURCE        │              │ DESTINATION  │
    │ /lustre/src   │  ─────────►  │ /lustre/dst  │
    │ (Data Files)  │   (Transfer) │ (Data Files) │
    └───────────────┘              └──────────────┘

    ┌──────────────────────────────────────────────┐
    │  /tmp/migration_YYYYMMDD_HHMMSS.log         │
    │  - Progress tracking                         │
    │  - Success/Failure logs                      │
    │  - Performance statistics                    │
    └──────────────────────────────────────────────┘
```

## Data Transfer Timeline

```
Time  Event
────────────────────────────────────────────────────────────
  0s  │ Script starts
      │ • Validate arguments
      │ • Check source/destination
      │ • Initialize logging
      │
  2s  │ File discovery
      │ • Scan source directory
      │ • Build item list
      │
  3s  │ Parallel transfer begins
      │ ┌─ Job 1: rsync item_1     (████████████         ) 60%
      │ ├─ Job 2: rsync item_2     (██████               ) 35%
      │ ├─ Job 3: rsync item_3     (██████████████████   ) 92%
      │ ├─ Job 4: rsync item_4     (Retry: Attempt 2/3   )
      │ └─ Job 5: rsync item_5     (████████             ) 40%
      │
120s  │ Transfer phase continues...
      │ (Depending on data size and network)
      │
220s  │ All transfers complete
      │ • Calculate statistics
      │ • Generate final report
      │
222s  │ ✓ Migration completed
      │   Total: 45.32 GB transferred in 222 seconds
      │   Speed: 208.23 MB/s average
```

## Parallel Job Execution Model

```
                    Main Process
                          │
              ┌───────────┴───────────┐
              │                       │
         Job Spawner            Log Aggregator
              │                       │
    ┌─────────┼─────────┐            │
    │         │         │            │
   Job1      Job2      JobN          │
    │         │         │            │
    └─────────┼─────────┴────────────┤
              │                      │
         Rsync Transfers      Write Statistics
              │                      │
    ┌─────────┼─────────┐            │
    │         │         │            │
   Item1     Item2     ItemN         │
    │         │         │            │
    └─────────┼─────────┴────────────┤
              │                      │
         DESTINATION              LOG FILE
         Directory               /tmp/mig.log
```

## Error Handling and Retry Flow

```
                        START TRANSFER
                              │
                              ▼
                       ┌─────────────────┐
                       │ Execute rsync   │
                       │ Job             │
                       └────────┬────────┘
                                │
                                ▼
                       ┌─────────────────┐
                       │ Transfer        │
                       │ Successful?     │
                       └────┬────────┬───┘
                            │        │
                       Yes  │        │  No
                            ▼        ▼
                       ┌───────┐  ┌──────────────┐
                       │Record │  │ Retry Count  │
                       │Size   │  │ < 3?         │
                       └───┬───┘  └──┬────────┬──┘
                           │         │        │
                           │    Yes  │        │ No
                           ▼         ▼        ▼
                       ┌────────┐ ┌──────┐ ┌───────┐
                       │Log     │ │Inc   │ │Log    │
                       │SUCCESS │ │Retry │ │ERROR  │
                       └───┬────┘ └──┬───┘ └───┬───┘
                           │         │         │
                           │         ▼         │
                           │    ┌─────────┐    │
                           │    │Wait 2s  │    │
                           │    └────┬────┘    │
                           │         │         │
                           │         ▼         │
                           │    ┌─────────┐    │
                           │    │Retry:   │    │
                           │    │Execute  │    │
                           │    │rsync    │    │
                           │    │again    │    │
                           │    └────┬────┘    │
                           │         │         │
                           │         └────┬────┘
                           │              │
                           └──────┬───────┘
                                  │
                        ┌─────────▼─────────┐
                        │ Move to Next Item │
                        └────────┬──────────┘
                                 │
                        ┌────────▼────────┐
                        │ More Items?     │
                        └────┬────────┬───┘
                             │        │
                        Yes  │        │  No
                             ▼        ▼
                        ┌───────┐ ┌─────────────┐
                        │Process│ │Generate     │
                        │Next   │ │Final Report │
                        │Item   │ └──────┬──────┘
                        └───┬───┘        │
                            │           │
                            └─────┬─────┘
                                  │
                         ┌────────▼────────┐
                         │ Complete        │
                         │ (Save & Exit)   │
                         └─────────────────┘

RETRY LOGIC SUMMARY:
═══════════════════════════════════════════
• Max Retries: 3 attempts per item
• Wait Between Retries: 2 seconds
• Items that fail after 3 attempts: Marked ERROR in log
• Script continues processing remaining items
• Failed items do not block other transfers
═══════════════════════════════════════════
```

## State Transitions

```
┌─────────────┐
│   INITIAL   │
│   STATE     │
└──────┬──────┘
       │ Script invoked
       ▼
┌─────────────────┐
│  VALIDATION     │
│  - Args check   │
│  - Path check   │
└──────┬──────────┘
       │ Valid
       ▼
┌─────────────────┐
│  PREPARATION    │
│  - Create dest  │
│  - Clean partial│
│  - Init logging │
└──────┬──────────┘
       │
       ▼
┌──────────────────┐
│  DISCOVERY       │
│  - Find items    │
│  - Build list    │
└────────┬─────────┘
         │
         ▼
    ┌──────────────────────┐
    │ MIGRATION RUNNING    │
    │ (Parallel transfers) │
    └────────┬─────────────┘
             │
    ┌────────┴────────┐
    │                 │
   User Interrupt  Complete/Fail
    │                 │
    ▼                 ▼
┌──────────┐    ┌──────────────┐
│INTERRUPTED   │ FINALIZING    │
└──────────────┘ │- Calculate  │
    │           │  statistics │
    └───────────┤- Gen report │
                │- Save log   │
                └──────┬──────┘
                       │
                       ▼
                ┌────────────┐
                │ COMPLETE   │
                │ (Exit 0/1) │
                └────────────┘
```

## Features

- **Parallel Processing**: Configurable parallel jobs for concurrent file transfers
- **Retry Logic**: Automatic retry mechanism (up to 3 attempts) for failed transfers
- **Progress Tracking**: Real-time progress reporting and transfer speed calculations
- **Comprehensive Logging**: Detailed logs with timestamps, success/failure status, and performance metrics
- **Signal Handling**: Graceful handling of interrupts (Ctrl+C) with cleanup and final statistics
- **Atomic Operations**: Ensures data integrity with retry mechanisms before marking transfer complete
- **File Cleanup**: Removes partial/incomplete transfers before starting migration

## Quick Start

```
QUICK START FLOW:
═════════════════════════════════════════════════════════════════

Step 1: Script Ready
       [Script installed and executable]
                    │
                    ▼
       
Step 2: Execute Command
       ./data_mig_git.sh /src /dst 10
                    │
                    ▼

Step 3: Validation ✓
       ✓ Arguments valid
       ✓ Source exists
       ✓ Destination created
                    │
                    ▼

Step 4: Discover Files
       ✓ Scanning source directory
       ✓ Found 45 top-level items
                    │
                    ▼

Step 5: Parallel Transfers
       ✓ 10 concurrent jobs spawned
       ✓ All items being transferred
       ✓ Real-time progress in log
                    │
                    ▼

Step 6: Complete ✓
       ✓ All transfers successful
       ✓ Log file saved
       ✓ Summary displayed
       ✓ Exit code: 0

═════════════════════════════════════════════════════════════════
RESULT: 45.32 GB transferred in 222 seconds (208.23 MB/s average)
═════════════════════════════════════════════════════════════════
```

## Prerequisites

- Bash shell
- `rsync` utility
- `find`, `awk`, `bc` commands
- Sufficient disk space on destination for source data
- Read permissions on source directory
- Write permissions on destination directory

## Usage

```bash
./data_mig_git.sh <source> <destination> [parallel_jobs]
```

### Arguments

| Argument | Description | Default | Required |
|----------|-------------|---------|----------|
| `source` | Full path to source directory | - | Yes |
| `destination` | Full path to destination directory | - | Yes |
| `parallel_jobs` | Number of parallel transfer jobs | 10 | No |

### Examples

**Basic migration with default parallel jobs (10):**
```bash
./data_mig_git.sh /lustre/source /lustre/destination
```

**Custom parallel jobs (20 concurrent transfers):**
```bash
./data_mig_git.sh /lustre/source /lustre/destination 20
```

**From NFS to Lustre:**
```bash
./data_mig_git.sh /mnt/nfs/data /mnt/lustre/data 15
```

## How It Works

1. **Validation**: Checks that source directory exists and creates destination if needed
2. **Cleanup**: Removes any incomplete transfers from previous runs
3. **File Discovery**: Lists all top-level items in source directory
4. **Parallel Transfer**: Spawns parallel rsync jobs for each item
5. **Retry on Failure**: Automatically retries failed transfers up to 3 times
6. **Progress Tracking**: Records transfer size and speed metrics
7. **Final Report**: Generates summary with total duration, data transferred, and average speed

## Output

### Console Output
The script displays a summary of the migration status during execution:
```
==================================================
DATA MIGRATION STARTED
Start Time        : Mon Jun 29 18:21:48 +0530 2026
Source            : /lustre/source
Destination       : /lustre/destination
Parallel Jobs     : 10
Log File          : /tmp/migration_20260629_182148.log
==================================================
Total items found: 45
```

### Log File
A detailed log file is created at `/tmp/migration_YYYYMMDD_HHMMSS.log` containing:
- Individual file transfer status (SUCCESS/FAILED)
- Retry attempts
- Transfer progress details
- Final statistics

### Final Summary
Upon completion or interruption:
```
==================================================
MIGRATION COMPLETED
End Time            : Mon Jun 29 18:25:30 +0530 2026
Total Duration      : 222 seconds
Total Data Transfer : 45.32 GB
Average Speed       : 208.23 MB/s
Log File            : /tmp/migration_20260629_182148.log
==================================================
```

## Performance Tuning

### Optimal Parallel Jobs
- **Small files (MB)**: 20-30 jobs
- **Medium files (GB)**: 10-20 jobs
- **Large files (100GB+)**: 5-10 jobs

Adjust based on:
- Network bandwidth
- System CPU cores
- Storage IOPS capacity
- Available memory

### Performance Impact Analysis

```
Transfer Speed vs Parallel Jobs
─────────────────────────────────────────────────

Speed
(MB/s)
   │
250 │                    ╱────────────────
   │                  ╱─╱
200 │              ╱╱
   │          ╱╱
150 │      ╱╱
   │  ╱╱
100 │╱
   │
   └────┴────┴────┴────┴────┴────┴────┴─── Parallel Jobs
     2    5   10   15   20   25   30   40

OBSERVATION:
• Speed increases significantly up to 15-20 jobs
• Diminishing returns beyond 20-25 jobs
• Overhead increases with too many jobs (40+)
• Optimal: 10-20 for most HPC environments
```

### Memory & CPU Utilization

```
Resource vs Parallel Jobs
─────────────────────────────────────────────────

CPU Usage (%)         Memory Usage (GB)
    │                     │
100 │    ╭─────           │    ╭─────────
    │   ╱                 │   ╱
 75 │  ╱                  │  ╱
    │ ╱                   │ ╱
 50 │╱                    │╱
    │                     │
 25 │                     │
    │                     │
    └─────────────────────┴─────────────
      5  10  15  20  25     5  10  15  20

RECOMMENDATION:
• Monitor system load
• CPU: Keep below 80% for system stability
• Memory: Reserve at least 20% for OS
• Adjust parallel jobs accordingly
```

## Rsync Options Used

| Option | Purpose |
|--------|---------|
| `-a` | Archive mode (preserves permissions, timestamps, etc.) |
| `-H` | Preserve hard links |
| `-A` | Preserve ACLs |
| `-X` | Preserve extended attributes |
| `--delete` | Delete files in destination not in source |
| `--numeric-ids` | Preserve user/group IDs numerically |
| `--info=progress2` | Show file transfer progress |
| `--stats` | Display transfer statistics |

## Troubleshooting

### Script fails with "Source does not exist"
**Solution**: Verify the source path is correct and accessible:
```bash
ls -la /your/source/path
```

### Migration is slow
**Solutions**:
- Increase `parallel_jobs` for faster I/O (but monitor system load)
- Check network connectivity and bandwidth
- Monitor system resources (CPU, memory, disk I/O)

### Partial transfers remain
The script cleans up partial transfers before starting:
- Removes `.rsync-partial` directory
- Deletes files with 6-character extensions (rsync temp files)

### Check migration status during execution
```bash
tail -f /tmp/migration_YYYYMMDD_HHMMSS.log
```

### Cancel migration gracefully
Press `Ctrl+C` to interrupt. The script will:
- Stop all active transfers
- Display final statistics
- Save the log file

## Log File Location

Logs are stored in `/tmp/` with timestamp:
```
/tmp/migration_YYYYMMDD_HHMMSS.log
```

To find the most recent log:
```bash
ls -lt /tmp/migration_*.log | head -1
```

## Error Handling

- **Validation Errors**: Exit code 1 if source doesn't exist or arguments are missing
- **Transfer Errors**: Retries up to 3 times before marking as failed
- **Interrupt (Ctrl+C)**: Exit code 130, cleanup and report final statistics
- **Partial Transfers**: Cleaned up automatically on script restart

## Exit Codes

| Code | Meaning |
|------|---------|
| 0 | Migration completed successfully |
| 1 | Validation failed or file not found |
| 130 | Interrupted by user (Ctrl+C) |

## Related Scripts

- `data_mig_git_encypt.sh` - Encrypted data migration variant
- `data_mig.sh` - Alternative migration script
- `data_mig_encypt.sh` - Encrypted alternative variant

## Author Notes

- This script is designed for Git-based launcher compatibility
- Supports `/tmp` temporary storage for launchers
- Ideal for Lustre filesystem migrations in HPC environments
- Thread-safe with proper cleanup on interruption

## Real-World Usage Scenarios

### Scenario 1: Large-Scale NFS to Lustre Migration

```
Source: /mnt/nfs/hpc_data (2.5 TB, 10,000 files)
Target: /mnt/lustre/hpc_data

Command:
  ./data_mig_git.sh /mnt/nfs/hpc_data /mnt/lustre/hpc_data 15

Expected Performance:
  • Parallel Jobs: 15 (balanced for 2.5 TB)
  • Average Speed: 250-300 MB/s
  • Estimated Duration: ~2-3 hours
  • Total Items: ~50 top-level directories
```

### Scenario 2: Fast Local to Local Migration

```
Source: /local/scratch/data (500 GB, high speed SSD)
Target: /lustre/user_data

Command:
  ./data_mig_git.sh /local/scratch/data /lustre/user_data 20

Expected Performance:
  • Parallel Jobs: 20 (local = low latency)
  • Average Speed: 400-600 MB/s
  • Estimated Duration: ~15-25 minutes
  • High throughput, low retry rate
```

### Scenario 3: Conservative Network Migration

```
Source: /remote/archive (1 TB, over WAN)
Target: /lustre/archive

Command:
  ./data_mig_git.sh /remote/archive /lustre/archive 5

Expected Performance:
  • Parallel Jobs: 5 (network limited)
  • Average Speed: 50-100 MB/s
  • Estimated Duration: ~2-5 hours
  • Higher retry rate expected
  • Monitor network utilization
```

## Migration Status Monitoring

### Real-Time Log Monitoring

```bash
# Watch log file for updates
tail -f /tmp/migration_20260629_182148.log

# Count successful transfers
grep "SUCCESS:" /tmp/migration_*.log | wc -l

# Find failed items
grep "ERROR:" /tmp/migration_*.log

# Monitor transfer speed
tail -f /tmp/migration_*.log | grep "Total written"

# Check specific item status
grep "item_name" /tmp/migration_*.log
```

### Performance Monitoring During Transfer

```
┌─ Current Migration Status ─────────────────────┐
│                                               │
│ Items Processed:    45/50  (90%)  ████████░  │
│ Data Transferred:   41.2 GB / 45 GB (92%)     │
│ Current Speed:      258 MB/s                  │
│ Elapsed Time:       165 seconds               │
│ Estimated Time:     8 seconds remaining       │
│                                               │
│ Active Jobs:        12/15                     │
│ Failed Items:       2 (retrying)              │
│ Pending Items:      5                         │
│                                               │
└───────────────────────────────────────────────┘
```

## Scaling Across Multiple Nodes

For very large migrations, consider running multiple instances:

```bash
# Node 1: Migrate directories A-J
./data_mig_git.sh /source/A-J /dest/A-J 12 &

# Node 2: Migrate directories K-T  
./data_mig_git.sh /source/K-T /dest/K-T 12 &

# Node 3: Migrate directories U-Z
./data_mig_git.sh /source/U-Z /dest/U-Z 12 &

# Monitor all jobs
jobs -l
tail -f /tmp/migration_*.log
```

## Troubleshooting with Diagnostics

### Check System Resources

```bash
# CPU and Memory
top -b -n 1 | head -15

# Disk I/O
iostat -x 1 5

# Network utilization
iftop -n

# Open file descriptors
lsof | grep rsync | wc -l
```

### Analyze Failed Transfers

```bash
# Extract failure details
grep "FAILED\|ERROR" /tmp/migration_*.log | tail -20

# Check if specific paths are problematic
grep "FAILED.*pattern" /tmp/migration_*.log

# List all items that needed retries
grep "Attempt 2\|Attempt 3" /tmp/migration_*.log
```

### Calculate Migration Statistics

```bash
# Total data transferred
grep "Total written" /tmp/migration_*.log | tail -1

# Success rate
SUCCESS=$(grep -c "SUCCESS:" /tmp/migration_*.log)
TOTAL=$(grep -c "SUCCESS:\|ERROR:" /tmp/migration_*.log)
echo "Success Rate: $((SUCCESS * 100 / TOTAL))%"

# Average file size
grep "Total written" /tmp/migration_*.log | awk '{sum+=$4; count++} 
END {print "Avg:", sum/count/1024/1024 " MB"}'
```
