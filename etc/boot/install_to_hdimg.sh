#! /bin/sh

# To use this script, add to your /etc/fstab something like this:
# hd-30M.img	/mnt/loop-fat	vfat	noauto,user,loop,offset=0x7E00	0   0

EMUDIR=~/emu
HDIMG=hd-30M.img
MNTDIR=`grep "$HDIMG" /etc/fstab | cut -f2`

KERNEL="radios.rdz"
MODULES="startup.rdl.gz"

(cd $EMUDIR && mount $HDIMG)
cp $KERNEL $MNTDIR/boot/radios
cp $MODULES $MNTDIR/boot/radios
(cd $EMUDIR && umount $HDIMG)
