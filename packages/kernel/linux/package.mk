# SPDX-License-Identifier: GPL-2.0-or-later
# Copyright (C) 2009-2016 Stephan Raue (stephan@openelec.tv)
# Copyright (C) 2017-present Team LibreELEC (https://libreelec.tv)

PKG_NAME="linux"
PKG_LICENSE="GPL"
PKG_SITE="http://www.kernel.org"
PKG_DEPENDS_HOST="ccache:host rdfind:host rsync:host openssl:host"
PKG_DEPENDS_TARGET="toolchain rdfind:host linux:host kmod:host cpio:host xz:host keyutils ncurses openssl:host wireless-regdb ${KERNEL_EXTRA_DEPENDS_TARGET}"
PKG_NEED_UNPACK="${LINUX_DEPENDS} $(get_pkg_directory initramfs) $(get_pkg_variable initramfs PKG_NEED_UNPACK)"
PKG_LONGDESC="This package contains a precompiled kernel image and the modules."
PKG_IS_KERNEL_PKG="yes"
PKG_STAMP="${KERNEL_TARGET} ${KERNEL_MAKE_EXTRACMD}"

PKG_PATCH_DIRS="${LINUX} ${DEVICE} default"

case ${DEVICE} in
  RK3588*)
    PKG_VERSION="494c0a303537c55971421b5552d98eb55e652cf3"
    PKG_URL="https://github.com/armbian/linux-rockchip/archive/${PKG_VERSION}.tar.gz"
    PKG_GIT_CLONE_BRANCH="rk-5.10-rkr6"
  ;;
  RK3566-BSP)
    PKG_URL="https://github.com/RetroGFX/rk356x-kernel.git"
    PKG_VERSION="bf340e252cd15e5857560b10e28be1746b0d0260"
    GET_HANDLER_SUPPORT="git"
    PKG_GIT_CLONE_BRANCH="main"
  ;;
  RK3566-BSP-X55)
    PKG_URL="https://github.com/RetroGFX/rk3566-x55-kernel.git"
    PKG_VERSION="9e8f3703fe49d5d12bbb951e233248f5f3eb9efd"
    GET_HANDLER_SUPPORT="git"
    PKG_GIT_CLONE_BRANCH="main"
  ;;
  RK356*)
    PKG_VERSION="6.8-rc6"
    PKG_URL="https://git.kernel.org/torvalds/t/${PKG_NAME}-${PKG_VERSION}.tar.gz"
  ;;
  S922X|RK3399)
    PKG_VERSION="6.8.1"
    PKG_URL="https://www.kernel.org/pub/linux/kernel/v6.x/${PKG_NAME}-${PKG_VERSION}.tar.xz"
  ;;
  *)
    PKG_VERSION="6.7.9"
    PKG_URL="https://www.kernel.org/pub/linux/kernel/v6.x/${PKG_NAME}-${PKG_VERSION}.tar.xz"
  ;;
esac

PKG_KERNEL_CFG_FILE=$(kernel_config_path) || die

if [ -n "${KERNEL_TOOLCHAIN}" ]; then
  PKG_DEPENDS_HOST+=" gcc-${KERNEL_TOOLCHAIN}:host"
  PKG_DEPENDS_TARGET+=" gcc-${KERNEL_TOOLCHAIN}:host"
  HEADERS_ARCH=${TARGET_ARCH}
fi

if [ "${PKG_BUILD_PERF}" != "no" ] && grep -q ^CONFIG_PERF_EVENTS= ${PKG_KERNEL_CFG_FILE}; then
  PKG_BUILD_PERF="yes"
  PKG_DEPENDS_TARGET+=" binutils elfutils libunwind zlib openssl libtraceevent libtracefs"
fi

if [[ "${TARGET_ARCH}" =~ i*86|x86_64 ]]; then
  PKG_DEPENDS_TARGET+=" elfutils:host pciutils intel-ucode kernel-firmware"
