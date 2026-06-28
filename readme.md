# HPE HPC Automation

Comprehensive automation toolkit for HPC environment setup, configuration, and management. This repository contains Ansible playbooks, scripts, and tools for LDAP/Kerberos authentication, SSSD integration, NFS storage, and Lustre filesystem management.

---

## 📊 System Architecture

```
┌────────────────────────────────────────────────────────────────────────────┐
│                      HPC Environment Architecture                          │
├────────────────────────────────────────────────────────────────────────────┤
│                                                                            │
│  ┌──────────────────────────────────────────────────────────────────────┐ │
│  │                    Authentication Services                          │ │
│  │  ┌──────────────────────┐        ┌──────────────────────┐           │ │
│  │  │   LDAP Server        │        │   Kerberos KDC       │           │ │
│  │  │   (389-DS)           │◄──────►│   (krb5kdc/kadmin)   │           │ │
│  │  │  10.25.67.150        │        │  10.25.67.150        │           │ │
│  │  │  Port: 389/636       │        │  Port: 88            │           │ │
│  │  └──────────────────────┘        └──────────────────────┘           │ │
│  └──────────────────────────────────────────────────────────────────────┘ │
│                                    │                                      │
│           ┌────────────────────────┼────────────────────────┐             │
│           │                        │                        │             │
│  ┌────────▼──────────┐  ┌─────────▼──────────┐  ┌─────────▼────────┐   │
│  │   Storage Layer   │  │  Compute Nodes     │  │  Lustre Nodes    │   │
│  │                   │  │  (via SSSD/PAM)    │  │  (Benchmarking)  │   │
│  │ NFS Server        │  │                    │  │                  │   │
│  │ 10.25.67.100      │  │ User Authentication│  │ Performance      │   │
│  │ ├─ /home          │  │ ├─ Lookup (LDAP)  │  │ Testing & Tuning │   │
│  │ ├─ /hpcdata       │  │ ├─ Auth (Krb5)    │  │                  │   │
│  │ └─ Shared Storage │  │ ├─ Caching (SSSD) │  │ lustre_perf/     │   │
│  │                   │  │ └─ Home Dirs      │  │ lustre_migrate/  │   │
│  └──────────────────┘  └───────────────────┘  └──────────────────┘   │
│           ▲                   ▲                       ▲                  │
│           │ NFS Mounts        │ User SSH/Apps        │ Network I/O      │
│           └───────────────────┴───────────────────────┘                  │
│                                                                            │
└────────────────────────────────────────────────────────────────────────────┘
```

---

## 🔄 Authentication & Authorization Workflow

```
┌─────────────────────────────────────────────────────────────────────┐
│                     User Login Request (SSH)                         │
└─────────────────────────────┬───────────────────────────────────────┘
                              │
                              ▼
                    ┌──────────────────────┐
                    │   PAM/SSSD Client    │
                    │   (Local Service)    │
                    └──────────────────────┘
                              │
              ┌───────────────┼───────────────┐
              │               │               │
              ▼               ▼               ▼
    ┌──────────────────┐ ┌────────────┐ ┌──────────────┐
    │ LDAP Lookup      │ │Krb5 Auth   │ │ Local Cache  │
    │ (User Info)      │ │ (Ticket)   │ │ (Offline)    │
    │ Base DN:         │ │ Request    │ │              │
    │ dc=hpcindia,dc=io├─┤ TGT/Service │ │ Credential   │
    │                  │ │ Ticket     │ │ Verification │
    └──────────────────┘ └────────────┘ └──────────────┘
              │               │               │
              └───────────────┼───────────────┘
                              │
                              ▼
                    ┌──────────────────────┐
                    │  Auth Verification   │
                    │  ✓ User Found        │
                    │  ✓ Credentials Valid │
                    │  ✓ Groups Determined │
                    └──────────────────────┘
                              │
                              ▼
                    ┌──────────────────────┐
                    │  Post-Login Setup    │
                    │  • Create home dir   │
                    │  • Set permissions   │
                    │  • Create session    │
                    │  • Mount NFS shares  │
                    └──────────────────────┘
                              │
                              ▼
                    ┌──────────────────────┐
                    │   User Session OK    │
                    │   Access to:         │
                    │   • /home (NFS)      │
                    │   • /hpcdata (NFS)   │
                    │   • HPC Resources    │
                    └──────────────────────┘
```

