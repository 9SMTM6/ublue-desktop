#!/bin/bash

set -ouex pipefail

# Build/install flow follows grandpares' bazzite-it87 image build:
# https://github.com/grandpares/ublue-image/blob/main/Containerfile.bazzite.unsigned
# https://github.com/grandpares/ublue-image/blob/main/build.bazzite.sh
# https://github.com/grandpares/ublue-image/blob/main/postbuild.sh

# Build the out-of-tree it87 driver against the exact kernel shipped in this
# image. `uname -r` would report the build host's kernel, so use the kernel
# package installed in the image instead.
KERNEL="$(rpm -q kernel --queryformat '%{VERSION}-%{RELEASE}.%{ARCH}')"

IT87_REPO="https://github.com/frankcrawford/it87.git"
# Renovate tracks this pin against upstream master; see .github/renovate.json5.
IT87_COMMIT="51341bae34c332aa4e989fe12f5a09cbda0b79a9"

# Upstream builds a module named it87, which collides with the in-tree driver.
# Build the same source as it87-extras instead, following grandpares/it87:
# https://github.com/grandpares/it87/blob/bef2dd79af1c2d711e4f3d00df4f32b59a9a9669/Makefile
IT87_MAKE_ARGS=(
    "TARGET=${KERNEL}"
    "DRIVER=it87-extras"
    "it87-extras-objs=it87.o"
)

if [[ ! -d "/usr/src/kernels/${KERNEL}" ]]; then
    echo "Missing kernel-devel for ${KERNEL}" >&2
    exit 1
fi

if [[ ! -d "/usr/lib/modules/${KERNEL}" ]]; then
    echo "Missing kernel modules for ${KERNEL}" >&2
    exit 1
fi

rm -rf /tmp/it87
git clone "${IT87_REPO}" /tmp/it87
git -C /tmp/it87 checkout --detach "${IT87_COMMIT}"
cd /tmp/it87

make "${IT87_MAKE_ARGS[@]}" clean
make "${IT87_MAKE_ARGS[@]}" modules

xz -C crc32 it87-extras.ko

# Catch a build that silently used different headers than the image's kernel.
vermagic="$(modinfo --field=vermagic it87-extras.ko.xz)"
if [[ "${vermagic}" != "${KERNEL} "* ]]; then
    echo "Unexpected it87-extras vermagic: ${vermagic} (expected ${KERNEL})" >&2
    exit 1
fi

install -Dm644 it87-extras.ko.xz \
    "/usr/lib/modules/${KERNEL}/extra/it87-extras/it87-extras.ko.xz"
depmod -a "${KERNEL}"

# Use the out-of-tree module instead of the in-tree driver with the same name.
# Blacklist source: https://github.com/grandpares/it87/blob/bef2dd79af1c2d711e4f3d00df4f32b59a9a9669/install/modprobe.conf
install -d /usr/lib/modprobe.d /usr/lib/modules-load.d
printf '%s\n' 'blacklist it87' > /usr/lib/modprobe.d/it87-extras.conf
printf '%s\n' 'it87-extras' > /usr/lib/modules-load.d/it87-extras.conf

rm -rf /tmp/it87
