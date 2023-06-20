#!/bin/bash
sudo swapoff -a && sudo rm -f /mnt/swapfile
sudo fallocate -l $(expr $(expr $(df --block-size=1024 --output=avail / | tail -1 ) - 1048576) \* 1024) /root.img
export ROOT_LOOP_DEVNAME=$(sudo losetup -Pf --show /root.img)
sudo pvcreate -f $ROOT_LOOP_DEVNAME
sudo fallocate -l $(expr $(expr $(df --block-size=1024 --output=avail /mnt | tail -1) - 102400) \* 1024) /mnt/mnt.img
export MNT_LOOP_DEVNAME=$(sudo losetup -Pf --show /mnt/mnt.img)
sudo pvcreate -f $MNT_LOOP_DEVNAME
sudo vgcreate vgstorage $ROOT_LOOP_DEVNAME $MNT_LOOP_DEVNAME
sudo lvcreate -n lvstorage -l 100%FREE vgstorage
export LV_DEVNAME=$(sudo lvscan | awk -F "'" '{print $2}')
sudo mkfs.btrfs -L combinedisk $LV_DEVNAME
sudo mount -o compress=zstd $LV_DEVNAME $GITHUB_WORKSPACE
sudo chown -R runner:runner $GITHUB_WORKSPACE
df -hT $GITHUB_WORKSPACE
sudo btrfs filesystem usage $GITHUB_WORKSPACE
