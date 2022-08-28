#! /bin/bash

set -xe

export LANG=C
export LC_ALL=C
export DEBIAN_FRONTEND=noninteractive

puts () { printf "\n\n --- %s\n" "$*"; }

#	Wrap APT commands in functions.

source /configs/scripts/apt_funcs.sh


puts "STARTING BOOTSTRAP."


#	Block installation of some packages.

cp /configs/files/preferences /etc/apt/preferences


#	Install basic packages.

puts "ADDING BASIC PACKAGES."

CHROOT_BASIC_PKGS='
	apt-transport-https
	apt-utils
	appstream
	axel
	ca-certificates
	curl
	dhcpcd5
	dirmngr
	gnupg2
	libzstd-dev
	lz4
	zstd
'

update
install $CHROOT_BASIC_PKGS


#	Add key for Nitrux repository.

puts "ADDING REPOSITORY KEYS."

add_nitrux_key_repo
add_nitrux_key_compat
add_nitrux_key_testing


#	Copy repository sources.

puts "ADDING SOURCES FILES."

cp /configs/files/sources.list.nitrux /etc/apt/sources.list
cp /configs/files/sources.list.nitrux.testing /etc/apt/sources.list.d/nitrux-testing-repo.list
cp /configs/files/sources.list.debian.experimental /etc/apt/sources.list.d/debian-experimental-repo.list
cp /configs/files/sources.list.debian.unstable /etc/apt/sources.list.d/debian-unstable-repo.list

apt-key export 86A634D7 | gpg --dearmour -o /usr/share/keyrings/nitrux-repo.gpg
apt-key export 712260DE | gpg --dearmour -o /usr/share/keyrings/nitrux-compat.gpg
apt-key export EB1BEB0D | gpg --dearmour -o /usr/share/keyrings/nitrux-testing.gpg

update


#	Upgrade dpkg for zstd support.

UPGRADE_DPKG='
	dpkg=1.21.1ubuntu1
'

install_downgrades $UPGRADE_DPKG


#	Do dist-upgrade.

dist_upgrade


#	Add bootloader.
#
#	The GRUB2 packages from Debian do not work correctly with EFI.

puts "ADDING BOOTLOADER."

GRUB2_PKGS='
	grub-common/trixie
	grub-efi-amd64/trixie
	grub-efi-amd64-bin/trixie
	grub-efi-amd64-signed/trixie
	grub-pc-bin/trixie
	grub2-common/trixie
	libfreetype6/unstable
'

install $GRUB2_PKGS


#	Add packages for secure boot compatibility.

puts "ADDING SECURE BOOT COMPAT."

SB_SHIM_PKGS='
	sbsigntool/trixie
	shim-signed/trixie
	mokutil/trixie
'

install $SB_SHIM_PKGS


#	Add eudev, elogind, and systemctl to replace systemd and utilize other inits.
#
#	To remove systemd, we have to replace libsystemd0, udev, elogind and provide systemctl. However, neither of them
#	are available to install from other sources than Devuan except for systemctl.

add_repo_keys \
	541922FB \
	61FC752C > /dev/null

cp /configs/files/sources.list.devuan.beowulf /etc/apt/sources.list.d/devuan-beowulf-repo.list

update

puts "ADDING EUDEV AND ELOGIND."

DEVUAN_EUDEV_ELOGIND_PKGS='
	eudev
	elogind
'

REMOVE_SYSTEMD_PKGS='
	systemd
	systemd-sysv
	libsystemd0
'

SYSTEMCTL_STANDALONE_PKG='
	systemctl
'

install $DEVUAN_EUDEV_ELOGIND_PKGS
purge $REMOVE_SYSTEMD_PKGS
autoremove
install $SYSTEMCTL_STANDALONE_PKG

rm \
	/etc/apt/sources.list.d/devuan-beowulf-repo.list

remove_repo_keys \
	541922FB \
	61FC752C > /dev/null

update


#	Add OpenRC as init.

puts "ADDING OPENRC AS INIT."

OPENRC_INIT_PKGS='
	initscripts
	init-system-helpers
	openrc
	policycoreutils
	startpar
	sysvinit-utils
'

install $OPENRC_INIT_PKGS


#	Add casper.
#
#	It's worth noting that casper isn't available anywhere but Ubuntu.
#	Debian doesn't use it; it uses live-boot, live-config, et. al.

puts "ADDING CASPER."

CASPER_DEPS_PKGS='
	casper/trixie
	initramfs-tools/trixie
	initramfs-tools-bin/trixie
	initramfs-tools-core/trixie
'

install_downgrades $CASPER_DEPS_PKGS


#	Hold initramfs and casper packages.

INITRAMFS_CASPER_PKGS='
	casper
	initramfs-tools
	initramfs-tools-core
	initramfs-tools-bin
