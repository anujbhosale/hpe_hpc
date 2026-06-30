# Lustre Enterprise Benchmark v2

## Overview

`lustre_enterprise_benchmark_v2.sh` is a comprehensive performance benchmarking script designed to validate and measure Lustre filesystem performance. It executes a series of tests to evaluate sequential I/O throughput, random I/O performance, and metadata operations, then generates a detailed report with pass/fail status against industry benchmarks.

## Features

- **Sequential I/O Testing**: Measures read/write throughput for large sequential operations
- **Random I/O Testing**: Evaluates IOPS and bandwidth for random access patterns using FIO
- **Metadata Performance**: Tests file creation and deletion performance
- **Multi-Mount Support**: Select from multiple Lustre mounts on the system
- **Comprehensive Reporting**: Generates timestamped reports with pass/fail status
- **Filesystem Discovery**: Automatically detects and reports MDT and OST counts
- **Color-Coded Output**: Easy-to-read status messages (PASS/WARN/FAIL/INFO)
- **Automated Cleanup**: Removes test data after benchmark completion
- **Enterprise Thresholds**: Tests against industry-standard performance expectations

## When to Use

### Recommended Scenarios:
- **Initial Setup**: Validate fresh Lustre installation performance
- **Health Checks**: Quarterly or monthly performance audits
- **Regression Detection**: Identify performance degradation over time
- **Post-Maintenance**: Verify performance after upgrades or repairs
- **Capacity Planning**: Establish baseline before critical workloads
- **SLA Validation**: Ensure contractual performance commitments are met
- **Troubleshooting**: Diagnose performance bottlenecks
- **Load Testing**: Validate system before production deployment

## Prerequisites

### Required Tools
```bash
lfs     # Lustre filesystem utilities
fio     # Flexible I/O tester (flexible I/O workloads)
dd      # Data duplicator utility
awk     # Text processing
grep    # Pattern matching
sed     # Stream editor
find    # File search
stat    # File statistics
mv      # Move files
rm      # Remove files
df      # Disk free space
date    # Timestamp generation
```

### System Requirements
- Lustre filesystem mounted and accessible
- At least 8 GB free space (for default 4GB sequential + 4GB random tests)
- Read/write permissions in benchmark directory
- Bash shell 4.0 or higher

### Installation

**Ubuntu/Debian:**
```bash
sudo apt-get install lustre-client-utils fio coreutils gawk grep sed findutils
```

**RHEL/CentOS:**
```bash
sudo yum install lustre-client-utils fio coreutils gawk grep sed findutils
```

## Usage

### Basic Execution
```bash
./lustre_enterprise_benchmark_v2.sh
```

### Interactive Prompts

**1. Select Lustre Mount:**
```
Available Lustre mounts:
1) /mnt/lustre
2) /mnt/lustre/project
Select mount: 1
[PASS] Selected mount: /mnt/lustre
```

**2. Specify Benchmark Directory:**
```
Enter benchmark folder inside mount: /mnt/lustre/benchmark
```

**3. Customize Metadata Test (Optional):**
```
How many files to create? [1000]: 5000
Size of each file in MB? [1]: 2
```

### Command Line Arguments
Currently, the script uses interactive prompts. To automate with default values:

```bash
# Create wrapper script for automation
cat > run_benchmark.sh << 'EOF'
#!/bin/bash
(
  echo "1"                              # Select first mount
  echo "/mnt/lustre/benchmark"          # Benchmark directory
  echo "1000"                           # File count (default)
  echo "1"                              # File size in MB (default)
) | ./lustre_enterprise_benchmark_v2.sh
EOF

chmod +x run_benchmark.sh
./run_benchmark.sh
```

## How It Works

