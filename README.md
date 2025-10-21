Perfect timing — you’ll have a polished foundation right as you push your first commit.
Below are both files ready to drop into your new repo root (`~/src/linux_tftp/`):

---

## ✅ **`README.md`**

````markdown
# Linux TFTP / PXE Lab Automation

A modular lab automation framework for managing PXE boot, ISO mounts, and KEA DHCP configuration
on Red Hat–based systems. Designed for repeatable provisioning, testing, and configuration sync.

---

## 🧩 Repository Overview

| Directory | Purpose |
|------------|----------|
| **ops/** | Operational shell scripts for syncing, sanity checks, and environment repair |
| **kea/** | Repository copy of `/etc/kea` configuration files |
| **system/** | Systemd mount and automount templates |
| **tftpboot/** | PXE boot assets and linked `images/pxeboot` directories |
| **www/** | Web content for ISO-based HTTP installs |
| **.rsync-exclude** | Exclusion rules for file synchronization (used by pull/push scripts) |
| **env.conf** | Centralized configuration for all paths and environment variables |

---

## ⚙️ Environment Configuration

All scripts source `ops/env.conf`, which defines shared variables:

```bash
# Base repo directory
REPO_BASE="$HOME/src/linux_tftp"

# ISO image storage
ISO_DIR="$HOME/iso"

# KEA configuration paths
KEA_SYS_DIR="/etc/kea"
KEA_REPO_DIR="$REPO_BASE/kea"
````

Changing `REPO_BASE` automatically updates all dependent scripts.

---

## 🧠 Core Scripts

| Script                      | Function                                                                        |
| --------------------------- | ------------------------------------------------------------------------------- |
| **pull_lab_to_repo.sh**     | Pulls live configuration and content into the repo while preserving permissions |
| **push_repo_to_lab.sh**     | Pushes repo content back to live directories for testing                        |
| **generate_mount_units.sh** | Creates systemd `.mount` and `.automount` units for RHEL and Rocky ISOs         |
| **enable_all_mounts.sh**    | Enables and starts all detected automount units                                 |
| **reset_mounts.sh**         | Cleans existing ISO mount units and reloads systemd                             |
| **sanity_check.sh**         | Validates mountpoints, PXE links, KEA configs, and SELinux context              |
| **repair_kea_sync.sh**      | Synchronizes KEA system ↔ repo configs and optionally restarts services         |

---

## 🚀 Common Workflows

### Initialize / Sync the Lab

```bash
cd ~/src/linux_tftp/ops
./pull_lab_to_repo.sh
./sanity_check.sh
```

### Repair Configuration

```bash
./repair_kea_sync.sh --auto
```

### Regenerate Mount Units

```bash
./reset_mounts.sh
./generate_mount_units.sh
./enable_all_mounts.sh
```

### Validate End-to-End

```bash
./sanity_check.sh --brief
```

---

## 🧾 Versioning Strategy

* Tag each verified baseline (e.g., after new ISO versions or KEA config changes):

  ```bash
  git tag -a v1.0 -m "Baseline environment verified via sanity_check.sh"
  git push origin v1.0
  ```

* Keep configuration drift visible through Git diffs.

---

## 🧰 System Requirements

* RHEL/Rocky Linux 9 or later
* Apache (httpd)
* KEA DHCP server
* rsync, systemd, bash
* Optional: SELinux in permissive or enforcing mode

---

## 🧑‍💻 Author Notes

This environment was built to simulate real-world provisioning pipelines:

* **KEA DHCP** for address assignment
* **Apache HTTP** for ISO-based installation
* **TFTP** for PXE boot delivery
* **systemd automount** for ISO management

Everything is modular — feel free to extend with Ansible roles or Terraform integration for remote provisioning.

---

*“Automation is the bridge between repeatability and creativity.”*
---

## 💭 Philosophy

> “I, too, have seen stupid people.  
> They’re everywhere — and they don’t know they’re stupid.”  
> — *Anonymous Sysadmin, after three cups of coffee and one mysterious kernel panic*

We’ve all been there — late nights, uncooperative systems, and that creeping realization that the problem wasn’t the server after all.  
This repo exists not just to automate and harden a lab environment, but to preserve those *hard-won lessons* that come from chasing ghosts through the logs.  

Remember:  
- Always check the obvious before rewriting the kernel.  
- Never trust a green check mark you didn’t personally verify.  
- And when all else fails, `ls -l` is your best friend.

May future engineers find wisdom (and catharsis) here.


--- 
## 🧠 Lessons Learned
🏅 Badge of Dork-Baggery Honor (First Class) — awarded for valiant service in the face of one’s own typos, filesystem quirks, and self-inflicted chaos.

Case Sensitivity Strikes Again
During setup, the mount units kept failing with mysterious failed to setup loop device errors.
After diving through kernel logs, systemd sandbox settings, and loop device allocation, the culprit turned out to be...
capitalization.

The symlink was named RHEL-9.iso while the mount unit referenced rhel-9.iso.
Linux, being the brutally honest friend it is, does not forgive such sins.

Takeaway: Before debugging the kernel, double-check what you think you know — the bug might just be in your typing.
````
