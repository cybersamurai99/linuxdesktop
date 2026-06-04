#!/usr/bin/env bash

# Exit immediately if a command exits with a non-zero status
set -euo pipefail

# ==============================================================================
# CONFIGURATION VARIABLES
# ==============================================================================
# Define the raw physical HDD partitions for your RAID array
# (Change these placeholders to your actual drive partitions when they arrive)
HDD_DISKS=("/dev/sda1" "/dev/sda2" "/dev/sda3") 

RAID_LEVEL="5"                      # RAID level (e.g., 5 for RAID5 parity)
HDD_ARRAY="/dev/md0"                # Target path for the new RAID array
SSD_PARTITION="/dev/nvme0n1p2"      # Your fast SSD cache partition
VG_NAME="vg_nas"                    # Desired Volume Group Name
LV_DATA_NAME="lv_storage"           # Name for the slow HDD data volume
LV_CACHE_NAME="lv_cache_pool"       # Name for the fast SSD cache volume
MOUNT_POINT="/mnt/nas_share"        # Final mount point for the XFS filesystem
CACHE_MODE="writeback"              # Options: "writeback" (fast) or "writethrough" (safe)

# ==============================================================================
# SANITY CHECKS
# ==============================================================================

# Ensure script is run as root
if [[ $EUID -ne 0 ]]; then
   echo "Error: This script must be run as root." >&2
   exit 1
fi

# Ensure required binaries are available
for cmd in mdadm pvcreate vgcreate lvcreate lvconvert mkfs.xfs wipefs; do
    if ! command -v "$cmd" &> /dev/null; then
        echo "Error: Required command '$cmd' is missing. Please install mdadm, lvm2, and xfsprogs." >&2
        exit 1
    fi
done

# Warning block
echo "========================================================================"
echo " WARNING: THIS WILL WIPE ALL DATA ON THE FOLLOWING DRIVES: "
for disk in "${HDD_DISKS[@]}"; do
    echo "   - $disk"
done
echo "   - $SSD_PARTITION"
echo " And will create a new RAID array at $HDD_ARRAY"
echo "========================================================================"
read -rp "Are you absolutely sure you want to proceed? (y/N): " confirm
if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
    echo "Aborting script."
    exit 0
fi

# ==============================================================================
# EXECUTION STEPS
# ==============================================================================

# Check if mdadm array already exists/is active
if [ -b "$HDD_ARRAY" ] || mdadm --detail "$HDD_ARRAY" &>/dev/null; then
    echo "Error: Device $HDD_ARRAY already exists or is active. Stop it or clear it manually." >&2
    exit 1
fi

echo "Step 1: Wiping existing signatures on target devices..."
for disk in "${HDD_DISKS[@]}"; do
    wipefs -a "$disk"
done
wipefs -a "$SSD_PARTITION"

echo "Step 2: Creating mdadm RAID array..."
# Computes array length dynamically based on the configuration variable array length
mdadm --create --verbose "$HDD_ARRAY" \
      --level="$RAID_LEVEL" \
      --raid-devices="${#HDD_DISKS[@]}" \
      "${HDD_DISKS[@]}"

echo "Step 3: Saving mdadm configuration..."
# Update mdadm.conf so the array assembles predictably on next boot
mkdir -p /etc/mdadm
if [ -f /etc/mdadm/mdadm.conf ]; then
    cp /etc/mdadm/mdadm.conf /etc/mdadm/mdadm.conf.bak
fi
mdadm --detail --scan >> /etc/mdadm/mdadm.conf

echo "Step 4: Initializing Physical Volumes (PVs)..."
pvcreate "$HDD_ARRAY"
pvcreate "$SSD_PARTITION"

echo "Step 5: Creating Volume Group ($VG_NAME)..."
vgcreate "$VG_NAME" "$HDD_ARRAY" "$SSD_PARTITION"

echo "Step 6: Creating data Logical Volume on HDDs (100% of HDD space)..."
lvcreate -l 100%FREE -n "$LV_DATA_NAME" "$VG_NAME" "$HDD_ARRAY"

echo "Step 7: Creating cache Logical Volume on SSD (100% of SSD space)..."
lvcreate -l 100%FREE -n "$LV_CACHE_NAME" "$VG_NAME" "$SSD_PARTITION"

echo "Step 8: Converting volumes into an LVM Cache Pool ($CACHE_MODE mode)..."
lvconvert --type cache \
          --cachepool "$VG_NAME/$LV_CACHE_NAME" \
          "$VG_NAME/$LV_DATA_NAME" \
          --config "allocation/cache_mode=\"$CACHE_MODE\""

echo "Step 9: Formatting the hybrid logical volume with XFS..."
mkfs.xfs "/dev/$VG_NAME/$LV_DATA_NAME"

echo "Step 10: Configuring the mount point..."
mkdir -p "$MOUNT_POINT"

# Prevent duplicate entries in fstab if running script multiple times
FSTAB_ENTRY="/dev/$VG_NAME/$LV_DATA_NAME   $MOUNT_POINT   xfs   defaults,noatime,nodiratime   0   2"
if ! grep -q "/dev/$VG_NAME/$LV_DATA_NAME" /etc/fstab; then
    echo "Adding entry to /etc/fstab..."
    echo "$FSTAB_ENTRY" >> /etc/fstab
else
    echo "/etc/fstab already contains an entry for this volume. Skipping append."
fi

echo "Step 11: Mounting the cached filesystem..."
mount -a

# ==============================================================================
# VERIFICATION
# ==============================================================================
echo "========================================================================"
echo " SUCCESS: RAID array assembled and LVM storage pool initialized."
echo " Mount point active at: $MOUNT_POINT"
echo "========================================================================"
echo "Mdadm Status:"
mdadm --detail "$HDD_ARRAY" | grep -E "State|Raid Devices|Active Devices"
echo "------------------------------------------------------------------------"
echo "Current LVM Cache Status:"
lvs -a -o +devices,cache_read_hits,cache_read_misses,cache_write_hits,cache_write_misses "$VG_NAME"