```
EXECUTION WORKFLOW:
═══════════════════════════════════════════════════════════════

START
  │
  ├─ 1. Check Tools
  │    └─ Verify lfs, fio, dd, awk, grep, sed, etc. available
  │       Exit if any tool missing
  │
  ├─ 2. Select Mount
  │    └─ List all mounted Lustre filesystems
  │       User selects which one to benchmark
  │
  ├─ 3. Get Root Directory
  │    └─ User specifies benchmark working directory
  │       Create: logs/, reports/, testdata/ subdirectories
  │
  ├─ 4. Discover Filesystem
  │    └─ Run: lfs df
  │       Count MDTs (Metadata Targets)
  │       Count OSTs (Object Storage Targets)
  │       Get filesystem usage percentage
  │
  ├─ 5. Initialize Report
  │    └─ Create: lustre_report_YYYY-MM-DD_HHMMSS.txt
  │       Write header with filesystem info
  │
  ├─ 6. Sequential Write Test (4 GB)
  │    └─ Run: dd if=/dev/zero of=seq.bin bs=1G count=4
  │       Measure time → Calculate GB/s
  │       Compare against: PASS (≥2 GB/s), WARN (≥0.8), FAIL
  │
  ├─ 7. Sequential Read Test (4 GB)
  │    └─ Run: dd if=seq.bin of=/dev/null bs=1G
  │       Measure time → Calculate GB/s
  │       Compare against same thresholds
  │
  ├─ 8. Random I/O Test (FIO)
  │    └─ Run: fio --rw=randread --bs=4k --iodepth=64 --runtime=15
  │       Extract: IOPS, Bandwidth
  │       Log results (INFO - tracked for trending)
  │
  ├─ 9. Metadata Operations Test
  │    ├─ Create: 1000 files (user-configurable)
  │    │   Measure time → Compare against: PASS (<15s), WARN (<60s), FAIL
  │    └─ Delete: all files
  │        Measure time → Compare against: PASS (<10s), WARN (<30s), FAIL
  │
  ├─ 10. Cleanup
  │     └─ Remove all testdata/ directory and contents
  │
  └─ 11. Report & Exit
       └─ Display report location
           Exit code: 0 (success) or 1 (failure)

═══════════════════════════════════════════════════════════════
```

## Performance Tests Explained

### Test 1: Sequential Write

**Purpose**: Measure throughput for large sequential write operations

**Command**:
```bash
dd if=/dev/zero of=$BENCH_ROOT/testdata/seq.bin \
   bs=1G count=4 oflag=direct status=none
```

**Parameters**:
- `if=/dev/zero` - Input: infinite zeros
- `of=seq.bin` - Output file on Lustre
- `bs=1G` - Block size: 1 GB (large blocks = sequential)
- `count=4` - Transfer 4 blocks = 4 GB total
- `oflag=direct` - Bypass filesystem cache
- `status=none` - Suppress output

**Metric**: Bandwidth (GB/s) = 4 GB / Time

**Thresholds**:
```
Status    Bandwidth    Assessment
─────────────────────────────────
PASS      ≥ 2.0 GB/s   Enterprise-grade performance
WARN      ≥ 0.8 GB/s   Below expectations, investigate
FAIL      < 0.8 GB/s   Poor performance, likely bottleneck
```

**Expected Result**:
```
Sequential Write    2.456 GB/s          >2 GB/s          PASS
```

---

### Test 2: Sequential Read

**Purpose**: Measure throughput for large sequential read operations

**Command**:
```bash
dd if=$BENCH_ROOT/testdata/seq.bin of=/dev/null \
   bs=1G iflag=direct status=none
```

**Parameters**:
- `if=seq.bin` - Input: file created in write test
- `of=/dev/null` - Output: discard data
- `iflag=direct` - Bypass cache during read
- Rest same as write test

**Metric**: Bandwidth (GB/s) = 4 GB / Time

**Thresholds**: Same as write test

**Expected Result**:
```
Sequential Read     3.124 GB/s          >2 GB/s          PASS
```

---