'

hold $INITRAMFS_CASPER_PKGS


#	Add kernel.

add_repo_keys \
	86F7D09EE734E623 > /dev/null

cp /configs/files/sources.list.xanmod /etc/apt/sources.list.d/xanmod-repo.list

update

puts "ADDING KERNEL."

MAINLINE_KERNEL_PKG='
	linux-image-xanmod-edge
	libcrypt-dev/trixie
	libcrypt1/trixie
'

install_downgrades $MAINLINE_KERNEL_PKG

rm \
	/etc/apt/sources.list.d/xanmod-repo.list

remove_repo_keys \
	86F7D09EE734E623 > /dev/null

update


#	Add Plymouth.
#
#	The version of Plymouth that is available from Debian requires systemd and udev.
#	To avoid this requirement, we will use the package from Devuan (daedalus) that only requires udev (eudev).

puts "ADDING PLYMOUTH."

add_repo_keys \
	541922FB \
	61FC752C > /dev/null

cp /configs/files/sources.list.devuan.daedalus /etc/apt/sources.list.d/devuan-daedalus-repo.list

update

DEVUAN_PLYMOUTH_PKGS='
	plymouth/daedalus
	plymouth-label/daedalus
	plymouth-x11/daedalus
'

install $DEVUAN_PLYMOUTH_PKGS

rm \
	/etc/apt/sources.list.d/devuan-daedalus-repo.list

remove_repo_keys \
	541922FB \
	61FC752C > /dev/null

update


#	Adding PolicyKit packages from Devuan.
#
#	Since we're using elogind to replace logind, we need to add the matching PolicyKit packages.
#
#	Strangely, the complete stack is only available in beowulf but not in chimaera or daedalus.

puts "ADDING POLICYKIT ELOGIND COMPAT."

add_repo_keys \
	541922FB \
	61FC752C > /dev/null

cp /configs/files/sources.list.devuan.beowulf /etc/apt/sources.list.d/devuan-beowulf-repo.list

update

DEVUAN_POLKIT_PKGS='
	libpam-elogind/beowulf
	libpolkit-agent-1-0/beowulf
	libpolkit-backend-elogind-1-0/beowulf
	libpolkit-gobject-1-0/beowulf
	libpolkit-gobject-elogind-1-0/beowulf
	policykit-1/beowulf
'

install_downgrades $DEVUAN_POLKIT_PKGS

rm \
	/etc/apt/sources.list.d/devuan-beowulf-repo.list

remove_repo_keys \
	541922FB \
	61FC752C > /dev/null

update


#	Add misc. Devuan packages.
#
#	The network-manager package that is available in Debian does not have an init script compatible with OpenRC.
#	so we use the package from Devuan instead.
#
#	Prioritize installing packages from daedalus over chimaera, unless the package only exists in ceres.

puts "ADDING DEVUAN MISC. PACKAGES."

add_repo_keys \
	541922FB \
	61FC752C > /dev/null

cp /configs/files/sources.list.devuan.daedalus /etc/apt/sources.list.d/devuan-daedalus-repo.list

update

MISC_DEVUAN_DAEDALUS_PKGS='
	network-manager/daedalus
'

install $MISC_DEVUAN_DAEDALUS_PKGS

rm \
	/etc/apt/sources.list.d/devuan-daedalus-repo.list

remove_repo_keys \
	541922FB \
	61FC752C > /dev/null

update


#	Add Nitrux meta-packages.
#
#	31/05/22 - Once again the package 'broadcom-sta-dkms' is broken with the latest kernel 5.18.

puts "ADDING NITRUX BASE."

NITRUX_BASE_PKGS='
	base-files=13.1.17+nitrux-legacy
	nitrux-minimal-legacy
	nitrux-standard-legacy
'

NITRUX_HW_PKGS='
	nitrux-hardware-drivers-legacy
'

install $NITRUX_BASE_PKGS $NITRUX_HW_PKGS


#	Add Nvidia drivers or Nouveau.
#
#	The package nouveau-firmware isn't available in Debian but only in Ubuntu.
#
#	The Nvidia proprietary driver can't be installed alongside Nouveau.
#
#	To install it replace the Nouveau packages with the Nvidia counterparts.

puts "ADDING NVIDIA DRIVERS/NOUVEAU FIRMWARE."

NVIDIA_DRV_PKGS='
	xserver-xorg-video-nouveau
	nouveau-firmware
'

install $NVIDIA_DRV_PKGS


#	Add NX Desktop meta-package.
#
#	Use MISC_DESKTOP_PKGS to add packages to test. If tests are positive, add to the appropriate meta-package.
#
#	Use the KDE Neon repository to provide the latest stable release of Plasma and KF5.

add_repo_keys \
	55751E5D > /dev/null