---

## 🚀 Deployment Workflow

```
┌─────────────────────────────────────────────────────────────────┐
│               Infrastructure Deployment Process                 │
└─────────────────────────────┬───────────────────────────────────┘
                              │
                    ┌─────────▼─────────┐
                    │ Phase 1: Prepare  │
                    │ • Inventory Setup │
                    │ • Network Config  │
                    │ • Host Config     │
                    └─────────┬─────────┘
                              │
            ┌─────────────────┼─────────────────┐
            │                 │                 │
    ┌───────▼────────┐ ┌─────▼──────┐ ┌──────▼─────────┐
    │ Phase 2A:      │ │ Phase 2B:  │ │ Phase 2C:      │
    │ LDAP/KDC Setup │ │NFS Config  │ │ SSSD Setup     │
    │ ─────────────── │ │ ───────── │ │ ─────────────  │
    │ 1. Install 389-DS│ │ 1. Install │ │ 1. Install    │
    │ 2. Create DB   │ │    NFS pkg │ │    SSSD pkg  │
    │ 3. Setup Krb5  │ │ 2. Mount   │ │ 2. Config    │
    │ 4. Create OUs  │ │    Points  │ │    sssd.conf │
    │ 5. Add admin   │ │ 3. Enable  │ │ 3. Enable    │
    │    principals  │ │    mounts  │ │    NSS/PAM   │
    └───────┬────────┘ └─────┬──────┘ └──────┬────────┘
            │                 │               │
            └─────────────────┼───────────────┘
                              │
                    ┌─────────▼─────────┐
                    │ Phase 3:          │
                    │ Validation Tests  │
                    │ • LDAP queries    │
                    │ • Krb5 tickets    │
                    │ • SSSD domain     │
                    │ • NFS mounts      │
                    │ • User login      │
                    └─────────┬─────────┘
                              │
                    ┌─────────▼─────────┐
                    │ Phase 4:          │
                    │ Production Ready  │
                    │ ✓ All Tests Pass  │
                    │ ✓ Services Active │
                    │ ✓ Users Can Login │
                    └───────────────────┘
```

---

## 🗂️ NFS & Storage Workflow

```
┌──────────────────────────────────────────────────────────────┐
│          NFS Mount & Data Access Flow                        │
└──────────────┬───────────────────────────────────────────────┘
               │
     ┌─────────▼─────────┐
     │  NFS Server       │
     │  10.25.67.100     │
     │  ─────────────── │
     │  • /home (RW)    │
     │  • /hpcdata (RW) │
     └─────────┬─────────┘
               │
     ┌─────────┴──────────┐
     │                    │
 ┌───▼──────────┐  ┌─────▼──────────┐
 │ Mount Point  │  │ Export Config  │
 │ /home        │  │ /etc/exports:  │
 │ /hpcdata     │  │ /home *(rw,no_ │
 │              │  │  root_squash)  │
 └───┬──────────┘  │ /hpcdata       │
     │             │ *(rw,no_root_  │
     │             │  squash)       │
     └─────┬───────┘
           │
   ┌───────▼────────┐
   │ NFS Client     │
   │ 10.25.67.180   │
   │ ──────────────│
   │ Mount Option: │
   │ rw,sync,hard  │
   │ timeo=30      │
   └───┬────────────┘
       │
   ┌───▼──────────────────┐
   │ User Data Access     │
   │ • Read Files         │
   │ • Write Data         │
   │ • Execute Programs   │
   │ • Share with Others  │
   └──────────────────────┘
```

---

