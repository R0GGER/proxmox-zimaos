#!/bin/bash

# github.com/R0GGER/proxmox-zimaos
# bash -c "$(wget -qLO - https://raw.githubusercontent.com/R0GGER/proxmox-zimaos/refs/heads/main/zimaos_zimacube_installer-iso.sh)"

# Default ZimaOS version
DEFAULT_VERSION="latest"
FALLBACK_VERSION="1.5.4"

# Variables
ISO_STORAGE=$(pvesm status --content iso 2>/dev/null | awk 'NR==2 {print $1}')
ISO_STORAGE=${ISO_STORAGE:-local}
VERSION=""
RELEASE_TAG=""
URL=""
IMAGE=""
IMAGE_VOLID=""
IMAGE_PATH=""

# Colors
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
ORANGE='\033[38;5;208m'
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
    if qm status $1 >/dev/null 2>&1; then
        echo -e "${RED}Error: VMID $1 already exists${NC}"
        exit 1
    fi
}

check_volume() {
    if ! pvesm status | grep -q "^$1"; then
        echo -e "${RED}Error: Storage volume $1 does not exist${NC}"
        exit 1
    fi
}

get_latest_release_tag() {
    local latest_tag
    latest_tag=$(wget -qO- "https://api.github.com/repos/IceWhaleTech/ZimaOS/releases/latest" | sed -n 's/.*"tag_name":[[:space:]]*"\([^"]*\)".*/\1/p' | head -n1)
    if [ -z "$latest_tag" ]; then
        echo -e "${RED}Error: Could not determine latest ZimaOS release tag from GitHub.${NC}"
        exit 1
    fi
    echo "$latest_tag"
}

clear
echo -e "${YELLOW}=== Proxmox ZimaOS Installer ===${NC}"
echo -e "This script will create a new VM and attach the ZimaOS installer ISO.\n"

read -e -i "$DEFAULT_VERSION" -p "ZimaOS version [${DEFAULT_VERSION} or e.g. ${FALLBACK_VERSION}]: " VERSION_INPUT
VERSION_INPUT=${VERSION_INPUT:-$DEFAULT_VERSION}

if [[ "${VERSION_INPUT,,}" == "latest" ]]; then
    RELEASE_TAG=$(get_latest_release_tag)
    VERSION="${RELEASE_TAG#v}"
else
    RELEASE_TAG="$VERSION_INPUT"
    VERSION="${VERSION_INPUT#v}"
fi

URL="https://github.com/IceWhaleTech/ZimaOS/releases/download/$RELEASE_TAG/zimaos-x86_64-${VERSION}_installer.iso"
IMAGE=$(basename "$URL")
IMAGE_VOLID="$ISO_STORAGE:iso/$IMAGE"

echo -e "${GREEN}Selected version: $VERSION${NC}\n"

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


read -p "Name [ZimaOS]: " VM_NAME
VM_NAME=${VM_NAME:-ZimaOS}

DISK_STORAGE="local-lvm"
check_volume $DISK_STORAGE

# Disk Size
while true; do
    read -p "Disk Size in GB [32]: " DISK_SIZE
    DISK_SIZE=${DISK_SIZE:-32}
    validate_number $DISK_SIZE
    if [[ $DISK_SIZE -gt 0 ]]; then
        break
    fi
    echo -e "${RED}Error: Disk size must be greater than 0${NC}"
done

# CPU Cores
while true; do
    read -p "CPU Cores [2]: " CPU_CORES
    CPU_CORES=${CPU_CORES:-2}
    validate_number $CPU_CORES
    if [[ $CPU_CORES -gt 0 ]]; then
        break
    fi
    echo -e "${RED}Error: CPU cores must be greater than 0${NC}"
done

# Memory
while true; do
    read -p "Memory in MB [2048]: " MEMORY_MB
    MEMORY_MB=${MEMORY_MB:-2048}
    validate_number $MEMORY_MB
    if [[ $MEMORY_MB -gt 0 ]]; then
        break
    fi
    echo -e "${RED}Error: Memory must be greater than 0${NC}"
