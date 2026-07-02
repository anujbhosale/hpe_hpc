# Storage Mount Operations Document

## 1. Document Purpose

This document explains the workflow, systemd artifacts, and operational steps for:

1. [nfs_mounts.sh](nfs_mounts.sh)
2. [lustre_mounts.sh](lustre_mounts.sh)

Target audience: Linux administrators managing NFS and Lustre client mount configuration through systemd mount units.

## 2. High-Level Architecture

```mermaid
flowchart LR
    A[Admin executes script as root] --> B[Script writes config files]
    B --> C[Script writes systemd .mount units]
    C --> D[systemctl daemon-reload]
    D --> E[systemctl enable or enable --now]
    E --> F[Boot-time or immediate mount behavior]
```

## 3. NFS Workflow

Source script: [nfs_mounts.sh](nfs_mounts.sh)

### 3.1 NFS Process Flow

```mermaid
flowchart TD
    A[Start nfs_mounts.sh] --> B{Run as root?}
    B -- No --> B1[Exit: root required]
    B -- Yes --> C{rpm available?}
    C -- No --> C1[Exit: RPM-based system required]
    C -- Yes --> D{nfs-utils installed?}
    D -- No --> D1[Exit with install guidance]
    D -- Yes --> E[Ensure /home and /shared exist]
    E --> F[Create home.mount and shared.mount]
    F --> G[systemctl daemon-reload]
    G --> H[systemctl enable --now home.mount]
    H --> I[systemctl enable --now shared.mount]
    I --> J[Verify mountpoint /home]
    J --> K[Verify mountpoint /shared]
    K --> L[Success]
```

### 3.2 Generated NFS Units

1. /etc/systemd/system/home.mount
2. /etc/systemd/system/shared.mount

### 3.3 NFS Mount Definitions

| Unit | What | Where | Type | Options |
|---|---|---|---|---|
| home.mount | FZ2BVIP1.mpfile2.int.oden2.com:/ODEN2Shares/Home | /home | nfs | _netdev,sec=sys,vers=4.2,noresvport,context=system_u:object_r:ssh_home_t:s0 |
| shared.mount | FZ2AVIP1.mpfile1.int.oden2.com:/ODEN2Shares/Shared | /shared | nfs | _netdev,sec=sys,vers=4.2,noresvport |

## 4. Lustre Workflow

Source script: [lustre_mounts.sh](lustre_mounts.sh)

### 4.1 Lustre Process Flow

```mermaid
flowchart TD
    A[Start lustre_mounts.sh] --> B{Run as root?}
    B -- No --> B1[Exit: root required]
    B -- Yes --> C[Write /etc/modprobe.d/lnet.conf]
    C --> D[Run lustre_rmmod]
    D --> E[Run modprobe lustre]
    E --> F[Create five .mount units]
    F --> G[systemctl daemon-reload]
    G --> H[Enable all Lustre mount units]
    H --> I[Success]
```

### 4.2 LNet Configuration Artifact

1. /etc/modprobe.d/lnet.conf

Content:

```conf
options lnet networks=o2ib20(ibs6)
```

### 4.3 Generated Lustre Units

1. /etc/systemd/system/bfz22.mount
2. /etc/systemd/system/boutput_hub.mount
3. /etc/systemd/system/fz21.mount
4. /etc/systemd/system/fz24.mount
5. /etc/systemd/system/output_hub.mount

## 5. Execution Procedure

```bash
sudo ./nfs_mounts.sh
sudo ./lustre_mounts.sh
```

## 6. Validation Workflow

```mermaid
flowchart LR
    A[Run scripts] --> B[Check unit files in /etc/systemd/system]
    B --> C[Check systemd unit status]
    C --> D[Check active mounts]
    D --> E[Operational ready]
```

Commands:

```bash
systemctl status home.mount shared.mount
systemctl status bfz22.mount boutput_hub.mount fz21.mount fz24.mount output_hub.mount
mount | egrep ' /home | /shared | /bfz22 | /boutput_hub | /fz21 | /fz24 | /output_hub '
```

## 7. Operational Notes

1. These scripts are designed for Linux systems using systemd.
2. Unit files are overwritten on each script run.
3. In [nfs_mounts.sh](nfs_mounts.sh), enable uses --now, so mounts are started immediately.
4. In [lustre_mounts.sh](lustre_mounts.sh), units are enabled for boot using systemctl enable.
5. Mounting NFS on /home can hide local home content while mounted.
