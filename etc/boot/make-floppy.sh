#! /bin/sh

BOOTDIR="/boot/RadiOS"
KERNEL="radios.rdz"
MODULES="startup.rdl.gz"

DRIVE="x:"
MTOOLSRC="$HOME/.mtoolsrc"

# Start here
grep -q "drive $DRIVE" $MTOOLSRC && (
    cd $BOOTDIR
    mcopy -o $KERNEL $DRIVE
    mcopy -o $MODULES $DRIVE
)