### Test 3: Random I/O (FIO)

**Purpose**: Measure IOPS and throughput for random access patterns (typical for databases, web servers)

**Command**:
```bash
fio --name=randtest \
    --filename=$BENCH_ROOT/testdata/rand.bin \
    --size=4G \
    --rw=randread \
    --bs=4k \
    --iodepth=64 \
    --runtime=15 \
    --time_based \
    --group_reporting
```

**Parameter Details**:

| Parameter | Value | Purpose |
|-----------|-------|---------|
| `--name` | randtest | Test identifier |
| `--filename` | rand.bin | Test file on Lustre |
| `--size` | 4G | Test file size |
| `--rw` | randread | Random read operations |
| `--bs` | 4k | 4 KB block size (small = random) |
| `--iodepth` | 64 | Queue 64 operations simultaneously (stress test) |
| `--runtime` | 15 | Run for 15 seconds |
| `--time_based` | - | Use time as stopping criterion |
| `--group_reporting` | - | Aggregate results |

**Metrics Extracted**:
- **IOPS**: Operations per second (how many 4KB reads/sec)
- **BW**: Bandwidth in MiB/s (throughput)

**Thresholds**:
```
Status  Metric           Value       Assessment
────────────────────────────────────────────────
INFO    Random IOPS      > 3000      Tracked for trending
INFO    Random BW        > 10 MiB/s  Tracked for trending
```

**Expected Result**:
```
Random Read IOPS    5847                >3000           INFO
Random Read BW      45.8 MiB/s          >10 MiB/s       INFO
```

---

### Test 4: Metadata Operations

**Purpose**: Measure filesystem metadata performance (file creation/deletion)

#### Sub-Test 4A: File Creation Performance

**Command**:
```bash
for i in $(seq 1 $FILE_COUNT); do
    dd if=/dev/zero of="$META_DIR/file_$i" \
       bs=1M count=$FILE_SIZE_MB status=none
done
```

**Measures**: Time to create N files

**Default**: 1000 files × 1 MB each = 1000 MB metadata operations

**Metric**: Time (seconds)

**Thresholds**:
```
Status  Time        Assessment
────────────────────────────────
PASS    < 15s       Excellent metadata performance
WARN    < 60s       Below expectations, check MDT
FAIL    ≥ 60s       Poor, likely MDT bottleneck
```

**Expected Result**:
```
Metadata Create     12.456s             <15s             PASS
```

#### Sub-Test 4B: File Deletion Performance

**Command**:
```bash
rm -f "$META_DIR"/*
```

**Measures**: Time to delete all created files

**Metric**: Time (seconds)

**Thresholds**:
```
Status  Time        Assessment
────────────────────────────────
PASS    < 10s       Excellent delete performance
WARN    < 30s       Acceptable but slow
FAIL    ≥ 30s       Poor, investigate MDT health
```

**Expected Result**:
```
Metadata Delete     8.234s              <10s             PASS
```

---

## Output & Reports

### Console Output

```
[INFO] Sequential write...
[INFO] Sequential read...
[INFO] Random IO...
[INFO] Metadata test...
[PASS] Benchmark completed
Report: /mnt/lustre/benchmark/reports/lustre_report_2026-06-29_183642.txt
```

### Report File Location

```
$BENCH_ROOT/reports/lustre_report_YYYY-MM-DD_HHMMSS.txt
```

Example:
```
/mnt/lustre/benchmark/reports/lustre_report_2026-06-29_183642.txt
```

### Report Content

```
====================================================
LUSTRE ENTERPRISE BENCHMARK REPORT V2
====================================================
Timestamp : Mon Jun 29 18:36:42 +0530 2026
Filesystem: /mnt/lustre
MDTs      : 2
OSTs      : 8
Usage     : 45%

TEST                      ACTUAL               EXPECTED           STATUS
--------------------------------------------------------------------------
Sequential Write          2.456 GB/s           >2 GB/s            PASS
Sequential Read           3.124 GB/s           >2 GB/s            PASS
Random Read IOPS          5847                 >3000              INFO
Random Read BW            45.8 MiB/s           >10 MiB/s          INFO
Metadata Create           12.456s              <15s               PASS
Metadata Delete           8.234s               <10s               PASS
```