cp /configs/files/sources.list.neon.user /etc/apt/sources.list.d/neon-user-repo.list

update

puts "ADDING NX DESKTOP."

NX_DESKTOP_PKG='
	nx-desktop-legacy
'

MISC_DESKTOP_PKGS='
	cryptsetup
	cryptsetup-initramfs
	dialog
	dmsetup
	keyutils
	nohang
	vkbasalt
'

install_downgrades $NX_DESKTOP_PKG $MISC_DESKTOP_PKGS

rm \
	/etc/apt/sources.list.d/neon-user-repo.list

remove_repo_keys \
	55751E5D > /dev/null

update


#	Add Calamares.
#
#	The package from KDE Neon is compiled against libkpmcore12 (22.04) and libboost-python1.71.0 from 
#	Ubuntu which provides the virtual package libboost-python1.71.0-py38. The package from Debian doesn't 
#	offer this virtual dependency.

puts "ADDING CALAMARES INSTALLER."

add_repo_keys \
	55751E5D > /dev/null

cp /configs/files/sources.list.neon.user /etc/apt/sources.list.d/neon-user-repo.list

update


CALAMARES_PKGS='
	efibootmgr
	calamares
	calamares-qml-settings-nitrux
	dosfstools
	libboost-python1.71.0/trixie
	squashfs-tools
'

install $CALAMARES_PKGS

rm \
	/etc/apt/sources.list.d/neon-user-repo.list

remove_repo_keys \
	55751E5D > /dev/null

update


#	Upgrade MESA packages.

puts "UPDATING MESA."

MESA_GIT_PKGS='
	mesa-git
'

MESA_LIBS_PKGS='
	libdrm-amdgpu1
	libdrm-common
	libdrm-intel1
	libdrm-nouveau2
	libdrm-radeon1
	libdrm2
	libegl-mesa0
	libgbm1
	libgl1-mesa-dri
	libglapi-mesa
	libglx-mesa0
	libxatracker2
	mesa-va-drivers
	mesa-vdpau-drivers
	mesa-vulkan-drivers
'

install $MESA_GIT_PKGS
only_upgrade_force_overwrite $MESA_LIBS_PKGS


#	Add OpenRC configuration.
#
#	Due to how the upstream openrc package "works," we need to put this package at the end of the build process.
#	Otherwise, we end up with an unbootable system.
#
#	See https://github.com/Nitrux/openrc-config/issues/1

puts "ADDING OPENRC CONFIG."

OPENRC_CONFIG='
	openrc-config
'

install $OPENRC_CONFIG


#	Remove sources used to build the root.

puts "REMOVE BUILD SOURCES."

rm \
	/etc/apt/preferences \
	/etc/apt/sources.list.d/* \
	/usr/share/keyrings/nitrux-repo.gpg \
	/usr/share/keyrings/nitrux-compat.gpg

update


#	Update Appstream cache.

clean_all
update
appstream_refresh_force


#	Add repository configuration.

puts "ADDING REPOSITORY SETTINGS."

NX_REPO_PKG='
	nitrux-repositories-config
'

install $NX_REPO_PKG


#	WARNING:
#	No apt usage past this point.


#	Changes specific to this image. If they can be put in a package, do so.
#	FIXME: These fixes should be included in a package.

puts "ADDING MISC. FIXES."

rm \
	/etc/default/grub \
	/etc/casper.conf

cat /configs/files/grub > /etc/default/grub
cat /configs/files/casper.conf > /etc/casper.conf

rm \
	/boot/{vmlinuz,initrd.img,vmlinuz.old,initrd.img.old} || true

cat /configs/files/motd > /etc/motd

printf '%s\n' fuse nouveau amdgpu >> /etc/modules

cat /configs/files/adduser.conf > /etc/adduser.conf


#	Generate initramfs.

puts "UPDATING THE INITRAMFS."

update-initramfs -c -k all


#	Before removing dpkg, check the most oversized installed packages.

puts "SHOW LARGEST INSTALLED PACKAGES.."

list_pkgs_size
list_number_pkgs
list_installed_pkgs


#	WARNING:
#	No dpkg usage past this point.


puts "PERFORM MANUAL CHECKS."

ls -lh \
	/boot \
	/etc/runlevels/{boot,default,nonetwork,off,recovery,shutdown,sysinit} \
	/{vmlinuz,initrd.img} \
	/etc/{init.d,sddm.conf.d} \
	/usr/lib/dbus-1.0/dbus-daemon-launch-helper \
	/Applications || true

stat /sbin/init \
	/bin/sh \
	/bin/dash \
	/bin/bash

cat \
	/etc/{casper.conf,sddm.conf,modules} \
	/etc/default/grub \
	/etc/environment \
	/etc/adduser.conf


puts "EXITING BOOTSTRAP."
