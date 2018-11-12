#!/bin/sh

# assumes ostree repo at /mnt/host/tree

usage() {
	echo "create_disk -d disk -o ostree"
}

rc=0
TEMP=$(getopt -o "d:o:" --long "disk:,ostree:" -- "$@") || rc=$?
if [ "$rc" -ne 0 ]; then
	usage
	exit 1
fi

eval set -- "$TEMP"

while :
do
	case "$1" in
		"-d"|"--disk")
			shift
			disk="$1"
			shift
			;;
		"-o"|"--ostree")
			shift
			ostree="$1"
			shift
			;;
		--)
			shift
			break
			;;
		*)
			echo "Error parsing args"
			usage
			exit 1
			;;
	esac
done

[ -z "$disk" ] || [ -z "$ostree" ] && {
	usage
	exit 1
}

set -e

script_dir=$(dirname $(readlink -f "$0"))
export IGNITION_SYSTEM_CONFIG_DIR=$(mktemp -d)

# render the config with the correct disk filled out
cat "$script_dir/disk_layout.ign" | sed "s#/\$DISK#$disk#" > "$IGNITION_CONFIG_DIR/config.ign"

# partition and create fs
ignition --stage disks --oem file --config-cache /dev/null

# mount the partitions
mkdir -p rootfs/boot
mount ${disk}p3 rootfs
mount ${disk}p1 rootfs/boot

# init the ostree
ostree admin init-fs rootfs
ostree pull-local $ostree --repo rootfs/ostree/repo
ostree admin os-init fedora-coreos --sysroot rootfs
ref=$(ostree ref --repo rootfs/ostree/repo)
ostree admin deploy "$ref" --sysroot rootfs --os fedora-coreos


# install bios grub (mostly lifted from the container linux scripts)
grub-install \
	--target i386-pc \
	--compress xz \
	--directory $grubdir/i386-pc \
	--boot-directory rootfs/boot \
	--verbose

# install uefi grub
# TODO