## Directory Structure

```
$BENCH_ROOT/
├── logs/
│   └── fio.log                              (Random I/O test details)
│
├── reports/
│   ├── lustre_report_2026-06-29_183642.txt  (Benchmark #1)
│   ├── lustre_report_2026-06-29_190215.txt  (Benchmark #2)
│   └── ...
│
└── testdata/                                (Cleaned up after completion)
    ├── seq.bin                              (Sequential test file)
    ├── rand.bin                             (Random I/O test file)
    └── meta/                                (Metadata test files)
        ├── file_1
        ├── file_2
        └── file_1000
```

## Performance Interpretation

### Sequential I/O Benchmarks

| Bandwidth | Performance | Typical Use |
|-----------|-------------|------------|
| > 3 GB/s | Excellent | High-performance cluster computing |
| 2-3 GB/s | Good | Enterprise data center |
| 1-2 GB/s | Fair | Medium-scale deployments |
| 0.5-1 GB/s | Poor | Network bottleneck likely |
| < 0.5 GB/s | Critical | Check connectivity, storage |

### Random IOPS Benchmarks

| IOPS | Performance | Typical Use |
|------|-------------|------------|
| > 10,000 | Excellent | High-frequency trading, real-time analytics |
| 5,000-10,000 | Good | Enterprise databases, web services |
| 3,000-5,000 | Fair | General-purpose computing |
| 1,000-3,000 | Poor | Investigate cache/tuning |
| < 1,000 | Critical | Serious bottleneck exists |

### Metadata Performance Benchmarks

| Operation | Time | Performance | Assessment |
|-----------|------|------------|------------|
| Create 1000 files | < 5s | Excellent | NVMe-backed MDT or high-end hardware |
| Create 1000 files | 5-15s | Good | Typical enterprise MDT |
| Create 1000 files | 15-60s | Fair | Network or MDT cache contention |
| Create 1000 files | > 60s | Poor | MDT bottleneck, check health |
| Delete 1000 files | < 3s | Excellent | Optimized metadata handling |
| Delete 1000 files | 3-10s | Good | Typical performance |
| Delete 1000 files | 10-30s | Fair | Slower than expected |
| Delete 1000 files | > 30s | Poor | Investigate MDT |

## Troubleshooting

### Issue 1: "No Lustre mounts found"

**Cause**: Lustre filesystem not mounted on this system

**Solution**:
```bash
# Check current mounts
mount | grep lustre

# If empty, mount Lustre
mount -t lustre <server>@<network>:/<filesystem> <mountpoint>

# Example:
mount -t lustre server01@tcp:/lustre /mnt/lustre
```

---

### Issue 2: "Tool missing" (e.g., fio)

**Cause**: Required utility not installed

**Solution**:
```bash
# Ubuntu/Debian
sudo apt-get install fio

# RHEL/CentOS
sudo yum install fio

# Or install all prerequisites at once
sudo apt-get install lustre-client-utils fio
```

---

### Issue 3: "Permission denied"

**Cause**: No write permission in benchmark directory

**Solution**:
```bash
# Fix permissions
chmod 755 /mnt/lustre/benchmark

# Or run with appropriate user
sudo ./lustre_enterprise_benchmark_v2.sh
```

---

### Issue 4: Slow Sequential I/O (< 1 GB/s)

**Possible Causes**:
1. **Network bottleneck** → Check network bandwidth with `iftop` or `nethogs`
2. **OST contention** → Check: `lfs df -i` to see OST load
3. **Storage latency** → Monitor OST with `iostat -x 1 5`
4. **Stripe settings** → Check: `lfs getstripe /mnt/lustre/benchmark`

