# HPE HPC Automation

Ansible automation for common HPC environment setup tasks, including LDAP/SSSD integration and NFS client configuration.

## NFS Client Setup

The NFS client playbooks are configured for the current NFS server and client:

- NFS server: `10.25.67.100` (`gccvmesxnfs-store`)
- NFS client: `10.25.67.180`
- Exports mounted on the client:
	- `10.25.67.100:/home` -> `/home`
	- `10.25.67.100:/hpcdata` -> `/hpcdata`

Run from the repository root:

```bash
cd nfs_client
ansible-galaxy collection install -r requirements.yml
ansible-playbook -i inventory.ini nfs-client-setup.yml
```

To run only against the configured client host:

```bash
ansible-playbook -i inventory.ini nfs-client-setup.yml -l nfs-client
```

After the playbook completes, verify the mounts on `10.25.67.180`:

```bash
df -Th /home /hpcdata
mount | grep -E '(/home|/hpcdata)'
```

See `nfs_client/README-NFS.md` for the full NFS client instructions.
