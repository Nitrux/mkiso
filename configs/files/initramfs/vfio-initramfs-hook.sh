#!/bin/sh
set -e

PREREQ=""

prereqs()
{
        echo "$PREREQ"
}

case $1 in
# get pre-requisites
prereqs)
        prereqs
        exit 0
        ;;
esac

# shellcheck source=/dev/null
. /usr/share/initramfs-tools/hook-functions

# Copy the script to /usr/sbin/ in the initramfs
copy_exec /usr/bin/vfio-override /bin
