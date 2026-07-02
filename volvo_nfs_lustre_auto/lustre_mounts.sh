#!/usr/bin/env bash

set -euo pipefail

if [[ "${EUID}" -ne 0 ]]; then
	echo "This script must be run as root."
	exit 1
fi

SYSTEMD_DIR="/etc/systemd/system"
LNET_CONF_DIR="/etc/modprobe.d"
LNET_CONF_PATH="${LNET_CONF_DIR}/lnet.conf"

log() {
	echo "[INFO] $*"
}

fail() {
	echo "[ERROR] $*" >&2
	exit 1
}

create_mount_unit() {
	local unit_name="$1"
	local description="$2"
	local what="$3"
	local where="$4"
	local fs_type="$5"
	local options="$6"
	local timeout_sec="$7"
	local unit_path="${SYSTEMD_DIR}/${unit_name}"

	cat > "${unit_path}" <<EOF
[Unit]
Description=${description}
Before=remote-fs.target

[Mount]
What=${what}
Where=${where}
Type=${fs_type}
Options=${options}
TimeoutSec=${timeout_sec}

[Install]
WantedBy=multi-user.target
EOF

	if [[ ! -f "${unit_path}" ]]; then
		fail "Failed to create ${unit_path}."
	fi

	log "Created ${unit_path}."
}

create_lnet_conf() {
	cat > "${LNET_CONF_PATH}" <<EOF
options lnet networks=o2ib20(ibs6)
EOF

	if [[ ! -f "${LNET_CONF_PATH}" ]]; then
		fail "Failed to create ${LNET_CONF_PATH}."
	fi

	log "Created ${LNET_CONF_PATH}."
}

enable_mount_unit() {
	local unit_name="$1"

	systemctl enable "${unit_name}"
	log "Enabled ${unit_name}."
}

main() {
	log "Creating LNet modprobe configuration."
	create_lnet_conf

	log "Reloading Lustre kernel modules."
	lustre_rmmod || fail "Failed to run lustre_rmmod."
	modprobe lustre || fail "Failed to run modprobe lustre."

	log "Creating systemd mount unit files."
	create_mount_unit \
		"bfz22.mount" \
		"Lustre fz22b File System - Backup of fz21p" \
		"10.72.161.217@o2ib20,10.72.161.218@o2ib20:10.72.161.219@o2ib20,10.72.161.220@o2ib20:/fz22b" \
		"/bfz22" \
		"lustre" \
		"rw,nosuid,user_xattr,nofail" \
		"90"

	create_mount_unit \
		"boutput_hub.mount" \
		"Lustre File System boutput_hub" \
		"10.72.161.77@o2ib20,10.72.161.78@o2ib20:10.72.161.79@o2ib20,10.72.161.80@o2ib20:/fz2bw" \
		"/boutput_hub" \
		"lustre" \
		"rw,nosuid,user_xattr" \
		"90"

	create_mount_unit \
		"fz21.mount" \
		"Lustre File System" \
		"10.72.162.98@o2ib20,10.72.162.99@o2ib20:10.72.162.100@o2ib20,10.72.162.101@o2ib20:/fz21p" \
		"/fz21" \
		"lustre" \
		"rw,nosuid,user_xattr" \
		"90"

	create_mount_unit \
		"fz24.mount" \
		"Lustre File System" \
		"10.72.162.190@o2ib20,10.72.162.191@o2ib20:10.72.162.192@o2ib20,10.72.162.193@o2ib20:/fz24p" \
		"/fz24" \
		"lustre" \
		"rw,nosuid,user_xattr" \
		"90"

	create_mount_unit \
		"output_hub.mount" \
		"Lustre File System" \
		"10.72.161.5@o2ib20,10.72.161.6@o2ib20:10.72.161.7@o2ib20,10.72.161.8@o2ib20:/fz2aw" \
		"/output_hub" \
		"lustre" \
		"rw,nosuid,user_xattr" \
		"90"

	log "Reloading systemd daemon."
	systemctl daemon-reload

	log "Enabling Lustre mount units."
	enable_mount_unit "bfz22.mount"
	enable_mount_unit "boutput_hub.mount"
	enable_mount_unit "fz21.mount"
	enable_mount_unit "fz24.mount"
	enable_mount_unit "output_hub.mount"

	log "Systemd mount unit files created and enabled successfully."
}

main