elif [ "${TARGET_ARCH}" = "arm" -a "${DEVICE}" = "iMX6" ]; then
  PKG_DEPENDS_TARGET+=" firmware-imx"
fi

if [[ "${KERNEL_TARGET}" = uImage* ]]; then
  PKG_DEPENDS_TARGET+=" u-boot-tools:host"
fi

# Ensure that the dependencies of initramfs:target are built correctly, but
# we don't want to add initramfs:target as a direct dependency as we install
# this "manually" from within linux:target
for pkg in $(get_pkg_variable initramfs PKG_DEPENDS_TARGET); do
  ! listcontains "${PKG_DEPENDS_TARGET}" "${pkg}" && PKG_DEPENDS_TARGET+=" ${pkg}" || true
done

if [ "${DEVICE}" = "RK3326" -o  "${DEVICE}" = "RK3326-CLONE" -o "${DEVICE}" = "RK3566" ]; then
  PKG_DEPENDS_UNPACK+=" generic-dsi"
fi

post_patch() {
  # linux was already built and its build dir autoremoved - prepare it again for kernel packages
  if [ -d ${PKG_INSTALL}/.image ]; then
    cp -p ${PKG_INSTALL}/.image/.config ${PKG_BUILD}
    kernel_make -C ${PKG_BUILD} prepare

    # restore the required Module.symvers from an earlier build
    cp -p ${PKG_INSTALL}/.image/Module.symvers ${PKG_BUILD}
  fi

  if [ "${DEVICE}" = "RK3326" -o  "${DEVICE}" = "RK3326-CLONE" -o "${DEVICE}" = "RK3566" ]; then
    cp -v $(get_pkg_directory generic-dsi)/sources/panel-generic-dsi.c ${PKG_BUILD}/drivers/gpu/drm/panel/
    echo "obj-y" += panel-generic-dsi.o >> ${PKG_BUILD}/drivers/gpu/drm/panel/Makefile
  fi
}

make_init() {
 : # reuse make_target()
}

makeinstall_init() {
  if [ -n "${INITRAMFS_MODULES}" ]; then
    mkdir -p ${INSTALL}/etc
    mkdir -p ${INSTALL}/usr/lib/modules

    for i in ${INITRAMFS_MODULES}; do
      module=`find .install_pkg/$(get_full_module_dir)/kernel -name ${i}.ko`
      if [ -n "${module}" ]; then
        echo ${i} >> ${INSTALL}/etc/modules
        cp ${module} ${INSTALL}/usr/lib/modules/`basename ${module}`
      fi
    done
  fi

  if [ "${UVESAFB_SUPPORT}" = yes ]; then
    mkdir -p ${INSTALL}/usr/lib/modules
      uvesafb=`find .install_pkg/$(get_full_module_dir)/kernel -name uvesafb.ko`
      cp ${uvesafb} ${INSTALL}/usr/lib/modules/`basename ${uvesafb}`
  fi
}

make_host() {
  :
}

