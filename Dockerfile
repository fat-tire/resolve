#  A Dockerfile for DaVinci Resolve on Ubuntu w/rootless podman
#
#  Build a DaVinci Resolve image for Podman/Docker
#
#  build this with:
#          ./build.sh

#-----------
#  To build, we start with Rocky Linux

ARG BASE_IMAGE=docker.io/rockylinux:8.6

FROM ${BASE_IMAGE}

# get the arch and nvidia version from the host.  These are default values overridden in build.sh

ARG ARCH=x86_64
ARG NVIDIA_VERSION=525.105
ARG NO_PIPEWIRE=0
ARG ZIPNAME
ARG BUILD_X264_ENCODER_PLUGIN=0

# get x11 + nvidia + sound + other dependency stuff set up the machine ID
#     libcurl-devel added to support fusion reactor installer
#     see https://gitlab.com/WeSuckLess/Reactor/-/blob/master/Docs/Installing-Reactor.md#installing-reactor

# Future: when bluetooth works with speed editor in Linux, add these packages:  bluez avahi dbus-x11 nss-mdns
# EXTRA_PACKS are packages that may not be available but should be installed if they are.
ARG EXTRA_PACKS=""
RUN if [[ `dnf list libxcrypt-compat` == *libxcrypt-compat* ]]; then export EXTRA_PACKS="${EXTRA_PACKS} libxcrypt-compat" ; fi \
       && if [[ `dnf list compat-openssl11` == *compat-openssl11* ]]; then export EXTRA_PACKS="${EXTRA_PACKS} compat-openssl11" ; fi \
       && if [[ `dnf list compat-openssl10` == *compat-openssl10* ]]; then export EXTRA_PACKS="${EXTRA_PACKS} compat-openssl10"; fi \
       && export NVIDIA_VERSION=$NVIDIA_VERSION \
       && export ARCH=$ARCH \
       && dnf update --refresh -y \
       && dnf install dnf-plugins-core xorg-x11-server-Xorg libXcursor unzip alsa-lib librsvg2 libGLU sudo module-init-tools libgomp xcb-util python39 -y \
       && dnf install epel-release -y && dnf install xcb-util-cursor libglvnd-devel -y \
       && if [ ! -z "${EXTRA_PACKS}" ]; then dnf install ${EXTRA_PACKS} -y ; fi \
       && if [[ "${NO_PIPEWIRE}" == 0 ]] ; then \
             dnf install libXi libXt libXtst procps dbus-x11 libSM pipewire libcurl-devel \
                 apr apr-util libXinerama libxkbcommon libxkbcommon-x11 libXrandr xcb-util-image xcb-util-keysyms xcb-util-renderutil xcb-util-wm \
                 libglvnd-opengl pulseaudio-libs nss libXcomposite libXdamage -y \
             && curl https://vault.centos.org/8-stream/AppStream/x86_64/os/Packages/alsa-plugins-pulseaudio-1.1.9-1.el8.x86_64.rpm -o /tmp/alsa-plugins-pulseaudio-1.1.9-1.el8.x86_64.rpm \
             && dnf -y remove pipewire-alsa \
             && rpm -i --nodeps --replacefiles /tmp/alsa-plugins-pulseaudio-1.1.9-1.el8.x86_64.rpm \
             && PINNEDSHA=`/usr/bin/sha256sum /tmp/alsa-plugins-pulseaudio-1.1.9-1.el8.x86_64.rpm` \
             && if [ "${PINNEDSHA}" != "a870db3bceeeba7f96a9f04265b8c8359629f0bb3066e68464e399d88001ae52  /tmp/alsa-plugins-pulseaudio-1.1.9-1.el8.x86_64.rpm" ]; then echo "bad checksum" ; exit 1; fi \
             && rm /tmp/alsa-plugins-pulseaudio-1.1.9-1.el8.x86_64.rpm ; \
          else \
             dnf install alsa-plugins-pulseaudio -y ; \
          fi \
       && curl https://us.download.nvidia.com/XFree86/Linux-${ARCH}/${NVIDIA_VERSION}/NVIDIA-Linux-${ARCH}-${NVIDIA_VERSION}.run -o /tmp/NVIDIA-Linux-${ARCH}-${NVIDIA_VERSION}.run \
       && bash /tmp/NVIDIA-Linux-${ARCH}-${NVIDIA_VERSION}.run --no-kernel-module --no-kernel-module-source --run-nvidia-xconfig --no-backup --no-questions --accept-license --ui=none \
       && rm -f /tmp/NVIDIA-Linux-${ARCH}-${NVIDIA_VERSION}.run \
       && rm -rf /var/cache/yum/* \
       && dnf remove -y epel-release dnf-plugins-core libcurl-devel \
       && dnf clean all


ARG USER=resolve
ARG USER_ID=1000

RUN useradd -u "${USER_ID}" -U --create-home -r $USER && echo "$USER:$USER" | chpasswd && usermod -aG wheel $USER

# To disallow the resolve user to do things as root, comment out this line
RUN echo "${USER} ALL=(ALL) NOPASSWD:ALL" > /etc/sudoers.d/90-$USER

# now install davinci resolve .zip

COPY "${ZIPNAME}" /tmp/DaVinci_Resolve_Linux.zip

# Note: for Arch & Manjaro distributions, we need to work around a potential AppImage "magic bytes" bug that may be in the run file
# see https://github.com/fat-tire/resolve/issues/16

RUN cd /tmp \
    && unzip *DaVinci_Resolve_Linux.zip \
    && if [ "`od -An -j 8 -N 6 -x --endian=big *DaVinci_Resolve_*_Linux.run`" = " 4149 0200 0000" ]; then \
            sed '0,/AI\x02/{s|AI\x02|\x00\x00\x00|}' -i *DaVinci_Resolve_*_Linux.run; fi \
    && ./*DaVinci_Resolve_*_Linux.run  --appimage-extract \
    && cd squashfs-root \
    && ./AppRun -i -a -y \
    && cat /tmp/squashfs-root/docs/License.* \
    && rm -rf /tmp/*.run /tmp/squashfs-root /tmp/*.zip /tmp/*.pdf

# build the x264 encoder plugin from source and move it in position

COPY ./x264_plugin_patcher.sh /tmp/x264_plugin_patcher.sh

ARG POWERTOOLS=powertools
RUN if [[ "${BUILD_X264_ENCODER_PLUGIN}" == 1 ]] ; then \
       if [[ `dnf repolist --all` == *"crb"* ]]; then export POWERTOOLS=crb ; fi \
       && cd /tmp \
       && dnf -y install clang llvm zlib-devel git diffutils patch ed \
       && dnf -y --enablerepo="${POWERTOOLS}" install nasm \
       && git clone https://code.videolan.org/videolan/x264.git \
       && cd x264 \
       && ./configure --enable-shared \
       && make \
       && cp -R /opt/resolve/Developer/CodecPlugin/Examples/x264_encoder_plugin /tmp \
       && cd .. \
       && chmod a+x x264_plugin_patcher.sh \
       && ./x264_plugin_patcher.sh \
       && cd x264_encoder_plugin && make clean && make && make install \
       && dnf remove -y clang llvm zlib-devel git diffutils patch nasm ed \
       && rm -rf /var/cache/yum/* \
       && dnf clean all ; \
    fi \
       && rm -rf /tmp/x264*

CMD __NV_PRIME_RENDER_OFFLOAD=1 __GLX_VENDOR_LIBRARY_NAME=nvidia __VK_LAYER_NV_optimus=NVIDIA_only /opt/resolve/bin/resolve
