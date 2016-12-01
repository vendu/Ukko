#!/bin/sh

#DEBUGFLAGS="-s -S"
DEBUGFLAGS=""

make &&
qemu-system-i386 $DEBUGFLAGS\
    -drive file=bootdisk.img,format=raw,index=0,if=floppy \
    -boot order=a
