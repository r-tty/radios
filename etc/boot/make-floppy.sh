#! /bin/sh

BOOTDIR="/boot/RadiOS"
KERNEL="rmk586.rdm.gz"
MODULES="libc.rdm taskman.rdx"

DRIVE="x:"
MTOOLSRC="$HOME/.mtoolsrc"

# Start here
grep -q "drive $DRIVE" $MTOOLSRC && (
    cd $BOOTDIR
    mcopy -o $KERNEL $DRIVE
    cd modules
    mcopy -o $MODULES $DRIVE/modules
)
