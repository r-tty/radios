#! /bin/sh

# To use this script, add to your /etc/fstab something like this:
# hd-30M.img	/mnt/loop-fat	vfat	noauto,user,loop,offset=0x7E00	0   0

EMUDIR=~/emu
HDIMG=hd-30M.img
MNTDIR=`grep "$HDIMG" /etc/fstab | awk '{ print $2 }'`

KERNEL="rmk586.rdm.gz"
BLMS="libc.rdm taskman.rdx"

(cd $EMUDIR && mount $HDIMG)
cp $KERNEL $MNTDIR/boot/radios
(cd modules && install $BLMS $MNTDIR/boot/radios/modules)
(cd $EMUDIR && umount $HDIMG)