## 🔐 SSSD Integration Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│            SSSD Client-Side Integration                         │
└─────────────────────────────────────────────────────────────────┘
                              │
                    ┌─────────▼─────────┐
                    │   /etc/sssd/      │
                    │   sssd.conf       │
                    │ ─────────────────│
                    │ [domain/default]  │
                    │ id_provider=ldap  │
                    │ auth_provider=krb5│
                    └─────────┬─────────┘
                              │
          ┌───────────────────┼───────────────────┐
          │                   │                   │
    ┌─────▼──────┐     ┌─────▼──────┐     ┌─────▼──────┐
    │   NSS      │     │    PAM     │     │  Cache     │
    │  Provider  │     │ Provider   │     │ Storage    │
    │ ──────────│     │ ──────────│     │ ──────────│
    │ getent     │     │ pam_sss.so│     │ /var/lib  │
    │ passwd/    │     │ Login     │     │ /sss/db   │
    │ group      │     │ Password  │     │ (offline) │
    └─────┬──────┘     │ chsh      │     └──────┬────┘
          │            │ chfn      │            │
          │            └─────┬─────┘            │
          │                  │                  │
          └──────────────────┼──────────────────┘
                             │
                 ┌───────────▼────────────┐
                 │  Database Lookups     │
                 │  ─────────────────── │
                 │ • User UID/GID        │
                 │ • Group Membership    │
                 │ • LDAP Cache          │
                 │ • Last Update Time    │
                 └───────────┬───────────┘
                             │
             ┌───────────────┴───────────────┐
             │                               │
    ┌────────▼─────────┐           ┌─────────▼────────┐
    │ Online Mode      │           │ Offline Mode     │
    │ ─────────────── │           │ ─────────────── │
    │ LDAP connected  │           │ LDAP unavailable│
    │ Real-time auth  │           │ Use cache       │
    │ Live lookups    │           │ Cached creds    │
    └──────────────────┘           └──────────────────┘
```

---

## Project Structure

### 📁 Folders Overview

| Folder | Purpose | Status |
|--------|---------|--------|
| **ldap** | LDAP server (389-DS) and Kerberos deployment | Production-ready |
| **nfs_client** | NFS client configuration and mount setup | Production-ready |
| **sssd** | SSSD server and client configuration | Config templates |
| **lustre_migration** | Lustre filesystem migration scripts | Development |
| **lustre_performance** | Lustre performance benchmarking tools | Testing |

---

## 🔐 LDAP / Kerberos Setup

Complete LDAP and Kerberos deployment for centralized authentication.

### Key Files

- **ldap-kdc-full.yml** — Production-hardened LDAP (389-DS) + Kerberos deployment with recovery logic
- **ldap_admin.sh** — Interactive CLI tool for LDAP administration (users, groups, memberships)
- **ldap_sssd_client_setup.yml** — SSSD client setup for LDAP authentication
- **sssd_client.yml** — LDAP + Kerberos SSSD client configuration

### Quick Start

**Deploy LDAP + Kerberos server:**
```bash
cd ldap
ansible-playbook -i inventory.ini ldap-kdc-full.yml
```

**Configure LDAP clients:**
```bash
cd ldap
ansible-playbook -i inventory.ini ldap_sssd_client_setup.yml
```

**Manage LDAP (Add users, groups, etc.):**
```bash
./ldap/ldap_admin.sh
```

### LDAP Configuration Reference

- **Base DN:** `dc=hpcindia,dc=io`
- **Server:** `ldap://localhost` (or `10.25.67.150`)
- **Port:** 389 (standard), 636 (secure)
- **Admin DN:** `cn=Directory Manager`
- **Default Realm:** `HPCINDIA.IO`

---

## 🗃️ NFS Client Setup

Configure NFS client mounts for shared storage access.

### Configuration

- **NFS Server:** `10.25.67.100` (`gccvmesxnfs-store`)
- **NFS Client:** `10.25.67.180`
- **Exports:**
  - `10.25.67.100:/home` → `/home`
  - `10.25.67.100:/hpcdata` → `/hpcdata`

### Quick Start

```bash
cd nfs_client
ansible-galaxy collection install -r requirements.yml
ansible-playbook -i inventory.ini nfs-client-setup.yml
```

### Verify Mounts

```bash
df -Th /home /hpcdata
mount | grep -E '(/home|/hpcdata)'
```

See `nfs_client/README-NFS.md` for detailed NFS instructions.

---

## 🔑 SSSD (System Security Services Daemon)

User authentication and identity management configuration.

### Folders