**Investigation Commands**:
```bash
# Check network bandwidth
iftop -n

# Monitor disk I/O
iostat -x 1 5

# Check OST status
lfs df -i

# Check stripe settings
lfs getstripe /mnt/lustre/benchmark/testdata/seq.bin
```

---

### Issue 5: Low Random IOPS (< 3000)

**Possible Causes**:
1. **Insufficient cache** → Increase with `--iodepth` parameter
2. **Stripe count too low** → Use more OSTs
3. **Cache effects** → Run test longer with `--runtime=30`
4. **Storage backend** → Verify OST hardware specs

**Investigation**:
```bash
# Increase queue depth for deeper stress
--iodepth=128

# Run longer test
--runtime=30

# Verify stripe count
lfs getstripe -c /mnt/lustre/benchmark/testdata/rand.bin
```

---

### Issue 6: Slow Metadata Operations (> 60s)

**Possible Causes**:
1. **MDT overload** → Check: `lfs df` for all MDTs
2. **Insufficient cache** → Check MDT memory usage
3. **Network latency** → Check latency: `ping server`
4. **Lock contention** → Check: `lctl get_param mdt.*

**Mitigation**:
```bash
# Reduce test file count for faster diagnosis
echo "500"   # Instead of 1000

# Reduce file size
echo "0.5"   # Instead of 1 MB

# Check MDT health
lfs mdts /mnt/lustre
```

---

### Issue 7: Permission Errors on Cleanup

**Cause**: Test files created by root but cleanup runs as regular user

**Solution**:
```bash
# Ensure consistent user execution
sudo ./lustre_enterprise_benchmark_v2.sh

# Or fix ownership after benchmark
sudo chown -R $USER:$USER /mnt/lustre/benchmark
```

---

## Performance Optimization Tips

### Improve Sequential I/O

```bash
# Increase stripe size (larger = better seq performance)
# Before benchmark, create test dir with optimal stripe:
lfs setstripe -S 4m /mnt/lustre/benchmark/testdata

# Use larger block size in dd
# Modify script: bs=2G (instead of bs=1G)
```

### Improve Random IOPS

```bash
# Increase stripe count (more OSTs = more parallelism)
lfs setstripe -c 8 /mnt/lustre/benchmark/testdata

# Increase queue depth in FIO
# Modify script: --iodepth=128 (instead of 64)

# Use NVMe-backed OSTs if available
```

### Improve Metadata Performance

```bash
# Increase MDT cache (requires filesystem reconfiguration)
# Contact Lustre administrator

# Reduce test file size for quick diagnosis
echo "0.1"   # Smaller files = faster test

# Reduce file count
echo "100"   # Instead of 1000
```

---

## Real-World Usage Scenarios

### Scenario 1: Initial Deployment Validation

```
Goal: Validate newly installed Lustre meets performance targets

Command:
  ./lustre_enterprise_benchmark_v2.sh

Expected Results:
  Sequential Write: > 2.0 GB/s ✓
  Sequential Read:  > 2.0 GB/s ✓
  Random IOPS:      > 5000 ✓
  Metadata Create:  < 15s ✓
  Metadata Delete:  < 10s ✓

Action: Deploy to production when all PASS
```

---

### Scenario 2: Monthly Health Audit

```
Goal: Track performance over time, detect degradation

Command:
  Run benchmark first day of each month

Log Results:
  Month 1: Seq Write 2.456 GB/s
  Month 2: Seq Write 2.412 GB/s (slight degradation)
  Month 3: Seq Write 2.214 GB/s (investigate!)

Investigation:
  Check: OST health, network load, storage capacity
  Action: Maintenance or upgrades if needed
```

---

### Scenario 3: Post-Maintenance Verification

```
Goal: Verify filesystem still performs after updates

