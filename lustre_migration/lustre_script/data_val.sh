#!/bin/bash

###############################################################################
# HPC Migration Validation Script (Checksum + Size + Count)
###############################################################################

set -e

# -----------------------------------------------------------------------------
# Defaults
# -----------------------------------------------------------------------------
DEFAULT_SOURCE="/hpcdata/projects/datamigration/old_lustre"
DEFAULT_DEST="/hpcdata/projects/datamigration/new_lustre"

# -----------------------------------------------------------------------------
# Input
# -----------------------------------------------------------------------------
read -rp "Enter Source Directory [${DEFAULT_SOURCE}] : " SOURCE
SOURCE=${SOURCE:-$DEFAULT_SOURCE}

read -rp "Enter Destination Directory [${DEFAULT_DEST}] : " DEST
DEST=${DEST:-$DEFAULT_DEST}

# -----------------------------------------------------------------------------
# Validation
# -----------------------------------------------------------------------------
if [[ ! -d "$SOURCE" || ! -d "$DEST" ]]; then
    echo "ERROR: Invalid source or destination"
    exit 1
fi

# -----------------------------------------------------------------------------
# Log file
# -----------------------------------------------------------------------------
LOGFILE="/tmp/validation_checksum_$(date +%Y%m%d_%H%M%S).log"

echo "==================================================" | tee -a "$LOGFILE"
echo "CHECKSUM VALIDATION STARTED" | tee -a "$LOGFILE"
echo "Source      : $SOURCE" | tee -a "$LOGFILE"
echo "Destination : $DEST" | tee -a "$LOGFILE"
echo "==================================================" | tee -a "$LOGFILE"

# -----------------------------------------------------------------------------
# Temp files
# -----------------------------------------------------------------------------
SRC_HASH="/tmp/src_hash_$$.txt"
DST_HASH="/tmp/dst_hash_$$.txt"

# -----------------------------------------------------------------------------
# Generate source checksums
# -----------------------------------------------------------------------------
echo "Generating source checksums..." | tee -a "$LOGFILE"

find "$SOURCE" -type f -print0 | while IFS= read -r -d '' file; do
    sha256sum "$file"
done | sed "s|$SOURCE/||g" | sort > "$SRC_HASH"

# -----------------------------------------------------------------------------
# Generate destination checksums
# -----------------------------------------------------------------------------
echo "Generating destination checksums..." | tee -a "$LOGFILE"

find "$DEST" -type f -print0 | while IFS= read -r -d '' file; do
    sha256sum "$file"
done | sed "s|$DEST/||g" | sort > "$DST_HASH"

# -----------------------------------------------------------------------------
# Compare
# -----------------------------------------------------------------------------
echo "Comparing checksums..." | tee -a "$LOGFILE"

MISSING_IN_DEST=$(comm -23 <(cut -d' ' -f3 "$SRC_HASH") <(cut -d' ' -f3 "$DST_HASH"))
MISSING_IN_SRC=$(comm -13 <(cut -d' ' -f3 "$SRC_HASH") <(cut -d' ' -f3 "$DST_HASH"))

# -----------------------------------------------------------------------------
# Result
# -----------------------------------------------------------------------------
echo "==================================================" | tee -a "$LOGFILE"

if [[ -z "$MISSING_IN_DEST" && -z "$MISSING_IN_SRC" ]]; then
    echo "STATUS: CHECKSUM VALIDATION SUCCESS ✔" | tee -a "$LOGFILE"
else
    echo "STATUS: CHECKSUM VALIDATION FAILED ❌" | tee -a "$LOGFILE"

    echo "" | tee -a "$LOGFILE"

    if [[ -n "$MISSING_IN_DEST" ]]; then
        echo "Missing in Destination:" | tee -a "$LOGFILE"
        echo "$MISSING_IN_DEST" | tee -a "$LOGFILE"
    fi

    if [[ -n "$MISSING_IN_SRC" ]]; then
        echo "Extra in Destination:" | tee -a "$LOGFILE"
        echo "$MISSING_IN_SRC" | tee -a "$LOGFILE"
    fi
fi

# -----------------------------------------------------------------------------
# Cleanup
# -----------------------------------------------------------------------------
rm -f "$SRC_HASH" "$DST_HASH"

echo "==================================================" | tee -a "$LOGFILE"
echo "Log File: $LOGFILE"
