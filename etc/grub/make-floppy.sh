#! /bin/sh

# Where is a floppy image located
KERNEL="/boot/RadiOS/radios.rdz"
DRIVE="x:"
MTOOLSRC="$HOME/.mtoolsrc"

# Start here
grep -q "drive $DRIVE" $MTOOLSRC && mcopy -o $KERNEL $DRIVE