- **sssd/sssd_client/** — Client-side SSSD configuration
- **sssd/sssd_server/** — Server-side SSSD setup

### Features

- LDAP integration
- Kerberos authentication
- User enumeration and caching
- Home directory creation on login

---

## 💾 Lustre Filesystem

Lustre performance testing and migration tools.

### lustre_performance

Performance benchmarking and metrics collection for Lustre filesystems.

- **lustre_enterprise_benchmark_v2.sh** — Enterprise-grade benchmarking script

### lustre_migration

Tools and scripts for Lustre filesystem migrations.

- **lustre_git/** — Git-tracked migration data
- **lustre_script/** — Migration automation scripts

---

## 📋 Prerequisites

- **Ansible 2.9+**
- **Python 3.6+**
- **SSH access** to target hosts
- **Root/sudo access** for deployments
- **Required packages:** `ansible`, `python3-dnf` (for Fedora/RHEL)

---

## 🚀 Quick Reference

### Deploy All Components

```bash
# 1. LDAP/Kerberos
ansible-playbook -i inventory.ini ldap/ldap-kdc-full.yml

# 2. LDAP Clients (SSSD)
ansible-playbook -i inventory.ini ldap/ldap_sssd_client_setup.yml

# 3. NFS Clients
ansible-playbook -i inventory.ini nfs_client/nfs-client-setup.yml
```

### Common Commands

```bash
# Test LDAP connection
ldapsearch -x -H ldap://10.25.67.150 -b "dc=hpcindia,dc=io"

# Check SSSD status
sssctl domain-status hpc

# List LDAP users
id testuser

# Verify NFS mounts
mount | grep nfs
```

---

## 📚 Additional Resources

- Individual folder READMEs for detailed instructions
- LDAP data files: `ldap/users.ldif`, `ldap/groups.ldif`, `ldap/group-members.ldif`
- Ansible inventory: `ldap/inventory.ini`, `nfs_client/inventory.ini`

---

## 📋 Deployment Sequence & Validation

```
┌─────────────────────────────────────────────────────────────────┐
│            Complete Deployment & Testing Timeline               │
└─────────────────────────────────────────────────────────────────┘

STEP 1: LDAP/Kerberos Server Deployment
───────────────────────────────────────
  $ cd ldap
  $ ansible-playbook -i inventory.ini ldap-kdc-full.yml
  
  ✓ 389-DS Instance Created
  ✓ Kerberos DB Initialized
  ✓ LDAP Suffixes/OUs Added
  ✓ Admin Principals Created
  ✓ Services Started & Enabled
  
  VALIDATE:
  $ ldapsearch -x -H ldap://localhost -b "dc=hpcindia,dc=io"
  $ kadmin.local -q "listprincs"
  
  ⏱️ Expected Time: 5-10 minutes
  

STEP 2: LDAP User/Group Setup
──────────────────────────────
  $ ./ldap/ldap_admin.sh
  
  Interactive Menu:
  1. Add groups
  2. Add users (assign UID/GID)
  3. Add users to groups
  
  Verify:
  $ ldapsearch -x -H ldap://localhost -b "ou=People,dc=hpcindia,dc=io"
  $ ldapsearch -x -H ldap://localhost -b "ou=Groups,dc=hpcindia,dc=io"
  
  ⏱️ Expected Time: 5-15 minutes (manual)


STEP 3: SSSD Client Configuration (Compute Nodes)
──────────────────────────────────────────────────
  $ cd ldap
  $ ansible-playbook -i inventory.ini ldap_sssd_client_setup.yml
  
  ✓ SSSD Packages Installed
  ✓ sssd.conf Generated
  ✓ NSS/PAM Configured
  ✓ SSSD Service Started
  ✓ Cache Initialized
  
  VALIDATE:
  $ sssctl domain-status hpc
  $ getent passwd testuser
  $ getent group testgroup
  
  ⏱️ Expected Time: 3-5 minutes (per node)


STEP 4: NFS Client Mounts (Storage Access)
───────────────────────────────────────────
  $ cd nfs_client
  $ ansible-galaxy collection install -r requirements.yml
  $ ansible-playbook -i inventory.ini nfs-client-setup.yml
  
  ✓ NFS Packages Installed
  ✓ Mount Points Created
  ✓ Mounts Configured
  ✓ Automount Enabled
  
  VALIDATE:
  $ df -Th /home /hpcdata
  $ mount | grep nfs
  $ ls -la /home
  $ touch /hpcdata/test_$(hostname).txt
  
  ⏱️ Expected Time: 2-4 minutes (per node)


STEP 5: End-to-End Testing
──────────────────────────
  
  5.1 User Authentication Test
  ────────────────────────────
  $ ssh testuser@10.25.67.180
  (enter Kerberos password)
  
  ✓ Login successful
  ✓ Home directory mounted (/home/testuser)
  ✓ Group memberships correct
  
  
  5.2 LDAP Verification
  ──────────────────────
  $ id testuser           # Show user info
  $ groups testuser       # Show group membership
  $ getent passwd         # List all users
  
  
  5.3 NFS Access Verification
  ─────────────────────────────
  $ cd ~                  # Navigate to home (/home via NFS)
  $ df -h .              # Should show NFS mount
  $ cd /hpcdata          # Shared data directory
  $ ls -la               # List shared files
  
  
  5.4 Kerberos Ticket Verification
  ──────────────────────────────────
  $ klist                 # List active tickets
  $ klist -e             # Show encryption types
  $ kinit testuser       # Request new ticket (if expired)
  
  
  ⏱️ Expected Time: 10-15 minutes (manual testing)
  ⏱️ Total Deployment: ~30 minutes


ROLLBACK (if needed)
────────────────────
LDAP Rollback:
  $ systemctl stop dirsrv@hpcindia
  $ rm -rf /etc/dirsrv/slapd-hpcindia /var/lib/dirsrv/slapd-hpcindia
  
SSSD Rollback:
  $ systemctl stop sssd
  $ sss_cache -E
  $ systemctl start sssd
  
NFS Rollback:
  $ umount /home /hpcdata
  $ rm -rf /etc/fstab entries
```

---

## 🔍 Component Interaction Diagram

```
┌─────────────────────────────────────────────────────────────────┐
│  Data Flow: User Login to HPC Resource Access                  │
└─────────────────────────────────────────────────────────────────┘


User SSH Login Request
       │
       ├─────────────────────────────┐
       │                             │
       ▼                             ▼
    PAM Stack                    sshd Process
       │                             │
       ├──> pam_krb5.so ────┐       │
       ├──> pam_sss.so  ────┼──────►│
       └──> pam_unix.so ────┘       │
                │                    │
                ▼                    │
           SSSD Daemon              │
                │                    │
        ┌───────┼───────┐           │
        │       │       │           │
        ▼       ▼       ▼           │
     LDAP    Krb5    Cache         │
     Query   Check   Lookup        │
        │       │       │           │
        └───────┼───────┘           │
                │                    │
                ▼                    │
         Auth Success ◄─────────────┤
                │                    │
                ▼                    ▼
        oddjob.mkhomedir        SSH Session
        (Create /home/user)     (User Shell)
                │                    │
                ├──────┬─────────────┤
                │      │             │
                ▼      ▼             ▼
            Mount   Set Env       NFS Read
            NFS     Vars          /home/user
                │                    │
                └────────┬───────────┘
                         │
                         ▼
                    User in HPC
                    Environment
                    ✓ Auth: Krb5
                    ✓ Home: NFS
                    ✓ Groups: LDAP
                    ✓ Perms: SSSD
```

---

## ⚙️ Troubleshooting

### LDAP Issues
- Check LDAP service: `systemctl status dirsrv@hpcindia`
- View LDAP logs: `/var/log/dirsrv/slapd-hpcindia/errors`
- Test bind: `ldapwhoami -x -H ldap://localhost -D "cn=Directory Manager" -w <password>`

### SSSD Issues
- Check SSSD status: `systemctl status sssd`
- Clear cache: `sss_cache -E`
- View debug logs: `tail -f /var/log/sssd/*.log`

### NFS Issues
- Check mounts: `mount | grep nfs`
- View NFS stats: `nfsstat`
- Test connectivity: `showmount -e 10.25.67.100`

---

## 📝 Notes

- All playbooks should be run from the repository root
- Update inventory files with your actual hostnames/IPs
- Sensitive data (passwords) should be managed via Ansible Vault
- Test in a non-production environment first
