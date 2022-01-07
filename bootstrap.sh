#! /bin/bash

set -xe

export LANG=C
export LC_ALL=C
export SUDO_FORCE_REMOVE=yes

puts () { printf "\n\n --- %s\n" "$*"; }


#	Wrap APT commands in functions.

add_nitrux_key_repo () { curl -L https://packagecloud.io/nitrux/repo/gpgkey | apt-key add -; }
add_nitrux_key_compat () { curl -L https://packagecloud.io/nitrux/compat/gpgkey | apt-key add -; }
add_nitrux_key_testing () { curl -L https://packagecloud.io/nitrux/testing/gpgkey | apt-key add -; }
add_repo_keys () { apt-key adv --keyserver keyserver.ubuntu.com --recv-keys $@; }
appstream_refresh_force () { appstreamcli refresh --force; }
autoremove () { apt -yy autoremove $@; }
clean_all () { apt clean && apt autoclean; }
dist_upgrade () { apt -yy dist-upgrade $@; }
download () { apt download $@; }
dpkg_force_install () { dpkg --force-all -i $@; }
dpkg_force_remove () { /usr/bin/dpkg --remove --no-triggers --force-remove-essential --force-bad-path $@; }
dpkg_install () { dpkg -i $@; }
fix_install () { apt -yy --fix-broken install $@; }
fix_install_no_recommends () { apt -yy --fix-broken install --no-install-recommends $@; }
hold () { apt-mark hold $@; }
install () { apt -yy install --no-install-recommends $@; }
install_downgrades () { apt -yy install --no-install-recommends --allow-downgrades $@; }
install_downgrades_hold () { apt -yy install --no-install-recommends --allow-downgrades --allow-change-held-packages $@; }
install_hold () { apt -yy install --no-install-recommends $@ && apt-mark hold $@; }
list_installed_apt () { apt list --installed; }
list_installed_dpkg () { dpkg --list '*'; }
list_number_pkgs () { dpkg-query -f '${binary:Package}\n' -W | wc -l; }
list_pkgs_size () { dpkg-query --show --showformat='${Installed-Size}\t${Package}\n' | sort -rh | head -25 | awk '{print $1/1024, $2}'; }
list_upgrade () { apt list --upgradable; }
only_upgrade () { apt -yy install --no-install-recommends --only-upgrade $@; }
pkg_policy () { apt-cache policy $@; }
pkg_search () { apt-cache search $@; }
purge () { apt -yy purge --remove $@; }
remove_dpkg () { /usr/bin/rdpkg; }
remove_keys () { apt-key del $@; }
unhold () { apt-mark unhold $@; }
update () { apt update; }
update_quiet () { apt -qq update; }
upgrade () { apt -yy upgrade $@; }
upgrade_downgrades () { apt -yy upgrade --allow-downgrades $@; }


puts "STARTING BOOTSTRAP."


# Check installed packages at start.

# list_installed_apt > list_installed_pkgs_start.txt
list_number_pkgs


#	Install basic packages.
#
#	Install extra packages.
#
#	SYSTEMD_RDEP_PKGS are packages that for one reason or the other do not get pulled when
#	the metapackages are installed, or, that require systemd to be present and can't be installed
#	from Devuan repositories, i.e., bluez, rng-tools so they have to be installed *before* installing
#	the rest of the packages.

puts "INSTALLING BASIC PACKAGES."

BASIC_PKGS='
	apt-transport-https
	apt-utils
	ca-certificates
	dhcpcd5
	gnupg2
'

EXTRA_PKGS='
	avahi-daemon
	curl
	efibootmgr
	squashfs-tools
'

SYSTEMD_RDEP_PKGS='
	user-setup
	ufw
'

update_quiet
install $BASIC_PKGS $EXTRA_PKGS $SYSTEMD_RDEP_PKGS


#	Hold misc. packages.

puts "HOLD MISC. PACKAGES."

HOLD_MISC_PKGS='
	cgroupfs-mount
	ssl-cert
'

hold $HOLD_MISC_PKGS


#	Add key for Nitrux repository.

puts "ADDING REPOSITORY KEYS."

add_nitrux_key_repo
add_nitrux_key_compat
add_nitrux_key_testing


#	Add key for Neon repository.
#	Add key for Devuan repositories #1.
#	Add key for Devuan repositories #2.
#	Add key for Ubuntu repositories #1.
#	Add key for Ubuntu repositories #2.

puts "INSTALLING REPOSITORY KEYS."

add_repo_keys \
	E6D4736255751E5D \
	94532124541922FB \
	BB23C00C61FC752C \
	3B4FE6ACC0B21F32 \
	871920D1991BC93C > /dev/null


#	Copy sources.list files.

puts "ADDING SOURCES FILES."

cp /configs/files/sources.list.nitrux /etc/apt/sources.list
cp /configs/files/sources.list.devuan.beowulf /etc/apt/sources.list.d/devuan-beowulf-repo.list
cp /configs/files/sources.list.devuan.daedalus /etc/apt/sources.list.d/devuan-daedalus-repo.list
cp /configs/files/sources.list.neon.user /etc/apt/sources.list.d/neon-user-repo.list
cp /configs/files/sources.list.focal /etc/apt/sources.list.d/ubuntu-focal-repo.list
cp /configs/files/sources.list.bionic /etc/apt/sources.list.d/ubuntu-bionic-repo.list

update_quiet


#	Block installation of some packages.

cp /configs/files/preferences /etc/apt/preferences


#	Add script to remove dpkg.

cp /configs/scripts/rdpkg /usr/bin/rdpkg


#	Add casper packages from bionic.
#
#	Remove bionic repo, we don't need it after.

puts "INSTALLING CASPER PACKAGES."

CASPER_PKGS='
	casper/bionic-updates
	lupin-casper/bionic
'

install $CASPER_PKGS

rm -r /etc/apt/sources.list.d/ubuntu-bionic-repo.list

update_quiet


#	Hold initramfs and casper packages.

INITRAMFS_CASPER_PKGS='
	casper
	lupin-casper
	initramfs-tools
	initramfs-tools-core
	initramfs-tools-bin
'

hold $INITRAMFS_CASPER_PKGS


#	Add elogind packages from Devuan.

puts "INSTALLING ELOGIND."

DEVUAN_ELOGIND_PKGS='
	elogind
	libelogind0
'

REMOVE_SYSTEMD_PKGS='
	libargon2-1
	libcryptsetup12
	libsystemd0
	systemd
	systemd-sysv
'

SYSTEMCTL_PKG='
	systemctl/focal
'

install $DEVUAN_ELOGIND_PKGS
purge $REMOVE_SYSTEMD_PKGS
install_hold $SYSTEMCTL_PKG


#	Use PolicyKit packages from Devuan.
#	Add NetworkManager and udisks2 from Devuan.
#	Add OpenRC as init.

puts "INSTALLING DEVUAN SYS PACKAGES."

DEVUAN_GLIB_PKGS='
	libglib2.0-data/daedalus
	libglib2.0-0/daedalus
	libglib2.0-bin/daedalus
	libglib2.0-dev-bin/daedalus
	libglib2.0-doc/daedalus
	
'

DEVUAN_SYS_PKGS='
	init-system-helpers
	initscripts
	libnm0
	libpolkit-agent-1-0/beowulf
	libpolkit-backend-1-0/beowulf
	libpolkit-backend-elogind-1-0/beowulf
	libpolkit-gobject-1-0/beowulf
	libpolkit-gobject-elogind-1-0/beowulf
	libsemanage-common/daedalus
	libsemanage2/daedalus
	libudisks2-0
	network-manager
	openrc
	policycoreutils
	policykit-1/beowulf
	startpar
	sysvinit-utils
	udisks2
'

install $DEVUAN_GLIB_PKGS 
install $DEVUAN_SYS_PKGS


#	Install base system metapackages.

puts "INSTALLING BASE FILES AND KERNEL."

NITRUX_BASE_PKGS='
	base-files=13.0.1+nitrux
	nitrux-minimal
	nitrux-standard
'

KERNEL_DRV_PKGS='
	nitrux-hardware-drivers
	linux-image-mainline-lts
'

install $NITRUX_BASE_PKGS
install $KERNEL_DRV_PKGS


#	Install NX Desktop metapackage.
#
#	Disallow dpkg to exclude translations affecting Plasma (see issues https://github.com/Nitrux/iso-tool/issues/48 and
#	https://github.com/Nitrux/nitrux-bug-tracker/issues/4).

puts "INSTALLING DESKTOP PACKAGES."

sed -i 's+path-exclude=/usr/share/locale/+#path-exclude=/usr/share/locale/+g' /etc/dpkg/dpkg.cfg.d/excludes

NX_DESKTOP_PKG='
	nx-desktop
'

MISC_KDE_PKGS='
	latte-dock
'

MISC_DESKTOP_PKGS='
	libcrypt1/trixie
	libcrypt-dev/trixie
	gir1.2-gtk-3.0/daedalus
'

PLYMOUTH_DAEDALUS_PKGS='
	libplymouth5/daedalus
	plymouth-label/daedalus
	plymouth-themes/daedalus
	plymouth/daedalus
	plymouth-x11/daedalus
'

install $NX_DESKTOP_PKG $MISC_KDE_PKGS $MISC_DESKTOP_PKGS $PLYMOUTH_DAEDALUS_PKGS


#	Install Nvidia driver.

NVIDIA_DRV_PKGS='
	libxnvctrl0
	nvidia-x11-config
'

install $NVIDIA_DRV_PKGS


# #	Upgrade, downgrade and install misc. packages.
# #
# #	Remove jammy repo, we don't need it after.

# cp /configs/files/sources.list.jammy /etc/apt/sources.list.d/ubuntu-jammy-repo.list

# puts "UPGRADING/DOWNGRADING/INSTALLING MISC. PACKAGES."

# UPGRADE_GLIBC_PKGS='

# '

# UPGRADE_MISC_PKGS='

# '

# INSTALL_MISC_PKGS='
# 	bash-completion
# 	busybox-static
# 	dosfstools
# 	iputils-ping
# 	linux-firmware
# 	linux-sound-base
# 	logrotate
# 	ltrace
# 	mailcap
# 	man-db
# 	manpages
# 	nano
# 	net-tools
# 	netcat-openbsd
# 	ntfs-3g
# 	whiptail
# '

# update_quiet
# only_upgrade $UPGRADE_GLIBC_PKGS $UPGRADE_MISC_PKGS 
# install $INSTALL_MISC_PKGS

# rm -r /etc/apt/sources.list.d/ubuntu-jammy-repo.list

# update_quiet


#	Add OpenRC configuration.

puts "INSTALLING OPENRC CONFIG."

OPENRC_CONFIG='
	openrc-config
'

install $OPENRC_CONFIG


#	Add live user.

puts "INSTALLING LIVE USER."

NX_LIVE_USER_PKG='
	nitrux-live-user-minimal
'

install $NX_LIVE_USER_PKG
autoremove
clean_all


#	WARNING:
#	No apt usage past this point.


#	Changes specific to this image. If they can be put in a package, do so.
#	FIXME: These fixes should be included in a package.

puts "ADDING MISC. FIXES."

cat /configs/files/casper.conf > /etc/casper.conf

ln -sv /usr/share/xsessions/jwm.desktop /usr/share/xsessions/plasma.desktop 

rm \
	/{vmlinuz,initrd.img,vmlinuz.old,initrd.img.old} || true

cp /configs/files/sound.conf /etc/modprobe.d/snd.conf

rm \
	/Applications/{app,appimaged} \
	/usr/bin/xterm

ln -svf $(which uxterm) /usr/bin/xterm

passwd --delete --lock root


#	Before removing dpkg, check the most oversized installed packages.

puts "SHOW LARGEST INSTALLED PACKAGES.."

list_pkgs_size
list_number_pkgs


#	Implement a new FHS.
#	FIXME: Replace with kernel patch and userland tool.

puts "CREATING NEW FHS."

mkdir -p \
	/Devices \
	/System/Binaries \
	/System/Binaries/Optional \
	/System/Configuration \
	/System/Libraries \
	/System/Mount/Filesystems \
	/System/Resources/Shared \
	/System/Server/Services \
	/System/Variable \
	/Users/

cp /configs/files/hidden /.hidden


#	Add persistence script.
#	Add fstab mount binds.

puts "UPDATING THE INITRAMFS."

cp /configs/scripts/hook-scripts.sh /usr/share/initramfs-tools/hooks/
cat /configs/scripts/persistence >> /usr/share/initramfs-tools/scripts/casper-bottom/05mountpoints_lupin
cat /configs/scripts/mounts >> /usr/share/initramfs-tools/scripts/casper-bottom/12fstab

update-initramfs -u


#	Remove Dash.
#	Remove APT.
#	Remove sudo as we're using doas link doas to sudo for downward compatibility.

puts "REMOVING DASH, CASPER AND APT."

REMOVE_DASH_CASPER_APT_PKGS='
	apt
	apt-transport-https
	apt-utils
	casper
	dash
	lupin-casper
	sudo
'

dpkg_force_remove $REMOVE_DASH_CASPER_APT_PKGS || true

ln -svf /usr/bin/mksh /bin/sh

dpkg_force_remove $REMOVE_DASH_CASPER_APT_PKGS

ln -svf $(which doas) /usr/bin/sudo


#	List installed packages at end.

# list_installed_dpkg > list_installed_pkgs_end.txt


#	WARNING:
#	No dpkg usage past this point.


#	Use script to remove dpkg.

puts "REMOVING DPKG."

remove_dpkg

rm -r /usr/bin/rdpkg


#	Check contents of /boot.
#	Check contents of OpenRC runlevels.
#	Check links to kernel and initramdisk.
#	Check contents of init.d and sddm.conf.d.
#	Check the setuid and groups of /usr/lib/dbus-1.0/dbus-daemon-launch-helper.
#	Check contents of /Applications.
#	Check that init system is not systemd.
#	Check that /bin/sh is in fact not Dash.
#	Check existence and contents of casper.conf, sddm.conf and sddm.conf.d.
#	Check that the VFIO driver is included in the intiramfs.


puts "PERFORM MANUAL CHECKS."

ls -lh \
	/boot \
	/etc/runlevels/{default,nonetwork,off,recovery,sysinit} \
	/{vmlinuz,initrd.img} \
	/etc/{init.d,sddm.conf.d} \
	/usr/lib/dbus-1.0/dbus-daemon-launch-helper \
	/Applications || true

stat \
	/sbin/init \
	/bin/sh

cat \
	/etc/{casper.conf,sddm.conf} \
	/etc/sddm.conf.d/kde_settings.conf


puts "EXITING BOOTSTRAP."
