#! /bin/sh

# Where a floppy image is located
WDIR="/boot/RadiOS"

( cd $WDIR && mount floppy.flp && cp radios.rdz /mnt/loop-floppy &&
  umount floppy.flp
  sync )
