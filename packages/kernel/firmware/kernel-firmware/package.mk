# SPDX-License-Identifier: GPL-2.0
# Copyright (C) 2016-present Team LibreELEC (https://libreelec.tv)

PKG_NAME="kernel-firmware"
PKG_VERSION="20250311"
PKG_LICENSE="other"
PKG_SITE="https://git.kernel.org/pub/scm/linux/kernel/git/firmware/linux-firmware.git/"
PKG_URL="https://cdn.kernel.org/pub/linux/kernel/firmware/linux-firmware-${PKG_VERSION}.tar.gz"
PKG_NEED_UNPACK="${PROJECT_DIR}/${PROJECT}/packages/${PKG_NAME} ${PROJECT_DIR}/${PROJECT}/devices/${DEVICE}/packages/${PKG_NAME}"
PKG_LONGDESC="kernel-firmware: kernel related firmware"
PKG_TOOLCHAIN="manual"

configure_package() {
  PKG_FW_SOURCE=${PKG_BUILD}/.copied-firmware
}

post_patch() {
  (
    cd ${PKG_BUILD}
    mkdir -p "${PKG_FW_SOURCE}"
      ./copy-firmware.sh --verbose "${PKG_FW_SOURCE}"

    # copy extra firmware files (or overwrite upstream ones)
    if [ -d ${PKG_DIR}/extra-firmware ]; then
      cp -r ${PKG_DIR}/extra-firmware/* "${PKG_FW_SOURCE}"
    fi
  )
}

# Install additional miscellaneous drivers
makeinstall_target() {
  FW_TARGET_DIR=${INSTALL}/$(get_full_firmware_dir)

  if find_file_path config/kernel-firmware.dat; then
    FW_LISTS="${FOUND_PATH}"
  else
    FW_LISTS="${PKG_DIR}/firmwares/any.dat ${PKG_DIR}/firmwares/${TARGET_ARCH}.dat"
  fi

  FW_LISTS+=" ${PROJECT_DIR}/${PROJECT}/config/kernel-firmware-any.dat ${PROJECT_DIR}/${PROJECT}/config/kernel-firmware-${TARGET_ARCH}.dat"

  FW_LISTS+=" ${PROJECT_DIR}/${PROJECT}/devices/${DEVICE}/config/kernel-firmware-any.dat ${PROJECT_DIR}/${PROJECT}/devices/${DEVICE}/config/kernel-firmware-${TARGET_ARCH}.dat"

  for fwlist in ${FW_LISTS}; do
    [ -f "${fwlist}" ] || continue

    while read -r fwline; do
      [ -z "${fwline}" ] && continue
      [[ ${fwline} =~ ^#.* ]] && continue
      [[ ${fwline} =~ ^[[:space:]] ]] && continue

      eval "(cd ${PKG_FW_SOURCE} && find "${fwline}" >/dev/null)" || die "ERROR: Firmware pattern does not exist: ${fwline}"

      while read -r fwfile; do
        [ -d "${PKG_FW_SOURCE}/${fwfile}" ] && continue

        if [ -f "${PKG_FW_SOURCE}/${fwfile}" ]; then
          mkdir -p "$(dirname "${FW_TARGET_DIR}/${fwfile}")"
            cp -Lv "${PKG_FW_SOURCE}/${fwfile}" "${FW_TARGET_DIR}/${fwfile}"
        else
          echo "ERROR: Firmware file ${fwfile} does not exist - aborting"
          exit 1
        fi
      done <<< "$(cd ${PKG_FW_SOURCE} && eval "find "${fwline}"")"
    done < "${fwlist}"
  done

  PKG_KERNEL_CFG_FILE=$(kernel_config_path) || die

  # brcm pcie firmware is only needed by x86_64
  [ "${TARGET_ARCH}" != "x86_64" ] && rm -fr ${FW_TARGET_DIR}/brcm/*-pcie.*

  # The BSP kernel for RK3588 reformats the vendor firmware path for Realtek BT devices,
  # so symlink the firmware.
  if [ ${DEVICE} = "RK3588" ]; then
    for i in ${FW_TARGET_DIR}/rtl_bt/*.bin; do
      ln -s "rtl_bt/$(basename ${i})" "${FW_TARGET_DIR}/$(basename ${i%.*})"
    done
  fi

  # Sm8250 devices need slpi firmware set to the correct dir
  if [ ${DEVICE} = "SM8250" ]; then
   mv ${FW_TARGET_DIR}/qcom/sm8250/Thundercomm/RB5/* ${FW_TARGET_DIR}/qcom/sm8250/
  fi

  # Cleanup - which may be project or device specific
  find_file_path scripts/cleanup.sh && ${FOUND_PATH} ${FW_TARGET_DIR} || true
}

