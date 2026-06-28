#!/usr/bin/env bash
set -euo pipefail

SEQ_SIZE_GB=4
RAND_SIZE_GB=4

RED="\033[0;31m"
GREEN="\033[0;32m"
YELLOW="\033[1;33m"
BLUE="\033[0;34m"
NC="\033[0m"

pass(){ echo -e "${GREEN}[PASS]${NC} $1"; }
warn(){ echo -e "${YELLOW}[WARN]${NC} $1"; }
fail(){ echo -e "${RED}[FAIL]${NC} $1"; exit 1; }
info(){ echo -e "${BLUE}[INFO]${NC} $1"; }

REPORT=""
BENCH_ROOT=""
TARGET_MOUNT=""
OST_COUNT=0
MDT_COUNT=0
FS_USAGE=0
FILE_COUNT=1000
FILE_SIZE_MB=1

report_line() {
    printf "%-25s %-20s %-20s %-10s\n" "$1" "$2" "$3" "$4" >> "$REPORT"
}

status_time() {
    local val=$1
    local pass_t=$2
    local warn_t=$3

    awk -v v="$val" -v p="$pass_t" -v w="$warn_t" '
    BEGIN{
      if(v<=p) print "PASS";
      else if(v<=w) print "WARN";
      else print "FAIL";
    }'
}

status_bw() {
    local val=$1
    local pass_t=$2
    local warn_t=$3

    awk -v v="$val" -v p="$pass_t" -v w="$warn_t" '
    BEGIN{
      if(v>=p) print "PASS";
      else if(v>=w) print "WARN";
      else print "FAIL";
    }'
}

check_tools() {
    for cmd in lfs fio dd awk grep sed find stat mv rm df date; do
        command -v "$cmd" >/dev/null || fail "$cmd missing"
    done
}

select_mount() {
    mapfile -t MOUNTS < <(mount | grep lustre | awk '{print $3}')
    [[ ${#MOUNTS[@]} -eq 0 ]] && fail "No Lustre mounts found"

    echo "Available Lustre mounts:"
    i=1
    for m in "${MOUNTS[@]}"; do
        echo "$i) $m"
        ((i++))
    done

    read -rp "Select mount: " choice
    TARGET_MOUNT=${MOUNTS[$((choice-1))]}
    pass "Selected mount: $TARGET_MOUNT"
}

get_root() {
    read -rp "Enter benchmark folder inside mount: " BENCH_ROOT
    mkdir -p "$BENCH_ROOT"/{logs,reports,testdata}
}

discover_fs() {
    info "Discovering filesystem..."
    MDT_COUNT=$(lfs df | grep "$TARGET_MOUNT\[MDT" | wc -l || true)
    OST_COUNT=$(lfs df | grep "$TARGET_MOUNT\[OST" | wc -l || true)
    FS_USAGE=$(lfs df | grep filesystem_summary | grep "$TARGET_MOUNT" | awk '{print $5}' | tr -d '%')
    [[ -z "$FS_USAGE" ]] && FS_USAGE=0

    pass "MDTs: $MDT_COUNT"
    pass "OSTs: $OST_COUNT"
    pass "Usage: ${FS_USAGE}%"
}

init_report() {
    REPORT="$BENCH_ROOT/reports/lustre_report_$(date +%F_%H%M%S).txt"

    {
        echo "===================================================="
        echo "LUSTRE ENTERPRISE BENCHMARK REPORT V2"
        echo "===================================================="
        echo "Timestamp : $(date)"
        echo "Filesystem: $TARGET_MOUNT"
        echo "MDTs      : $MDT_COUNT"
        echo "OSTs      : $OST_COUNT"
        echo "Usage     : ${FS_USAGE}%"
        echo
        printf "%-25s %-20s %-20s %-10s\n" "TEST" "ACTUAL" "EXPECTED" "STATUS"
        echo "--------------------------------------------------------------------------"
    } > "$REPORT"
}

seq_write_test() {
    info "Sequential write..."
    START=$(date +%s.%N)
    dd if=/dev/zero of="$BENCH_ROOT/testdata/seq.bin" bs=1G count=$SEQ_SIZE_GB oflag=direct status=none
    END=$(date +%s.%N)

    TIME=$(awk "BEGIN{print $END-$START}")
    BW=$(awk "BEGIN{print $SEQ_SIZE_GB/$TIME}")
    STATUS=$(status_bw "$BW" 2.0 0.8)

    report_line "Sequential Write" "${BW} GB/s" ">2 GB/s" "$STATUS"
}

seq_read_test() {
    info "Sequential read..."
    START=$(date +%s.%N)
    dd if="$BENCH_ROOT/testdata/seq.bin" of=/dev/null bs=1G iflag=direct status=none
    END=$(date +%s.%N)

    TIME=$(awk "BEGIN{print $END-$START}")
    BW=$(awk "BEGIN{print $SEQ_SIZE_GB/$TIME}")
    STATUS=$(status_bw "$BW" 2.0 0.8)

    report_line "Sequential Read" "${BW} GB/s" ">2 GB/s" "$STATUS"
}

random_io_test() {
    info "Random IO..."

    fio --name=randtest \
        --filename="$BENCH_ROOT/testdata/rand.bin" \
        --size=${RAND_SIZE_GB}G \
        --rw=randread \
        --bs=4k \
        --iodepth=64 \
        --runtime=15 \
        --time_based \
        --group_reporting > "$BENCH_ROOT/logs/fio.log" 2>&1

    IOPS=$(grep IOPS "$BENCH_ROOT/logs/fio.log" | head -1 | sed 's/.*IOPS=\([^,]*\).*/\1/')
    BW=$(grep IOPS "$BENCH_ROOT/logs/fio.log" | head -1 | sed 's/.*BW=\([^ ]*\).*/\1/')

    report_line "Random Read IOPS" "$IOPS" ">3000" "INFO"
    report_line "Random Read BW" "$BW" ">10 MiB/s" "INFO"
}

metadata_test() {
    info "Metadata test..."
    META_DIR="$BENCH_ROOT/testdata/meta"
    mkdir -p "$META_DIR"

    read -rp "How many files to create? [$FILE_COUNT]: " input || true
    [[ -n "${input:-}" ]] && FILE_COUNT=$input

    read -rp "Size of each file in MB? [$FILE_SIZE_MB]: " input2 || true
    [[ -n "${input2:-}" ]] && FILE_SIZE_MB=$input2

    START=$(date +%s.%N)
    for i in $(seq 1 $FILE_COUNT); do
        dd if=/dev/zero of="$META_DIR/file_$i" bs=1M count=$FILE_SIZE_MB status=none
    done
    END=$(date +%s.%N)
    CREATE=$(awk "BEGIN{print $END-$START}")

    START=$(date +%s.%N)
    rm -f "$META_DIR"/*
    END=$(date +%s.%N)
    DELETE=$(awk "BEGIN{print $END-$START}")

    STATUS_CREATE=$(status_time "$CREATE" 15 60)
    STATUS_DELETE=$(status_time "$DELETE" 10 30)

    report_line "Metadata Create" "${CREATE}s" "<15s" "$STATUS_CREATE"
    report_line "Metadata Delete" "${DELETE}s" "<10s" "$STATUS_DELETE"
}

cleanup() {
    rm -rf "$BENCH_ROOT/testdata"
}

main() {
    check_tools
    select_mount
    get_root
    discover_fs
    init_report
    seq_write_test
    seq_read_test
    random_io_test
    metadata_test
    cleanup

    echo
    pass "Benchmark completed"
    echo "Report: $REPORT"
}

main