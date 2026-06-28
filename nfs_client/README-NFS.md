# NFS Client Installation and Configuration with Ansible

This playbook automates the installation and configuration of NFS client on Linux machines and mounts NFS shares from a remote host.

Current environment:

- NFS server: `10.25.67.100` (`gccvmesxnfs-store`)
- NFS client: `10.25.67.180`
- Mounted exports:
  - `10.25.67.100:/home` -> `/home`
  - `10.25.67.100:/hpcdata` -> `/hpcdata`

## Prerequisites

- Ansible installed on control machine
- `ansible.posix` collection installed for the mount module
- SSH access to target machines
- NFS server already set up and exporting shares
- Sudo/root privileges on target machines

## Files

- `nfs-client-setup.yml` - Main Ansible playbook
- `nfs-client-setup-advanced.yml` - Advanced playbook with reachability checks and retry handling
- `inventory.ini` - Inventory file with target hosts
- `nfs_client_vars.yml` - Variables file with configuration options
- `requirements.yml` - Ansible collection requirements

## Quick Start

### 1. Update Inventory

The inventory is already configured for the NFS client host `10.25.67.180`:

```ini
[nfs_clients]
nfs-client ansible_host=10.25.67.180 ansible_user=root

[nfs_clients:vars]
nfs_server_host=10.25.67.100
nfs_mounts='[{"export_path":"/home","mount_point":"/home"},{"export_path":"/hpcdata","mount_point":"/hpcdata"}]'
nfs_mount_options=rw,sync,hard,intr,vers=4
```

### 2. Configure Variables

`nfs_client_vars.yml` contains the default NFS configuration:

```yaml
nfs_server_host: "10.25.67.100"
nfs_mounts:
  - export_path: "/home"
    mount_point: "/home"
  - export_path: "/hpcdata"
    mount_point: "/hpcdata"
nfs_mount_options: "rw,sync,hard,intr,vers=4"
```

Edit this file to customize:

- NFS server IP/hostname
- Export paths on NFS server
- Local mount points
- Mount options (rw/ro, sync/async, etc.)

### 3. Install Required Ansible Collection

The playbooks use `ansible.posix.mount`, so install the collection before running them:

```bash
ansible-galaxy collection install -r requirements.yml
```

### 4. Run the Playbook

```bash
# Using inventory file
ansible-playbook -i inventory.ini nfs-client-setup.yml

# Using the advanced playbook
ansible-playbook -i inventory.ini nfs-client-setup-advanced.yml

# Using variable overrides
ansible-playbook -i inventory.ini nfs-client-setup.yml \
  -e "nfs_server_host=10.25.67.100" \
  -e 'nfs_mounts=[{"export_path":"/hpcdata","mount_point":"/hpcdata"}]'

# With verbose output
ansible-playbook -i inventory.ini nfs-client-setup.yml -v

# For specific hosts
ansible-playbook -i inventory.ini nfs-client-setup.yml -l nfs-client
```

## What the Playbook Does

1. **Updates package cache** for Debian/Ubuntu systems
2. **Installs NFS client packages**:
   - `nfs-common` for Debian/Ubuntu
   - `nfs-utils` for RedHat/CentOS/Fedora
3. **Starts and enables** rpcbind service
4. **Creates mount point** directories with proper permissions
5. **Mounts NFS shares** to the specified mount points
6. **Verifies the mounts** and displays mount information

## Supported Linux Distributions

- Ubuntu/Debian (apt-based)
- CentOS/RedHat/Fedora (yum/dnf-based)

## Mount Options Explained

Common NFS mount options:

| Option | Description |
|--------|-------------|
| rw | Read-write (default) |
| ro | Read-only |
| sync | Synchronous I/O (safer) |
| async | Asynchronous I/O (faster) |
| hard | Hard mount (retry indefinitely) |
| soft | Soft mount (limited retries) |
| intr | Allow interruption of NFS calls |
| nolock | Disable file locking |
| vers=3 | Use NFS version 3 |
| vers=4 | Use NFS version 4 |

## Example: Different Configurations

### Read-only, High Performance
```bash
ansible-playbook -i inventory.ini nfs-client-setup.yml \
  -e "nfs_mount_options=ro,async,nolock"
```

### Production, High Reliability
```bash
ansible-playbook -i inventory.ini nfs-client-setup.yml \
  -e "nfs_mount_options=rw,sync,hard,intr,vers=4"
```

## Troubleshooting

### Mount fails with "Connection refused"
- Check NFS server is running and exporting the path
- Verify firewall rules allow NFS traffic (ports 111, 2049)
- Confirm network connectivity: `ping <nfs_server_host>`

### Permission denied on mounted share
- Check NFS export permissions on server
- Verify user/group IDs match between client and server
- Check mount options (rw vs ro)

### Verify NFS mount on client
```bash
# Check mount status
df -Th /home /hpcdata

# List mounted shares
mount | grep nfs

# Test file operations
touch /hpcdata/ansible_nfs_test.txt
```

## Permanent Mount

The playbook uses `state: mounted` which mounts the shares and adds them to `/etc/fstab`, making them permanent across reboots.

## Unmount NFS Share (Manual)

```bash
ansible-playbook -i inventory.ini nfs-client-setup.yml \
  -e "mount_state=absent"
```

Or manually on each client:
```bash
umount /home
umount /hpcdata
```

## References

- [Ansible mount module](https://docs.ansible.com/ansible/latest/collections/ansible/posix/mount_module.html)
- [NFS Documentation](https://linux.die.net/man/5/nfs)
- [NFS Server Setup Guide](https://ubuntu.com/server/docs/service-nfs)
