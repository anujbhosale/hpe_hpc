#!/bin/bash

set -o pipefail

REPO="git@github.com:anujbhosale/lustre_migration.git"
SOURCE="/hpcdata/projects/datamigration/old_lustre"
DEST="/hpcdata/projects/datamigration/new_lustre"
PARALLEL=50

TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
WORKDIR=$(mktemp -d /tmp/lustre_migration_${TIMESTAMP}_XXXX)
LAUNCH_LOG="/tmp/lustre_launcher_${TIMESTAMP}.log"

CHILD_PID=""

exec > >(tee -a "$LAUNCH_LOG") 2>&1

cleanup() {
    echo ""
    echo "Cleaning temporary files..."

    if [[ -n "$CHILD_PID" ]]; then
        echo "Stopping migration process tree..."
        kill -TERM -- -"$CHILD_PID" 2>/dev/null || true
        sleep 2
        kill -KILL -- -"$CHILD_PID" 2>/dev/null || true
    fi

    if [[ -d "$WORKDIR" ]]; then
        rm -rf "$WORKDIR"
        echo "Deleted cloned repo: $WORKDIR"
    fi

    echo "Wrapper log saved at: $LAUNCH_LOG"
}

interrupt_handler() {
    echo ""
    echo "Interrupt received (Ctrl+C / SIGTERM)"
    cleanup
    exit 130
}

trap cleanup EXIT
trap interrupt_handler INT TERM

echo "=================================================="
echo "LUSTRE MIGRATION WRAPPER STARTED"
echo "Time        : $(date)"
echo "Repo        : $REPO"
echo "Source      : $SOURCE"
echo "Destination : $DEST"
echo "Parallel    : $PARALLEL"
echo "Workdir     : $WORKDIR"
echo "LauncherLog : $LAUNCH_LOG"
echo "=================================================="

echo "Cloning repository..."
git clone "$REPO" "$WORKDIR" || exit 1

SCRIPT=$(find "$WORKDIR" -name "data_mig_git_encypt.sh" | head -1)

if [[ -z "$SCRIPT" ]]; then
    echo "ERROR: data_mig.sh not found"
    exit 1
fi

chmod +x "$SCRIPT"

echo "Starting migration..."
setsid "$SCRIPT" "$SOURCE" "$DEST" "$PARALLEL" &
CHILD_PID=$!

wait "$CHILD_PID"
RET=$?

echo ""
echo "Migration exited with code: $RET"

if [[ $RET -eq 0 ]]; then
    echo "Migration completed successfully"
else
    echo "Migration failed"
fi

exit $RET
