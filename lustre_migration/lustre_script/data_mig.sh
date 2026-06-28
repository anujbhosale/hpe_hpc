#!/bin/bash

###############################################################################
# HPC Data Migration Script V3
# - No xargs
# - Proper worker pool
# - Clean Ctrl+C handling
# - Accurate transfer size via df
###############################################################################

set -o pipefail

DEFAULT_SOURCE="/hpcdata/projects/datamigration/old_lustre"
DEFAULT_DEST="/hpcdata/projects/datamigration/new_lustre"

PASSWORD_HASH="10006b9c0bee18a4315de2423b7abe6543b482107ec0c29e982158032379f68d"

###############################################################################
# Password Authentication
###############################################################################
for attempt in {1..3}; do
    read -rsp "Enter password: " PASSWORD
    echo

    INPUT_HASH=$(printf "%s" "$PASSWORD" | sha256sum | awk '{print $1}')

    if [[ "$INPUT_HASH" == "$PASSWORD_HASH" ]]; then
        echo "Authentication successful."
        break
    fi

    echo "Incorrect password ($attempt/3)"
    [[ $attempt -eq 3 ]] && exit 1
done

echo

###############################################################################
# Inputs
###############################################################################
read -rp "Enter Source Directory [${DEFAULT_SOURCE}] : " SOURCE
SOURCE=${SOURCE:-$DEFAULT_SOURCE}

read -rp "Enter Destination Directory [${DEFAULT_DEST}] : " DEST
DEST=${DEST:-$DEFAULT_DEST}

read -rp "Enter Number of Parallel Jobs [10] : " PARALLEL_JOBS
PARALLEL_JOBS=${PARALLEL_JOBS:-10}

if [[ ! -d "$SOURCE" ]]; then
    echo "ERROR: Source directory does not exist"
    exit 1
fi

mkdir -p "$DEST"

rm -rf "$DEST/.rsync-partial" 2>/dev/null

find "$DEST" \
  -type f \
  -regex '.*\.[A-Za-z0-9]\{6\}$' \
  -delete 2>/dev/null

###############################################################################
# Logging
###############################################################################
TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
LOGFILE="/tmp/migration_${TIMESTAMP}.log"

START_TIME=$(date +%s)
INTERRUPTED=0
PIDS=()

INITIAL_USED=$(df -B1 "$DEST" | awk 'NR==2 {print $3}')
INITIAL_USED=${INITIAL_USED:-0}

echo "==================================================" | tee -a "$LOGFILE"
echo "DATA MIGRATION STARTED" | tee -a "$LOGFILE"
echo "Start Time   : $(date)" | tee -a "$LOGFILE"
echo "Source       : $SOURCE" | tee -a "$LOGFILE"
echo "Destination  : $DEST" | tee -a "$LOGFILE"
echo "Parallel Jobs: $PARALLEL_JOBS" | tee -a "$LOGFILE"
echo "Log File     : $LOGFILE" | tee -a "$LOGFILE"
echo "==================================================" | tee -a "$LOGFILE"

###############################################################################
# Helpers
###############################################################################
format_size() {
    local bytes=$1
    awk -v b="$bytes" '
    BEGIN {
        mb=b/1024/1024
        gb=b/1024/1024/1024
        tb=b/1024/1024/1024/1024
        if (tb>=1) printf "%.2f TB", tb
        else if (gb>=1) printf "%.2f GB", gb
        else printf "%.2f MB", mb
    }'
}

cleanup() {
    END_TIME=$(date +%s)
    DURATION=$((END_TIME - START_TIME))
    [[ $DURATION -le 0 ]] && DURATION=1

    FINAL_USED=$(df -B1 "$DEST" | awk 'NR==2 {print $3}')
    FINAL_USED=${FINAL_USED:-0}

    TOTAL_BYTES=$((FINAL_USED - INITIAL_USED))
    [[ $TOTAL_BYTES -lt 0 ]] && TOTAL_BYTES=0

    TOTAL_SIZE=$(format_size "$TOTAL_BYTES")
    SPEED_MBPS=$(awk "BEGIN {printf \"%.2f\", $TOTAL_BYTES/$DURATION/1024/1024}")

    echo "==================================================" | tee -a "$LOGFILE"

    if [[ $INTERRUPTED -eq 1 ]]; then
        echo "MIGRATION INTERRUPTED (Ctrl+C detected)" | tee -a "$LOGFILE"
    else
        echo "MIGRATION COMPLETED" | tee -a "$LOGFILE"
    fi

    echo "End Time            : $(date)" | tee -a "$LOGFILE"
    echo "Total Duration      : $DURATION seconds" | tee -a "$LOGFILE"
    echo "Total Data Transfer : $TOTAL_SIZE" | tee -a "$LOGFILE"
    echo "Average Speed       : $SPEED_MBPS MB/s" | tee -a "$LOGFILE"
    echo "Log File            : $LOGFILE" | tee -a "$LOGFILE"
    echo "==================================================" | tee -a "$LOGFILE"

    echo
    echo "Log saved at: $LOGFILE"
}

stop_all() {
    echo
    echo "Interrupt detected. Stopping all rsync jobs..." | tee -a "$LOGFILE"

    for pid in "${PIDS[@]}"; do
        kill -TERM "$pid" 2>/dev/null
    done

    pkill -9 rsync 2>/dev/null
    wait 2>/dev/null
}

trap cleanup EXIT
trap 'INTERRUPTED=1; stop_all; exit 130' INT TERM

###############################################################################
# Copy function
###############################################################################
copy_item() {
    ITEM="$1"
    NAME=$(basename "$ITEM")

    echo "START: $NAME" >> "$LOGFILE"

    for retry in 1 2 3; do
	rsync -aHAX \
    	    --delete \
    	    --numeric-ids \
   	    --info=progress2 \
    	    --stats \
    	    "$ITEM"/ "$DEST/$(basename "$ITEM")"/ >> "$LOGFILE" 2>&1
        STATUS=$?

        if [[ $STATUS -eq 0 ]]; then
            echo "SUCCESS: $NAME" >> "$LOGFILE"
            return 0
        fi

        echo "FAILED: $NAME attempt $retry" >> "$LOGFILE"
        [[ $retry -lt 3 ]] && sleep 2
    done

    echo "ERROR: $NAME failed after 3 attempts" >> "$LOGFILE"
    return 1
}

###############################################################################
# Worker Pool
###############################################################################
echo "Building file list..." | tee -a "$LOGFILE"

mapfile -t ITEMS < <(find "$SOURCE" -mindepth 1 -maxdepth 1)

TOTAL_ITEMS=${#ITEMS[@]}
echo "Total items found: $TOTAL_ITEMS" | tee -a "$LOGFILE"

echo "Migration started..." | tee -a "$LOGFILE"

ACTIVE=0

for item in "${ITEMS[@]}"; do
    copy_item "$item" &
    pid=$!
    PIDS+=("$pid")
    ((ACTIVE++))

    while [[ $ACTIVE -ge $PARALLEL_JOBS ]]; do
        wait -n
        ((ACTIVE--))
    done
done

wait
