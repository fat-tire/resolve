#  A Dockerfile for DaVinci Resolve on Ubuntu w/rootless podman
#
#  Build a DaVinci Resolve image for Podman/Docker in Ubuntu 21.10 or so
#
#  build this with:
#          ./build.sh

#-----------
#  To build, we start with a recent version of Centos Stream
#     12/31/21 CentOS 8 is EOL - https://forums.centos.org/viewtopic.php?f=54&t=78026
#     Switch to official CentOS Stream from quay.io
#     https://www.linux.org/threads/centos-announce-centos-stream-container-images-available-on-quay-io.33339/

FROM quay.io/centos/centos:stream

# get the arch and nvidia version from the host.  These are default values overridden in build.sh

ARG ARCH=x86_64
ARG NVIDIA_VERSION=510.47
ARG ZIPNAME

# get x11 + nvidia + sound + other dependency stuff set up the machine ID
#     libcurl-devel added to support fusion reactor installer
#     see https://gitlab.com/WeSuckLess/Reactor/-/blob/master/Docs/Installing-Reactor.md#installing-reactor

# Future: when bluetooth works with speed editor in Linux, add these packages:  bluez avahi dbus-x11 nss-mdns

RUN    export NVIDIA_VERSION=$NVIDIA_VERSION \
       && export ARCH=$ARCH \
       && dnf update -y \
       && dnf install dnf-plugins-core -y \
       && dnf config-manager --set-enabled powertools \
       && dnf install epel-release -y \
       && dnf install xorg-x11-server-Xorg libXcursor unzip alsa-lib alsa-plugins-pulseaudio librsvg2 libGLU sudo module-init-tools libgomp xcb-util -y \
       && dnf install libcurl-devel -y \
       && curl https://us.download.nvidia.com/XFree86/Linux-${ARCH}/${NVIDIA_VERSION}/NVIDIA-Linux-${ARCH}-${NVIDIA_VERSION}.run -o /tmp/NVIDIA-Linux-${ARCH}-${NVIDIA_VERSION}.run \
       && bash /tmp/NVIDIA-Linux-${ARCH}-${NVIDIA_VERSION}.run --no-kernel-module --no-kernel-module-source --run-nvidia-xconfig --no-backup --no-questions --ui=none \
       && rm -f /tmp/NVIDIA-Linux-${ARCH}-${NVIDIA_VERSION}.run \
       && rm -rf /var/cache/yum/* \
       && dnf remove -y epel-release dnf-plugins-core \ 
       && dnf clean all

ARG USER=resolve

RUN useradd -u 1000 -U --create-home -r $USER && echo "$USER:$USER" | chpasswd && usermod -aG wheel $USER

# To disallow the resolve user to do things as root, comment out this line
RUN echo "${USER} ALL=(ALL) NOPASSWD:ALL" > /etc/sudoers.d/90-$USER

# now install davinci resolve .zip

COPY "${ZIPNAME}" /tmp/DaVinci_Resolve_Linux.zip

RUN cd /tmp \
    && unzip *DaVinci_Resolve_Linux.zip \
    && ./*DaVinci_Resolve_*_Linux.run  --appimage-extract \
    && cd squashfs-root \
    && ./AppRun -i -a -y \
    && cat /tmp/squashfs-root/docs/License.txt \
    && rm -rf /tmp/*.run /tmp/squashfs-root /tmp/*.zip /tmp/*.pdf

CMD /opt/resolve/bin/resolve
