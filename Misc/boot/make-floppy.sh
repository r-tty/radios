#! /bin/sh

BOOTDIR="/boot/RadiOS"
KERNEL="rmk586.rdm.gz"
MODULES="libc.rdm taskman.rdm monitor.rdm console.rdx x-ray.rdx"

DRIVE="x:"
DIR="boot/radios"
MTOOLSRC="$HOME/.mtoolsrc"

# Start here
grep -q "drive $DRIVE" $MTOOLSRC && (
    cd $BOOTDIR
    mcopy -o $KERNEL $DRIVE/$DIR
    cd modules
    mcopy -o $MODULES $DRIVE/$DIR/modules
)
