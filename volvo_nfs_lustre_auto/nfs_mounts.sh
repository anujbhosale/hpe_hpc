#!/usr/bin/env bash

set -euo pipefail

if [[ "${EUID}" -ne 0 ]]; then
	echo "This script must be run as root."
	exit 1
fi

SYSTEMD_DIR="/etc/systemd/system"

log() {
	echo "[INFO] $*"
}

fail() {
	echo "[ERROR] $*" >&2
	exit 1
}

is_package_installed() {
	local pkg="$1"

	if command -v rpm >/dev/null 2>&1; then
		rpm -q "${pkg}" >/dev/null 2>&1
		return $?
	fi

	if command -v dpkg-query >/dev/null 2>&1; then
		dpkg-query -W -f='${Status}' "${pkg}" 2>/dev/null | grep -q "install ok installed"
		return $?
	fi

	return 2
}

verify_nfs_packages() {
	if command -v rpm >/dev/null 2>&1; then
		if is_package_installed "nfs-utils"; then
			log "Package nfs-utils is installed."
		else
			fail "Package nfs-utils is not installed. Install it with: yum install -y nfs-utils (or dnf install -y nfs-utils)."
		fi
	else
		fail "rpm is not available. This script currently supports only RPM-based systems with nfs-utils."
	fi
}

create_mount_dir() {
	local mount_dir="$1"

	if [[ -d "${mount_dir}" ]]; then
		log "Directory ${mount_dir} already exists."
	else
		log "Creating directory ${mount_dir}."
		mkdir -p "${mount_dir}"
	fi

	if [[ ! -d "${mount_dir}" ]]; then
		fail "Directory ${mount_dir} was not created."
	fi

	log "Verified directory ${mount_dir} exists."
}

create_mount_unit() {
	local unit_name="$1"
	local description="$2"
	local what="$3"
	local where="$4"
	local fs_type="$5"
	local options="$6"
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

[Install]
WantedBy=multi-user.target
EOF

	if [[ ! -f "${unit_path}" ]]; then
		fail "Failed to create ${unit_path}."
	fi

	log "Created ${unit_path}."
}

enable_and_start_mount() {
	local unit_name="$1"

	systemctl daemon-reload
	systemctl enable --now "${unit_name}"

	if ! systemctl is-active --quiet "${unit_name}"; then
		fail "${unit_name} is not active."
	fi

	log "${unit_name} is enabled and active."
}

verify_mount() {
	local mount_dir="$1"

	if mountpoint -q "${mount_dir}"; then
		log "${mount_dir} is mounted."
	else
		fail "${mount_dir} is not mounted."
	fi
}

main() {
	log "Verifying required NFS client packages."
	verify_nfs_packages

	log "Preparing mount directories."
	create_mount_dir "/home"
	create_mount_dir "/shared"

	log "Creating systemd mount unit files."
	create_mount_unit \
		"home.mount" \
		"NFS /home filesystem" \
		"FZ2BVIP1.mpfile2.int.oden2.com:/ODEN2Shares/Home" \
		"/home" \
		"nfs" \
		"_netdev,sec=sys,vers=4.2,noresvport,context=system_u:object_r:ssh_home_t:s0"

	create_mount_unit \
		"shared.mount" \
		"NFS /shared filesystem" \
		"FZ2AVIP1.mpfile1.int.oden2.com:/ODEN2Shares/Shared" \
		"/shared" \
		"nfs" \
		"_netdev,sec=sys,vers=4.2,noresvport"

	log "Enabling and starting mount units."
	enable_and_start_mount "home.mount"
	enable_and_start_mount "shared.mount"

	log "Verifying mounted filesystems."
	verify_mount "/home"
	verify_mount "/shared"

	log "NFS mount setup completed successfully."
}

main
