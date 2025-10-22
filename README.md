Excellent — time for a full rewrite worthy of the evolved lab you’ve built.
Below is a complete **replacement `README.md`**, updated to reflect your *current architecture*, including:

* The transition from `/var/www/html` to `/var/www/<distro>/<version>`
* The addition of `init_pxe_distro.sh`
* The enhanced environment awareness via `env.conf`
* The systemd automount workflow
* The “Badge of Dork-Baggery Honor” legacy 🏅

---

## ✅ **`README.md`**

````markdown
# Linux PXE / TFTP / ISO Automation Lab

A modular, environment-aware automation framework for managing **PXE boot**, **ISO mounts**, and **KEA DHCP** configuration on RHEL-based systems.  
It provides a complete toolchain for initializing, synchronizing, verifying, and repairing a self-contained provisioning lab — all through clean, idempotent Bash.

---

## 🗺️ Repository Overview

| Directory | Purpose |
|------------|----------|
| **ops/** | Core operational scripts: sync, mount generation, validation, and repair |
| **kea/** | Repository copy of `/etc/kea` DHCP configuration files |
| **system/** | Systemd `.mount` and `.automount` templates used for ISO management |
| **tftpboot/** | PXE boot structure and linked `images/pxeboot` directories |
| **www/** | Webroot content for HTTP-based installations (ISO mounts live here) |
| **.rsync-exclude** | File and directory exclusions used during repo syncs |
| **env.conf** | Central configuration of all key environment paths and version definitions |

---

## ⚙️ Environment Configuration

All scripts dynamically source `env.conf`, ensuring consistency and portability.

```bash
# Base repository path
REPO_BASE="$HOME/src/projects/home/linux_tftp"

# ISO storage (mounted via systemd)
ISO_DIR="/srv/iso"

# PXE / Web roots
WWW_BASE="/var/www"
TFTP_BASE="/var/lib/tftpboot"

# Distro definitions (auto-expandable)
declare -A DISTRO_VERSIONS=(
  [rhel]="9 10"
  [rocky]="10"
)
````

Changing `REPO_BASE`, `WWW_BASE`, or any path variable automatically updates all scripts.
No hard-coded paths. No drift.

---

## 🧠 Core Scripts

| Script                      | Purpose                                                                                 |
| --------------------------- | --------------------------------------------------------------------------------------- |
| **pull_lab_to_repo.sh**     | Pulls live configs and web/TFTP data into the repo (preserves permissions)              |
| **push_repo_to_lab.sh**     | Pushes repo content back into live system directories                                   |
| **generate_mount_units.sh** | Creates `.mount` and `.automount` units for each ISO                                    |
| **enable_all_mounts.sh**    | Enables and starts all automount units for on-demand ISO mounting                       |
| **reset_mounts.sh**         | Cleans and rebuilds mount units after config changes                                    |
| **init_pxe_distro.sh**      | Creates PXE/TFTP directory structure and symlink for a given distro/version             |
| **build_pxe_links.sh**      | Rebuilds all PXE symlinks defined in `env.conf`                                         |
| **sanity_check.sh**         | Validates mounts, automounts, PXE links, KEA configs, permissions, and SELinux contexts |
| **repair_kea_sync.sh**      | Syncs KEA configuration between `/etc/kea` and repo, with optional service restart      |

---

## 🔄 PXE Initialization Workflow

### 1️⃣ Mount Preparation

ISOs are stored under `/srv/iso` and mounted automatically on demand:

```bash
sudo ./generate_mount_units.sh
sudo ./enable_all_mounts.sh
```

Each ISO is mounted to `/var/www/<distro>/<version>` via systemd automounts.

---

### 2️⃣ PXE Structure Initialization

When adding a new ISO or distro version, initialize its PXE directory:

```bash
sudo ./init_pxe_distro.sh <distro> <version>
```

Example:

```bash
sudo ./init_pxe_distro.sh rhel 10
sudo ./init_pxe_distro.sh rocky 10
```

This creates:

```
/var/lib/tftpboot/<distro>/<version>/images/pxeboot -> /var/www/<distro>/<version>/images/pxeboot
```

and ensures SELinux contexts are restored on both trees.

---

### 3️⃣ Link Rebuild and Validation

After all mounts and PXE links exist:

```bash
sudo ./build_pxe_links.sh
sudo ./sanity_check.sh
```

This confirms every symlink points to the expected mounted ISO path and validates KEA configuration integrity.

---

## 🧾 Adding a New ISO

To add a new distribution or version:

1. Copy or symlink the ISO into `/srv/iso/`:

   ```bash
   sudo cp rhel-11.iso /srv/iso/
   ```
2. Update `env.conf`:

   ```bash
   declare -A DISTRO_VERSIONS=(
     [rhel]="9 10 11"
     [rocky]="10"
   )
   ```
3. Run:

   ```bash
   ./generate_mount_units.sh
   ./enable_all_mounts.sh
   ./init_pxe_distro.sh rhel 11
   ./build_pxe_links.sh
   ./sanity_check.sh
   ```

---

## 🧰 Common Workflows

### 🧩 Sync Lab → Repo

```bash
./pull_lab_to_repo.sh
```

### 🧩 Repo → Lab

```bash
./push_repo_to_lab.sh
```

### 🧩 Repair KEA Config

```bash
./repair_kea_sync.sh --auto
```

### 🧩 Validate Environment

```bash
./sanity_check.sh --brief
```

---

## 📊 Version Control Practices

Each verified baseline should be tagged:

```bash
git add -A
git commit -m "Baseline verified via sanity_check.sh"
git tag -a v1.0 -m "Stable PXE/KEA baseline"
git push --tags
```

Git preserves configuration drift history — *treat it as your audit log*.

---

## 🧩 System Requirements

* RHEL or Rocky Linux 9+
* `bash`, `rsync`, `systemd`
* Apache (`httpd`)
* KEA DHCP server
* Optional: SELinux (Enforcing or Permissive)

---

## 🧩 Design Philosophy

> **Automation is the bridge between repeatability and creativity.**

This repo is built around real-world operational patterns:

* **KEA DHCP** handles dynamic IP assignment.
* **Apache HTTP** serves ISO installation trees.
* **TFTP** delivers boot files.
* **systemd automount** mounts ISOs on demand.
* **Rsync** ensures reproducible configuration states.

Each module is independent, idempotent, and environment-aware — ideal for lab automation, field testing, or production-grade provisioning at small scale.

---

## 🧠 Lessons Learned

🏅 **Badge of Dork-Baggery Honor (First Class)**
Awarded for valiant service in the face of one’s own typos, filesystem quirks, and self-inflicted chaos.

### Case Sensitivity Strikes Again

During setup, mount units failed with mysterious
`failed to setup loop device` errors.

After combing through kernel logs and SELinux contexts, the culprit was — **capitalization.**

> The ISO was named `RHEL-9.iso` while the mount unit referenced `rhel-9.iso`.
> Linux, being the brutally honest friend it is, does not forgive such sins.

**Takeaway:**
Before debugging the kernel, double-check what you *think* you know — the bug might just be in your typing.

---

## ☕ Parting Wisdom

> “I, too, have seen stupid people.
> They’re everywhere — and they don’t know they’re stupid.”
> — *Anonymous Sysadmin, after three cups of coffee and one mysterious kernel panic*

Never underestimate the power of:

* `ls -l`
* `grep`
* and a good laugh after a 2-hour goose chase.

This repo isn’t just a toolkit — it’s a notebook of lessons learned the hard way, written so the next late-night engineer has a slightly easier time than you did.

---

