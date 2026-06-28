# NFS Client Installation and Configuration with Ansible

This playbook automates the installation and configuration of NFS client on Linux machines and mounts NFS shares from a remote host.

## Prerequisites

- Ansible installed on control machine
- SSH access to target machines
- NFS server already set up and exporting shares
- Sudo/root privileges on target machines

## Files

- `nfs-client-setup.yml` - Main Ansible playbook
- `inventory.ini` - Inventory file with target hosts
- `nfs_client_vars.yml` - Variables file with configuration options

## Quick Start

### 1. Update Inventory

Edit `inventory.ini` and add your NFS client hosts and NFS server details:

```ini
[nfs_clients]
client1 ansible_host=192.168.1.10 ansible_user=ubuntu
client2 ansible_host=192.168.1.11 ansible_user=ubuntu

[nfs_clients:vars]
nfs_server_host=192.168.1.100
nfs_export_path=/export/data
nfs_mount_point=/mnt/nfs
```

### 2. Configure Variables

Edit `nfs_client_vars.yml` to customize:
- NFS server IP/hostname
- Export path on NFS server
- Local mount point
- Mount options (rw/ro, sync/async, etc.)

### 3. Run the Playbook

```bash
# Using inventory file
ansible-playbook -i inventory.ini nfs-client-setup.yml

# Using variable overrides
ansible-playbook -i inventory.ini nfs-client-setup.yml \
  -e "nfs_server_host=192.168.1.200" \
  -e "nfs_mount_point=/mnt/nfs_data"

# With verbose output
ansible-playbook -i inventory.ini nfs-client-setup.yml -v

# For specific hosts
ansible-playbook -i inventory.ini nfs-client-setup.yml -l client1
```

## What the Playbook Does

1. **Updates package cache** for Debian/Ubuntu systems
2. **Installs NFS client packages**:
   - `nfs-common` for Debian/Ubuntu
   - `nfs-utils` for RedHat/CentOS/Fedora
3. **Starts and enables** rpcbind service
4. **Creates mount point** directory with proper permissions
5. **Mounts NFS share** to specified mount point
6. **Verifies the mount** and displays mount information

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
df -h | grep nfs

# List mounted shares
mount | grep nfs

# Test file operations
touch /mnt/nfs/test.txt
```

## Permanent Mount

The playbook uses `state: mounted` which adds the mount to `/etc/fstab`, making it permanent across reboots.

## Unmount NFS Share (Manual)

```bash
ansible-playbook -i inventory.ini nfs-client-setup.yml \
  -e "mount_state=absent"
```

Or manually on each client:
```bash
umount /mnt/nfs
```

## References

- [Ansible mount module](https://docs.ansible.com/ansible/latest/collections/ansible/posix/mount_module.html)
- [NFS Documentation](https://linux.die.net/man/5/nfs)
- [NFS Server Setup Guide](https://ubuntu.com/server/docs/service-nfs)