done

check_volume $ISO_STORAGE
IMAGE_PATH=$(pvesm path "$IMAGE_VOLID" 2>/dev/null)
if [ -z "$IMAGE_PATH" ]; then
    echo -e "${RED}Error: Could not determine path for ISO storage '$ISO_STORAGE'.${NC}"
    exit 1
fi

echo -e "\n${GREEN}Creating VM with the following settings:${NC}"
echo -e "VM ID: ${YELLOW}$VMID${NC}"
echo -e "Name: ${YELLOW}$VM_NAME${NC}"
echo -e "BIOS: ${YELLOW}OVMF (UEFI)${NC}"
echo -e "Disk storage: ${YELLOW}$DISK_STORAGE${NC}"
echo -e "EFI storage: ${YELLOW}$DISK_STORAGE${NC}"
echo -e "Disk Size: ${YELLOW}${DISK_SIZE}GB${NC}"
echo -e "CPU Cores: ${YELLOW}$CPU_CORES${NC}"
echo -e "Memory: ${YELLOW}${MEMORY_MB}MB${NC}"
echo -e "ISO storage: ${YELLOW}$ISO_STORAGE${NC}\n"

read -p "Continue? (y/n): " CONFIRM
if [[ $CONFIRM != [yY] ]]; then
    echo -e "${YELLOW}Cancelled by user.${NC}"
    exit 0
fi

# Create VM
echo -e "\n${YELLOW}Creating VM...${NC}"
qm create $VMID --name "$VM_NAME" --memory $MEMORY_MB --cores $CPU_CORES --bios ovmf --ostype l26 --machine q35 --scsihw virtio-scsi-pci --scsi0 "$DISK_STORAGE:${DISK_SIZE}" --net0 virtio,bridge=vmbr0
if [ $? -ne 0 ]; then
    echo -e "${RED}Error: Failed to create VM.${NC}"
    exit 1
fi

# Create EFI disk on same storage as VM disk
echo -e "\n${YELLOW}Creating EFI disk on $DISK_STORAGE...${NC}"
qm set $VMID --efidisk0 "$DISK_STORAGE:0,efitype=4m"
if [ $? -ne 0 ]; then
    echo -e "${RED}Error: Failed to create EFI disk.${NC}"
    exit 1
fi

mkdir -p "$(dirname "$IMAGE_PATH")"

# Download
echo -e "\n${YELLOW}Downloading the installer ISO...${NC}"
wget -q --show-progress -O "$IMAGE_PATH" "$URL"
if [ $? -ne 0 ]; then
    echo -e "${RED}Error: Failed to download the installer ISO.${NC}"
    exit 1
fi

# Attach ISO as CD/DVD drive
echo -e "\n${YELLOW}Attaching installer ISO as CD/DVD (ide2)...${NC}"
qm set $VMID --ide2 "$IMAGE_VOLID,media=cdrom"
if [ $? -ne 0 ]; then
    echo -e "${RED}Error: Failed to attach the installer ISO.${NC}"
    rm -f "$IMAGE_PATH" 
    exit 1
fi

# Set boot order to boot installer first
echo -e "\n${YELLOW}Setting boot order to installer ISO (ide2)...${NC}"
qm set $VMID --boot order=ide2
if [ $? -ne 0 ]; then
    echo -e "${RED}Error: Failed to set boot order.${NC}"
    exit 1
fi

# Get started
echo -e "\n${GREEN}Success! ZimaOS installer ISO has been added to VM $VMID${NC}\n"
echo -e "${ORANGE}IMPORTANT:${NC} Start the VM and run the installer. After installation, ${ORANGE}\033[1mSTOP${NC} the VM and detach the ISO (set CD/DVD to 'Do not use any media').\n"