Procedure:
  1. Take baseline before maintenance
  2. Apply patches/upgrades
  3. Run benchmark again
  4. Compare results

Acceptable: Within 5% of baseline
Concerning: > 10% degradation
Critical: > 20% degradation
```

---

### Scenario 4: Capacity Planning

```
Goal: Determine if system can handle projected load

Current Performance:
  Random IOPS: 8,500
  Seq Write:   2.8 GB/s

Projected Load:
  Need 12,000 IOPS

Action:
  Add 2-3 more OSTs to increase IOPS capacity
  Rerun benchmark to verify new capacity
```

---

## Automation & Scripting

### Automated Benchmark with Email Report

```bash
#!/bin/bash
BENCHMARK_DIR="/mnt/lustre/benchmark"
REPORT_DIR="$BENCHMARK_DIR/reports"

# Run benchmark
(
  echo "1"                              # Select mount
  echo "$BENCHMARK_DIR"                 # Benchmark path
  echo "1000"                           # File count
  echo "1"                              # File size
) | /path/to/lustre_enterprise_benchmark_v2.sh

# Find latest report
LATEST=$(ls -t $REPORT_DIR/lustre_report_*.txt | head -1)

# Email results
mail -s "Lustre Benchmark Report" admin@example.com < "$LATEST"

echo "Benchmark complete. Report emailed."
```

---

### Scheduled Benchmark (Cron)

```bash
# Add to crontab
crontab -e

# Run every first day of month at 2 AM
0 2 1 * * /usr/local/bin/run_lustre_benchmark.sh

# Run every Monday
0 2 * * 1 /usr/local/bin/run_lustre_benchmark.sh
```

---

### Benchmark Result Trending

```bash
#!/bin/bash
# Extract metrics from all reports

for report in /mnt/lustre/benchmark/reports/lustre_report_*.txt; do
  echo "=== $report ==="
  grep -E "Sequential Write|Sequential Read|Random Read IOPS" "$report"
done
```

---

## Exit Codes

| Code | Meaning | Action |
|------|---------|--------|
| 0 | Benchmark completed successfully | Results available |
| 1 | Benchmark failed (tool missing, etc.) | Check error message |

## Related Scripts

- `data_mig_git.sh` - High-performance data migration script
- `data_mig_git_encypt.sh` - Encrypted data migration variant
- `lustre_script/data_mig.sh` - Alternative migration script

## Best Practices

✅ **Run benchmarks regularly** - Monthly audits help detect degradation
✅ **Baseline before changes** - Document performance before upgrades
✅ **Test after maintenance** - Verify nothing broke during repairs
✅ **Compare within same conditions** - Run benchmarks at similar times
✅ **Monitor trending** - Track metrics over months for insights
✅ **Archive reports** - Keep historical data for analysis
✅ **Adjust thresholds** - Customize for your environment/SLAs
✅ **Share results** - Communicate performance to stakeholders

## Author Notes

- Script designed for enterprise Lustre deployments
- Thresholds based on industry-standard performance expectations
- Can be integrated into monitoring and alerting systems
- Results timestamped for easy tracking and trending
- Self-contained with automatic cleanup to avoid disk issues

## Support & Debugging

### Enable Verbose Mode
```bash
# Modify script to add debugging
set -x                    # Print each command
./lustre_enterprise_benchmark_v2.sh
```

### Manual Component Testing

```bash
# Test sequential I/O manually
dd if=/dev/zero of=/mnt/lustre/test.bin bs=1G count=4 oflag=direct

# Test random I/O manually
fio --name=test --filename=/mnt/lustre/test.bin --size=4G \
    --rw=randread --bs=4k --iodepth=64 --runtime=15

# Check filesystem info
lfs df
lfs mdts /mnt/lustre
lfs osts /mnt/lustre
```

## License & Attribution

Part of HPE HPC Lustre Utilities Suite
