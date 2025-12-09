#!/bin/bash

# github.com/R0GGER/proxmox-zimaos
# bash -c "$(wget -qLO - https://raw.githubusercontent.com/R0GGER/proxmox-zimaos/refs/heads/main/zimaos_zimacube_installer.sh)"

# ZimaOS version
VERSION="1.5.0"

# Variables
URL="https://github.com/IceWhaleTech/ZimaOS/releases/download/$VERSION/zimaos-x86_64-${VERSION}_installer.img"
IMAGE=$(basename "$URL")
IMAGE_PATH="/var/lib/vz/images/$IMAGE"
DISK_NUMBER="2"
DISK="scsi1"

# Colors
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# Functions
validate_number() {
    if ! [[ $1 =~ ^[0-9]+$ ]]; then
        echo -e "${RED}Error: Please enter a valid number${NC}"
        exit 1
    fi
}

check_vmid() {
    if ! qm status $1 >/dev/null 2>&1; then
        echo -e "${RED}Error: VMID $1 does not exist${NC}"
        exit 1
    fi
}

check_volume() {
    if ! pvesm status | grep -q "^$1"; then
        echo -e "${RED}Error: Storage volume $1 does not exist${NC}"
        exit 1
    fi
}

clear
echo -e "${YELLOW}=== Proxmox ZimaOS Installer ===${NC}"
echo -e "${GREEN}Version: $VERSION${NC}\n"

echo -e "!! Before running this script, make sure you have:${NC}\n"
echo -e "Created a new VM with:${NC}"
echo -e " - OS -> Do not use any media"
echo -e " - System -> BIOS -> OMVF (UEFI)"
echo -e " - EFI Storage configured (e.g. local-lvm)"
echo -e " - Disks, CPU, Memory, Network configured\n"
echo -e "!! Do NOT start the VM after creation !!${NC}"

# VMID
while true; do
    read -p "Enter VM ID (100-999): " VMID
    validate_number $VMID
    if [[ $VMID -ge 100 && $VMID -le 999 ]]; then
        check_vmid $VMID
        break
    else
        echo -e "${RED}Error: VMID must be between 100 and 999${NC}"
    fi
done

# Storage volume
while true; do
    read -p "Enter storage volume [local-lvm]: " VOLUME
    VOLUME=${VOLUME:-local-lvm}
    if check_volume $VOLUME; then
        break
    fi
done

mkdir -p /var/lib/vz/images

# Remove any old zimaos image files
echo "Cleaning up any existing image files..."
rm -f "/var/lib/vz/images/"zimaos_zimacube*.img "/var/lib/vz/images/"zimaos_zimacube*.img.xz

# Download
echo -e "\n${YELLOW}Downloading the image...${NC}"
wget -q --show-progress -O "$IMAGE_PATH" "$URL"
if [ $? -ne 0 ]; then
    echo -e "${RED}Error: Failed to download the image.${NC}"
    exit 1
fi

# Import the disk
echo -e "\n${YELLOW}Importing the disk...${NC}"
qm importdisk $VMID "$IMAGE_PATH" $VOLUME --format raw
if [ $? -ne 0 ]; then
    echo -e "${RED}Error: Failed to import the disk.${NC}"
    rm -f "$IMAGE_PATH" 
    exit 1
fi

# Attach the disk to the VM
echo -e "\n${YELLOW}Attaching the disk...${NC}"
STORAGE_TYPE=$(pvesm status -storage "$VOLUME" | awk 'NR==2 {print $2}')
case "$STORAGE_TYPE" in
    dir|btrfs|nfs|cifs|glusterfs)
        qm set $VMID --$DISK $VOLUME:$VMID/vm-$VMID-disk-$DISK_NUMBER.raw --boot c --scsihw virtio-scsi-pci --boot order=$DISK
        ;;
    *)
        qm set $VMID --$DISK $VOLUME:vm-$VMID-disk-$DISK_NUMBER --boot c --scsihw virtio-scsi-pci --boot order=$DISK
        ;;
esac
if [ $? -ne 0 ]; then
    echo -e "${RED}Error: Failed to set the disk.${NC}"
    exit 1
fi

# Cleanup downloaded image
rm -f "$IMAGE_PATH"

# Get started
echo -e "\n${GREEN}Success! ZimaOS installer image has been added to VM $VMID${NC}\n"
echo -e "${YELLOW}READ THIS CLOSELY BEFORE STARTING THE VM:${NC}"
echo -e "To ensure successful booting, you have to disable Secure Boot within the VM."
echo -e "1. Go to ${YELLOW}Console${NC} and start the VM."
echo -e "2. Click ${YELLOW}Start Now${NC} and press ${YELLOW}ESC ESC ESC${NC} (multiple times) to load the virtual BIOS"
echo -e "3. Go to ${YELLOW}Secure Boot Configuration${NC} option in ${YELLOW}Device Manager${NC} and disable ${YELLOW}Secure Boot${NC}\n"
echo -e "Quick steps:"
echo -e "Device Manager > Secure Boot Configuration > Attempt Secure Boot > Enter > Esc > Esc > Continue > Enter\n"
