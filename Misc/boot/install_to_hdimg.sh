#! /bin/sh

if [ $1 ] ; then
    RDIR=$1
else
    RDIR="/mnt/radios/"
fi

# To use this script, add to your /etc/fstab something like this:
# hd-30M.img	/mnt/loop-fat	vfat	noauto,user,loop,offset=0x7E00	0   0

EMUDIR=~/emu
HDIMG=hd-30M.img
grep -q "$HDIMG" /etc/fstab || exit
MNTDIR=`grep "$HDIMG" /etc/fstab | awk '{ print $2 }'`

(cd $EMUDIR && mount $HDIMG)
(cd $RDIR && tar --exclude lost+found -cf - * | tar -C $MNTDIR/radios/ -xf - )
(cd $EMUDIR && umount $HDIMG)
