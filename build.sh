#! /bin/sh

# -- Exit on errors.

set -e

# -- Update xorriso and grub.

xorriso='
http://mirrors.kernel.org/ubuntu/pool/universe/libi/libisoburn/xorriso_1.5.0-1build1_amd64.deb 
http://mirrors.kernel.org/ubuntu/pool/universe/libi/libisoburn/libisoburn1_1.5.0-1build1_amd64.deb 
http://mirrors.kernel.org/ubuntu/pool/universe/libb/libburn/libburn4_1.5.0-1_amd64.deb 
http://mirrors.kernel.org/ubuntu/pool/universe/libi/libisofs/libisofs6_1.5.0-1_amd64.deb 
http://mirrors.kernel.org/ubuntu/pool/main/r/readline/libreadline8_8.0-1_amd64.deb 
http://mirrors.kernel.org/ubuntu/pool/main/r/readline/readline-common_8.0-1_all.deb 
http://mirrors.kernel.org/ubuntu/pool/main/n/ncurses/libtinfo6_6.1+20181013-2ubuntu2_amd64.deb
http://mirrors.kernel.org/ubuntu/pool/main/g/grub2/grub-efi-amd64-bin_2.02-2ubuntu8.13_amd64.deb
http://mirrors.kernel.org/ubuntu/pool/main/g/grub2/grub-common_2.02-2ubuntu8.13_amd64.deb
http://mirrors.kernel.org/ubuntu/pool/main/g/grub2/grub2-common_2.02-2ubuntu8.13_amd64.deb
'

mkdir /latest_xorriso

for x in $xorriso; do
printf "$x"
    wget -q -P /latest_xorriso $x
done

dpkg -install /latest_xorriso/*.deb
dpkg /latest_xorriso -a
rm -r /latest_xorriso


# -- Prepare the directories for the build.

BUILD_DIR=$(mktemp -d)
ISO_DIR=$(mktemp -d)
OUTPUT_DIR=$(mktemp -d)

CONFIG_DIR=$PWD/configs


# -- The name of the ISO image.

IMAGE=nitrux-$(printf $TRAVIS_BRANCH | sed 's/master/stable/')-amd64
UPDATE_URL=http://repo.nxos.org:8000/$IMAGE.zsync


# -- Prepare the directory where the filesystem will be created.

wget -O base.tar.gz -q http://cdimage.ubuntu.com/ubuntu-base/releases/18.04/release/ubuntu-base-18.04.2-base-amd64.tar.gz
tar xf base.tar.gz -C $BUILD_DIR


# -- Populate $BUILD_DIR.

wget -qO /bin/runc https://raw.githubusercontent.com/Nitrux/runc/master/runc
chmod +x /bin/runc

cp -r configs $BUILD_DIR/

runc $BUILD_DIR bootstrap.sh || true

rm -rf $BUILD_DIR/configs


# -- Copy the kernel and initramfs to $ISO_DIR.

mkdir -p $ISO_DIR/boot

cp $(echo $BUILD_DIR/vmlinuz* | tr ' ' '\n' | sort | tail -n 1) $ISO_DIR/boot/kernel
cp $(echo $BUILD_DIR/initrd* | tr ' ' '\n' | sort | tail -n 1) $ISO_DIR/boot/initramfs


# -- Compress the root filesystem.

(while :; do sleep 300; printf "."; done) &

mkdir -p $ISO_DIR/casper
mksquashfs $BUILD_DIR $ISO_DIR/casper/filesystem.squashfs -comp xz -no-progress -b 1M


# -- Write the commit hash that generated the image.

printf "UPDATE_URL $UPDATE_URL" >> $ISO_DIR/.INFO
printf "\n" >> $ISO_DIR/.INFO
printf "VERSION ${TRAVIS_COMMIT:0:7}" >> $ISO_DIR/.INFO
printf "\n" >> $ISO_DIR/.INFO


# -- Generate the ISO image.

wget -qO /bin/mkiso https://raw.githubusercontent.com/Nitrux/mkiso/master/mkiso
chmod +x /bin/mkiso

git clone https://github.com/Nitrux/nitrux-grub-theme grub-theme

mkiso \
	-V "NITRUX" \
	-g $CONFIG_DIR/grub.cfg \
	-g $CONFIG_DIR/loopback.cfg \
	-t grub-theme/nitrux \
	$ISO_DIR $OUTPUT_DIR/$IMAGE


# -- Embed the update information in the image.

printf "zsync|$UPDATE_URL" | dd of=$OUTPUT_DIR/$IMAGE bs=1 seek=33651 count=512 conv=notrunc


# -- Calculate the checksum.

sha256sum $OUTPUT_DIR/$IMAGE > $OUTPUT_DIR/$IMAGE.sha256sum


# -- Generate the zsync file.

zsyncmake \
	$OUTPUT_DIR/$IMAGE \
	-u ${UPDATE_URL/.zsync} \
	-o $OUTPUT_DIR/$IMAGE.zsync


# -- Add .iso extension to file for redistribution.

cp $OUTPUT_DIR/$IMAGE $OUTPUT_DIR/$IMAGE.iso


# -- Upload the ISO image.

cd $OUTPUT_DIR

export SSHPASS=$DEPLOY_PASS

for f in *; do
    sshpass -e scp -q -o stricthostkeychecking=no $f $DEPLOY_USER@$DEPLOY_HOST:$DEPLOY_PATH
done
