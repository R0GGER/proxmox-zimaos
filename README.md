# ZimaOS Installation Guide for Proxmox

This guide provides step-by-step instructions for installing [ZimaOS](https://github.com/IceWhaleTech/zimaos) on Proxmox Virtual Environment. ZimaOS is a modern NAS operating system that can be easily deployed as a virtual machine.

## 📋 Table of Contents

- [Installation Methods](#installation-methods)
- [ISO version - Super Easy](#iso-version---super-easy)
- [Manual Installation](#manual-installation)
- [Post-Installation Configuration](#post-installation-configuration)
- [Troubleshooting](#troubleshooting)

## Installation Methods

Choose the installation method that best suits your needs:

| Method   | Time   | Difficulty  | Description |
|----------|--------|-------------|:-------------|
| **\*.iso** | ~2 min | Super Easy  | New VM, download ISO, attach; you run installer |
| **Manual** | ~5 min | Medium      | Step-by-step, full control |

## ISO version - Super Easy

The **ISO script** (`zimaos_zimacube_installer-iso.sh`) is the easiest way to install ZimaOS using the official installer. It does everything for you:

1. **Run the script** on your Proxmox node (SSH):
   ```bash
   bash -c "$(wget -qLO - https://raw.githubusercontent.com/R0GGER/proxmox-zimaos/refs/heads/main/zimaos_zimacube_installer-iso.sh)"
   ```
2. **Answer a few prompts** (you can press Enter to accept defaults):
   - ZimaOS version (`latest` or a specific version number, e.g. `1.5.4`)
   - VM ID (100–999)
   - Name (default: ZimaOS)
   - Disk size in GB (default: 32)
   - CPU cores (default: 2)
   - Memory in MB (default: 2048)
3. **Confirm** when the script shows the VM settings.
4. The script **creates the VM**, **downloads the ZimaOS installer ISO**, and **attaches it as the boot CD/DVD**.
5. **Start the VM** in Proxmox. It boots from the installer.
6. **Run the ZimaOS installer** in the VM (e.g. choose “Install ZimaOS”).
7. **After installation**: STOP (not poweroff) the VM, detach the ISO (set CD/DVD to “Do not use any media”), then start the VM again.

## Manual Installation

For users who prefer more control over the installation process or need custom configurations.

### Prerequisites
- Proxmox VE running on your server
- SSH access to your Proxmox node
- Basic understanding of VM creation in Proxmox

### Step 1: Create VM in Proxmox

1. **Open Proxmox Web Interface** and navigate to your node
2. **Create a new VM** with the following settings:
   - **OS**: Do not use any media
   - **System**: 
     - BIOS: OMVF (UEFI)
     - Choose an EFI storage (e.g., `local-lvm`)
   - **Disks, CPU, Memory, Network**: Use default settings or customize as needed
   - **Confirm**: Finish (do not check "Start after created")

### Step 2: Run Installation Script

Execute the installer script on your Proxmox node (not inside the VM):

```bash
bash -c "$(wget -qLO - https://raw.githubusercontent.com/R0GGER/proxmox-zimaos/refs/heads/main/zimaos_zimacube_installer-iso.sh)"
```

**Answer the prompts:**
- Enter VM ID: `[Your VM ID]`
- Enter storage volume: `[e.g., local-lvm]`

### Step 3: Configure VM BIOS

1. **Navigate to the VM** in Proxmox
2. **Go to Console** tab
3. **Start the VM** and immediately press **ESC** multiple times to access the virtual BIOS
4. **Navigate to Device Manager** → **Secure Boot Configuration**
5. **Disable Secure Boot**:
   - Select "Attempt Secure Boot"
   - Press **Enter** → **Esc** → **Esc** → **Continue** → **Enter**

### Step 4: Install ZimaOS

1. **Select "1. Install ZimaOS"** from the boot menu
2. **Complete the installation wizard** following the on-screen prompts
3. **After installation completes**:
   - Stop the VM using **Stop** button in Proxmox (not Shutdown)
   - Disable **scsi1** and enable **scsi0** in VM hardware settings
   - Start the VM again

### 📹 Video Tutorial

Watch the complete installation process: [ZimaOS Proxmox Installation Video](https://www.youtube.com/watch?v=3n739Dia8eMz)

> **Note**: The video is fast-forwarded in some sections for brevity. 

## Post-Installation Configuration

After successful installation, you may need to perform additional configuration steps:

### Initial Setup
1. **Access ZimaOS Web Interface** using the VM's IP address
2. **Complete the initial setup wizard**
3. **Configure storage pools** and network settings
4. **Set up user accounts** and permissions

### Network Configuration
- Ensure your VM has proper network access
- Configure static IP if needed
- Set up port forwarding for external access

### Adding Additional Storage

To add more drives to your ZimaOS VM:

1. **Stop the ZimaOS VM** in Proxmox
2. **Add new hard disk**:
   - Go to **Hardware** → **Add** → **Hard Disk**
   - Set **Bus/Device** to **SATA**
   - Configure size and storage location
3. **Start the VM** and configure the new drive in ZimaOS

![Add Drive Example](https://github.com/user-attachments/assets/a3c2463f-6cc1-4671-9ddb-a717a06284e8)

## Troubleshooting

### Common Issues

#### VM Won't Boot
- **Check Secure Boot**: Ensure Secure Boot is disabled in VM BIOS
- **Verify EFI Storage**: Confirm EFI storage is properly configured
- **Check VM Settings**: Ensure UEFI is selected as BIOS type

#### Installation Script Fails
- **Check Internet Connection**: Ensure Proxmox node has internet access
- **Verify VM ID**: Make sure the VM ID exists and is correct
- **Check Storage**: Verify storage volume is available and has space

### Getting Help

- **ZimaOS GitHub**: [Official ZimaOS Documentation](https://github.com/IceWhaleTech/ZimaOS)
- **Proxmox Documentation**: [https://pve.proxmox.com/wiki/Main_Page](https://pve.proxmox.com/wiki/Main_Page)

---

*Inspired by [bigbeartechworld](https://www.youtube.com/watch?v=o2H5pwLxOwA) - Thank you for the original tutorial!*