makeinstall_host() {
  make \
    ARCH=${HEADERS_ARCH:-${TARGET_KERNEL_ARCH}} \
    HOSTCC="${TOOLCHAIN}/bin/host-gcc" \
    HOSTCXX="${TOOLCHAIN}/bin/host-g++" \
    HOSTCFLAGS="${HOST_CFLAGS}" \
    HOSTCXXFLAGS="${HOST_CXXFLAGS}" \
    HOSTLDFLAGS="${HOST_LDFLAGS}" \
    INSTALL_HDR_PATH=dest \
    headers_install
  mkdir -p ${SYSROOT_PREFIX}/usr/include
    cp -R dest/include/* ${SYSROOT_PREFIX}/usr/include
}

pre_make_target() {
 ( cd ${ROOT}
    rm -f ${STAMPS_INSTALL}/initramfs/install_target ${STAMPS_INSTALL}/*/install_init
    for INIT_PACKAGE in $(find ${PKG_BUILD}/../image/.stamps -name "*_init" | sed 's#^.*stamps/##g; s#/.*init$##g')
    do
      ${SCRIPTS}/install ${INIT_PACKAGE}:init
    done
    ${SCRIPTS}/install initramfs
  )
  pkg_lock_status "ACTIVE" "linux:target" "build"

  cp ${PKG_KERNEL_CFG_FILE} ${PKG_BUILD}/.config

  # set initramfs source
  ${PKG_BUILD}/scripts/config --set-str CONFIG_INITRAMFS_SOURCE "$(kernel_initramfs_confs) ${BUILD}/initramfs"

  # set default hostname based on ${DEVICE}
  ${PKG_BUILD}/scripts/config --set-str CONFIG_DEFAULT_HOSTNAME "${DEVICE}"

  # disable swap support if not enabled
  if [ ! "${SWAP_SUPPORT}" = yes ]; then
    ${PKG_BUILD}/scripts/config --disable CONFIG_SWAP
  fi

  # disable nfs support if not enabled
  if [ ! "${NFS_SUPPORT}" = yes ]; then
    ${PKG_BUILD}/scripts/config --disable CONFIG_NFS_FS
  fi

  # disable cifs support if not enabled
  if [ ! "${SAMBA_SUPPORT}" = yes ]; then
    ${PKG_BUILD}/scripts/config --disable CONFIG_CIFS
  fi

  # disable iscsi support if not enabled
  if [ ! "${ISCSI_SUPPORT}" = yes ]; then
    ${PKG_BUILD}/scripts/config --disable CONFIG_SCSI_ISCSI_ATTRS
    ${PKG_BUILD}/scripts/config --disable CONFIG_ISCSI_TCP
    ${PKG_BUILD}/scripts/config --disable CONFIG_ISCSI_BOOT_SYSFS
    ${PKG_BUILD}/scripts/config --disable CONFIG_ISCSI_IBFT_FIND
    ${PKG_BUILD}/scripts/config --disable CONFIG_ISCSI_IBFT
  fi

  # disable lima/panfrost if libmali is configured
  if [ "${OPENGLES}" = "libmali" ]; then
    ${PKG_BUILD}/scripts/config --disable CONFIG_DRM_LIMA
    ${PKG_BUILD}/scripts/config --disable CONFIG_DRM_PANFROST
  fi

  # disable wireguard support if not enabled
  if [ ! "${WIREGUARD_SUPPORT}" = yes ]; then
    ${PKG_BUILD}/scripts/config --disable CONFIG_WIREGUARD
  fi

  if [[ "${TARGET_ARCH}" =~ i*86|x86_64 ]]; then
    # copy some extra firmware to linux tree
    mkdir -p ${PKG_BUILD}/external-firmware
      cp -a $(get_build_dir kernel-firmware)/.copied-firmware/{amdgpu,amd-ucode,i915,radeon,e100,rtl_nic} ${PKG_BUILD}/external-firmware

    cp -a $(get_build_dir intel-ucode)/intel-ucode ${PKG_BUILD}/external-firmware

    FW_LIST="$(find ${PKG_BUILD}/external-firmware \( -type f -o -type l \) \( -iname '*.bin' -o -iname '*.fw' -o -path '*/intel-ucode/*' \) | sed 's|.*external-firmware/||' | sort | xargs)"

    ${PKG_BUILD}/scripts/config --set-str CONFIG_EXTRA_FIRMWARE "${FW_LIST}"
    ${PKG_BUILD}/scripts/config --set-str CONFIG_EXTRA_FIRMWARE_DIR "external-firmware"

  elif [ "${TARGET_ARCH}" = "arm" -a "${DEVICE}" = "iMX6" ]; then
    mkdir -p ${PKG_BUILD}/external-firmware/imx/sdma
      cp -a $(get_build_dir firmware-imx)/firmware/sdma/*imx6*.bin ${PKG_BUILD}/external-firmware/imx/sdma
      cp -a $(get_build_dir firmware-imx)/firmware/vpu/*imx6*.bin ${PKG_BUILD}/external-firmware

    FW_LIST="$(find ${PKG_BUILD}/external-firmware -type f | sed 's|.*external-firmware/||' | sort | xargs)"

    ${PKG_BUILD}/scripts/config --set-str CONFIG_EXTRA_FIRMWARE "${FW_LIST}"
    ${PKG_BUILD}/scripts/config --set-str CONFIG_EXTRA_FIRMWARE_DIR "external-firmware"
  fi

  yes "" | kernel_make oldconfig

  if [ -f "${ROOT}/${DISTRO}/kernel_options" ]; then
    while read OPTION; do
      [ -z "${OPTION}" -o -n "$(echo "${OPTION}" | grep '^#')" ] && continue

      if [ "${OPTION##*=}" == "n" -a "$(${PKG_BUILD}/scripts/config --state ${OPTION%%=*})" == "undef" ]; then
        continue
      fi

      if [ "$(${PKG_BUILD}/scripts/config --state ${OPTION%%=*})" != "$(echo ${OPTION##*=} | tr -d '"')" ]; then
        MISSING_KERNEL_OPTIONS+="\t${OPTION}\n"
      fi
    done < ${ROOT}/${DISTRO}/kernel_options

    if [ -n "${MISSING_KERNEL_OPTIONS}" ]; then
      print_color CLR_WARNING "LINUX: kernel options not correct: \n${MISSING_KERNEL_OPTIONS%%}\nPlease run ./tools/check_kernel_config\n"
    fi
  fi
}

make_target() {
  # arm64 target does not support creating uImage.
  # Build Image first, then wrap it using u-boot's mkimage.
  if [[ "${TARGET_KERNEL_ARCH}" = "arm64" && "${KERNEL_TARGET}" = uImage* ]]; then
    if [ -z "${KERNEL_UIMAGE_LOADADDR}" -o -z "${KERNEL_UIMAGE_ENTRYADDR}" ]; then
      die "ERROR: KERNEL_UIMAGE_LOADADDR and KERNEL_UIMAGE_ENTRYADDR have to be set to build uImage - aborting"
    fi
    KERNEL_UIMAGE_TARGET="${KERNEL_TARGET}"
    KERNEL_TARGET="${KERNEL_TARGET/uImage/Image}"
  fi

  DTC_FLAGS=-@ kernel_make ${KERNEL_TARGET} ${KERNEL_MAKE_EXTRACMD} modules

  if [ "${PKG_BUILD_PERF}" = "yes" ]; then
    ( cd tools/perf

      # arch specific perf build args
      case "${TARGET_ARCH}" in
        x86_64|i*86)
          PERF_BUILD_ARGS="ARCH=x86"
          ;;
        aarch64)
          PERF_BUILD_ARGS="ARCH=arm64"
          ;;
        *)
          PERF_BUILD_ARGS="ARCH=${TARGET_ARCH}"
          ;;
      esac

      WERROR=0 \
      NO_LIBPERL=1 \
      NO_LIBPYTHON=1 \
      NO_SLANG=1 \
      NO_GTK2=1 \
      NO_LIBNUMA=1 \
      NO_LIBAUDIT=1 \
      NO_LIBTRACEEVENT=1 \
      NO_LZMA=1 \
      NO_SDT=1 \
      CROSS_COMPILE="${TARGET_PREFIX}" \
      JOBS="${CONCURRENCY_MAKE_LEVEL}" \
        make ${PERF_BUILD_ARGS}
      mkdir -p ${INSTALL}/usr/bin
        cp perf ${INSTALL}/usr/bin
    )
  fi

  if [ -n "${KERNEL_UIMAGE_TARGET}" ]; then
    # determine compression used for kernel image
    KERNEL_UIMAGE_COMP=${KERNEL_UIMAGE_TARGET:7}
    KERNEL_UIMAGE_COMP=$(echo ${KERNEL_UIMAGE_COMP:-none} | sed 's/gz/gzip/; s/bz2/bzip2/')

    # calculate new load address to make kernel Image unpack to memory area after compressed image
    if [ "${KERNEL_UIMAGE_COMP}" != "none" ]; then
      COMPRESSED_SIZE=$(stat -t "arch/${TARGET_KERNEL_ARCH}/boot/${KERNEL_TARGET}" | awk '{print $2}')
      # align to 1 MiB
      COMPRESSED_SIZE=$(( ((${COMPRESSED_SIZE} - 1 >> 20) + 1) << 20 ))
      PKG_KERNEL_UIMAGE_LOADADDR=$(printf '%X' "$(( ${KERNEL_UIMAGE_LOADADDR} + ${COMPRESSED_SIZE} ))")
      PKG_KERNEL_UIMAGE_ENTRYADDR=$(printf '%X' "$(( ${KERNEL_UIMAGE_ENTRYADDR} + ${COMPRESSED_SIZE} ))")
    else
      PKG_KERNEL_UIMAGE_LOADADDR=${KERNEL_UIMAGE_LOADADDR}
      PKG_KERNEL_UIMAGE_ENTRYADDR=${KERNEL_UIMAGE_ENTRYADDR}
    fi

    mkimage -A ${TARGET_KERNEL_ARCH} \
            -O linux \
            -T kernel \
            -C ${KERNEL_UIMAGE_COMP} \
            -a ${PKG_KERNEL_UIMAGE_LOADADDR} \
            -e ${PKG_KERNEL_UIMAGE_ENTRYADDR} \
            -d arch/${TARGET_KERNEL_ARCH}/boot/${KERNEL_TARGET} \
               arch/${TARGET_KERNEL_ARCH}/boot/${KERNEL_UIMAGE_TARGET}

    KERNEL_TARGET="${KERNEL_UIMAGE_TARGET}"
  fi
}

makeinstall_target() {
  mkdir -p ${INSTALL}/.image
  cp -p arch/${TARGET_KERNEL_ARCH}/boot/${KERNEL_TARGET} System.map .config Module.symvers ${INSTALL}/.image/

  kernel_make INSTALL_MOD_PATH=${INSTALL}/$(get_kernel_overlay_dir) modules_install
  rm -f ${INSTALL}/$(get_kernel_overlay_dir)/lib/modules/*/build
  rm -f ${INSTALL}/$(get_kernel_overlay_dir)/lib/modules/*/source

  if [ "${BOOTLOADER}" = "u-boot" ]; then
    mkdir -p ${INSTALL}/usr/share/bootloader
    for dtb in arch/${TARGET_KERNEL_ARCH}/boot/dts/*.dtb arch/${TARGET_KERNEL_ARCH}/boot/dts/*/*.dtb; do
      if [ -f ${dtb} ]; then
        cp -v ${dtb} ${INSTALL}/usr/share/bootloader
      fi
    done

    if [ "${PROJECT}" = "Rockchip" ]; then
      . ${PROJECT_DIR}/${PROJECT}/devices/${DEVICE}/options
      if [ "${TRUST_LABEL}" = "resource" ]; then
        ARCH=arm64 scripts/mkimg --dtb ${DEVICE_DTB[0]}.dtb
        ARCH=arm64 scripts/mkmultidtb.py ${PKG_SOC}
        cp -v resource.img ${INSTALL}/usr/share/bootloader
        ARCH=${TARGET_ARCH}
      fi
    fi
  fi
  makeinstall_host
}

post_install() {
  if [ ! -d ${INSTALL}/$(get_full_firmware_dir) ]
  then
    mkdir -p ${INSTALL}/$(get_full_firmware_dir)/
  fi

  # regdb and signature is now loaded as firmware by 4.15+
    if grep -q ^CONFIG_CFG80211_REQUIRE_SIGNED_REGDB= ${PKG_BUILD}/.config; then
      cp $(get_build_dir wireless-regdb)/regulatory.db{,.p7s} ${INSTALL}/$(get_full_firmware_dir)
    fi
}
