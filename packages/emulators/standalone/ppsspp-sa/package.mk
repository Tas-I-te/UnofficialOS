# SPDX-License-Identifier: GPL-2.0-or-later
# Copyright (C) 2019-present Shanti Gilbert (https://github.com/shantigilbert)
# Copyright (C) 2023 JELOS (https://github.com/JustEnoughLinuxOS)

PKG_NAME="ppsspp-sa"
PKG_REV="1"
PKG_ARCH="any"
PKG_SITE="https://github.com/hrydgard/ppsspp"
PKG_URL="${PKG_SITE}.git"
PKG_VERSION="c017718b51e1d8aa4acf16aa9b096a43594c807a" # v1.19.2
CHEAT_DB_VERSION="9475ff7b4be805f818f5f40cc3e5116a4a68deac" # Update cheat.db (20/01/2025)
PKG_LICENSE="GPLv2"
PKG_DEPENDS_TARGET="toolchain ffmpeg libzip SDL2 zlib zip"
PKG_SHORTDESC="PPSSPPDL"
PKG_LONGDESC="PPSSPP Standalone"
GET_HANDLER_SUPPORT="git"

### Note:
### This package includes the NotoSansJP-Regular.ttf font.  This font is licensed under
### SIL Open Font License, Version 1.1.  The license can be found in the licenses
### directory in the root of this project, OFL.txt.
###

PKG_PATCH_DIRS+="${DEVICE}"

PKG_CMAKE_OPTS_TARGET=" -DUSE_SYSTEM_FFMPEG=OFF \
                        -DCMAKE_BUILD_TYPE=Release \
                        -DCMAKE_SYSTEM_NAME=Linux \
                        -DBUILD_SHARED_LIBS=OFF \
                        -DUSE_SYSTEM_LIBPNG=OFF \
                        -DANDROID=OFF \
                        -DWIN32=OFF \
                        -DAPPLE=OFF \
                        -DCMAKE_CROSSCOMPILING=ON \
                        -DUSING_QT_UI=OFF \
                        -DUNITTEST=OFF \
                        -DSIMULATOR=OFF \
                        -DHEADLESS=OFF \
                        -DUSE_DISCORD=OFF"

if [[ "${OPENGL_SUPPORT}" = "yes" ]] && [[ ! "${DEVICE}" = "S922X" ]]; then
  PKG_DEPENDS_TARGET+=" ${OPENGL} glu libglvnd glew"
  PKG_CMAKE_OPTS_TARGET+=" -DUSING_FBDEV=OFF \
			   -DUSING_GLES2=OFF"

elif [ "${OPENGLES_SUPPORT}" = "yes" ]; then
  PKG_DEPENDS_TARGET+=" ${OPENGLES}"
  PKG_CMAKE_OPTS_TARGET+=" -DUSING_FBDEV=ON \
                           -DUSING_EGL=OFF \
                           -DUSING_GLES2=ON"
fi

if [ "${VULKAN_SUPPORT}" = "yes" ]
then
  PKG_DEPENDS_TARGET+=" vulkan-loader vulkan-headers"
  PKG_CMAKE_OPTS_TARGET+=" -DUSE_VULKAN_DISPLAY_KHR=ON \
                           -DVULKAN=ON \
                           -DEGL_NO_X11=1 \
                           -DMESA_EGL_NO_X11_HEADERS=1"
else
  PKG_CMAKE_OPTS_TARGET+=" -DVULKAN=OFF \
                           -DUSE_VULKAN_DISPLAY_KHR=OFF \
                           -DUSING_X11_VULKAN=OFF"
fi

if [ "${DISPLAYSERVER}" = "wl" ]; then
  PKG_DEPENDS_TARGET+=" wayland ${WINDOWMANAGER}"
  PKG_CMAKE_OPTS_TARGET+=" -DUSE_WAYLAND_WSI=ON"
else
  PKG_CMAKE_OPTS_TARGET+=" -DUSE_WAYLAND_WSI=OFF"
fi

pre_configure_target() {
  sed -i 's/\-O[23]//g' ${PKG_BUILD}/CMakeLists.txt
  sed -i "s|include_directories(/usr/include/drm)|include_directories(${SYSROOT_PREFIX}/usr/include/drm)|" ${PKG_BUILD}/CMakeLists.txt
}

pre_make_target() {
  export CPPFLAGS="${CPPFLAGS} -Wno-error"
  export CFLAGS="${CFLAGS} -Wno-error"

  # fix cross compiling
  find ${PKG_BUILD} -name flags.make -exec sed -i "s:isystem :I:g" \{} \;
  find ${PKG_BUILD} -name build.ninja -exec sed -i "s:isystem :I:g" \{} \;
}

makeinstall_target() {
  mkdir -p ${INSTALL}/usr/bin
  cp ${PKG_DIR}/scripts/* ${INSTALL}/usr/bin
  cp PPSSPPSDL ${INSTALL}/usr/bin/ppsspp
  chmod 0755 ${INSTALL}/usr/bin/*
  ln -sf /storage/.config/ppsspp/assets ${INSTALL}/usr/bin/assets
  mkdir -p ${INSTALL}/usr/config/ppsspp/PSP/SYSTEM
  cp -r `find . -name "assets" | xargs echo` ${INSTALL}/usr/config/ppsspp/
  cp -rf ${PKG_DIR}/config/* ${INSTALL}/usr/config/ppsspp/
  if [ -d "${PKG_DIR}/sources/${DEVICE}" ]
  then
    cp ${PKG_DIR}/sources/${DEVICE}/* ${INSTALL}/usr/config/ppsspp/PSP/SYSTEM
  fi
  rm ${INSTALL}/usr/config/ppsspp/assets/gamecontrollerdb.txt
  ln -sf NotoSansJP-Regular.ttf ${INSTALL}/usr/config/ppsspp/assets/Roboto-Condensed.ttf
  curl -Lo ${INSTALL}/usr/config/ppsspp/PSP/Cheats/cheat.db https://raw.githubusercontent.com/Saramagrean/CWCheat-Database-Plus-/${CHEAT_DB_VERSION}/cheat.db
}
