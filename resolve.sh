#!/bin/bash
#
# DaVinci Resolve [Studio] for Ubuntu launch script

announce () {
   echo "$1"
   notify-send "$1"
}

source ${BASH_SOURCE%/*}/env-set.sh

# allow local access to xwindows
xhost +local:resolve

# check if resolve is already running-- don't want multiple instances as only one set of configs

if pidof -o %PPID -x "resolve.sh">/dev/null; then
   announce "Already running resolve.  Exiting."
   exit 1
fi

# is the resolve image built?

${CONTAINER_EXISTS} resolve

if [ $? -ne 0 ]; then
   announce "The 'resolve' image wasn't found.  Build the Dockerfile first."
   exit 1
fi

# change these if you want different locations for your MOUNTS

export MOUNTS_DIRNAME=mounts

export RESOLVE_HOMEDIR=${MOUNTS_DIRNAME}/resolve-home # the container user $HOME
export RESOLVE_LOGS=${MOUNTS_DIRNAME}/logs
export RESOLVE_CONFIGS=${MOUNTS_DIRNAME}/configs
export RESOLVE_DATABASE=${MOUNTS_DIRNAME}/database
export RESOLVE_EASYDCP=${MOUNTS_DIRNAME}/easyDCP
export RESOLVE_LICENSE=${MOUNTS_DIRNAME}/license
export RESOLVE_COMMON_DATA_DIR=${MOUNTS_DIRNAME}/BlackmagicDesign
export RESOLVE_MEDIA=${MOUNTS_DIRNAME}/Media  # for raw footage (Ubuntu ~/Videos)

# make sure expected MOUNTS are here.
mkdir -p ${RESOLVE_MOUNTS_PATH}/${RESOLVE_HOMEDIR}/.local/share/fonts
mkdir -p ${RESOLVE_MOUNTS_PATH}/${RESOLVE_LOGS}
mkdir -p ${RESOLVE_MOUNTS_PATH}/${RESOLVE_CONFIGS}
mkdir -p ${RESOLVE_MOUNTS_PATH}/${RESOLVE_DATABASE}
mkdir -p ${RESOLVE_MOUNTS_PATH}/${RESOLVE_EASYDCP}
mkdir -p ${RESOLVE_MOUNTS_PATH}/${RESOLVE_LICENSE}
mkdir -p ${RESOLVE_MOUNTS_PATH}/${RESOLVE_COMMON_DATA_DIR}
mkdir -p ${RESOLVE_MOUNTS_PATH}/${RESOLVE_MEDIA}

# Check for a machine-id file. If one doesn't exist, generate one derived from
# the current host's machine-id if it exists (so it can be reproduced if needed).
# The generated "contanier-machine-id" is a md5sum of the host's /etc/machine-id.
# (In this case, an MD5 hash is deemed "good enough" for this purpose.)
#
# This new file will be placed in the /mounts directory to be bind-mounted onto the
# container's /etc/machine-id - if you ever want another machine id, replace
# container-machine-id.  You can make a random new one with:
#     dbus-uuidgen > new-machine-id-file

echo "------------------------------------------------------------------------------"

if [ -z "$RESOLVE_TAG" ]; then
   export RESOLVE_TAG="latest"
fi

if [ ! -f "${RESOLVE_MOUNTS_PATH}/${MOUNTS_DIRNAME}/container-machine-id" ]; then
    echo "No \"container-machine-id\" file found for this container."
    if [ ! -f "/etc/machine-id" ]; then
        export NEW_ONE=`hexdump -n 16 -e '4/4 "%08X" 1 "\n"' /dev/urandom`
        echo "No /etc/machine-id found on host. Generating a random machine-id..."
    else
        # salt the current machine ID for no practical reason
        export NEW_ONE=`echo -n "DaVinciResolveSalt" | cat - /etc/machine-id`
        # and md5sum it -- we are not worried about hash collisions, etc.
        export NEW_ONE=`echo -n $NEW_ONE | md5sum  | awk '{print $1}'`
        echo "Creating new one derived from host machine-id ("`cat /etc/machine-id`")..."
    fi
    echo $NEW_ONE > "${RESOLVE_MOUNTS_PATH}/${MOUNTS_DIRNAME}/container-machine-id"
    echo "This container's machine-id file can now" \
         "be found at ${RESOLVE_MOUNTS_PATH}/${MOUNTS_DIRNAME}/container-machine-id and may be replaced" \
         "if needed."
fi

echo "The container's /etc/machine-id  : "`cat ${RESOLVE_MOUNTS_PATH}/mounts/container-machine-id`

if [ -z "${RESOLVE_NETWORK}" ]; then
   export NET_DRIVER="--network=none"
else
   export NET_DRIVER="--network=${RESOLVE_NETWORK}"
fi

echo "The network driver setting is          : ${NET_DRIVER}"
echo "Bind-mounted directories of interest   :"
echo "  CONTAINER (CentOS 8)                  -> HOST (`source /etc/os-release; echo ${NAME}`)"
echo "  ----------------------------------------------------------------------------"
echo "  /home/resolve                         -> ${RESOLVE_MOUNTS_PATH}/${RESOLVE_HOMEDIR}"
echo "  /opt/resolve/logs                     -> ${RESOLVE_MOUNTS_PATH}/${RESOLVE_LOGS}"
echo "  /opt/resolve/configs                  -> ${RESOLVE_MOUNTS_PATH}/${RESOLVE_CONFIGS}"
echo "  /opt/resolve/easyDCP                  -> ${RESOLVE_MOUNTS_PATH}/${RESOLVE_EASYDCP}"
echo "  /opt/resolve/.license                 -> ${RESOLVE_MOUNTS_PATH}/${RESOLVE_LICENSE}"
echo "  /opt/resolve/'Resolve Disk Database'  -> ${RESOLVE_MOUNTS_PATH}/${RESOLVE_DATABASE}"
echo "  /var/BlackmagicDesign/DaVinci Resolve -> ${RESOLVE_MOUNTS_PATH}/${RESOLVE_COMMON_DATA_DIR}"
echo "  /opt/resolve/Media                    -> ${RESOLVE_MOUNTS_PATH}/${RESOLVE_MEDIA}"

# mount all hidraws - used for speed editor hardware

for f in `find /dev/hidraw*`
do
  MOUNTS_HIDRAW+="--mount type=bind,source=${f},target=${f} "
done

# enable host's system fonts (put it in $HOME/.local/share/fonts in container)

if ! [ -z ${RESOLVE_ENABLE_HOST_SYSTEM_FONTS} ]; then
   export MOUNT_SYSTEM_FONTS="--mount type=bind,source=/usr/share/fonts,target=/home/resolve/.local/share/fonts"
fi

# quick sanity check.

if [ -z "${XAUTHORITY}" ]; then
   if [ -f "${HOME}/.Xauthority" ]; then
      export XAUTHORITY="${HOME}/.Xauthority"
   else
      export XAUTHORITY="/run/user/`id -u`/gdm/Xauthority"
   fi
   echo "\$XAUTHORITY was not set.  Defaulting to ${XAUTHORITY}"
fi

${CONTAINER_TYPE} run -it \
     --user resolve:resolve \
     --env DISPLAY=$DISPLAY \
     --env PULSE_SERVER=unix:${XDG_RUNTIME_DIR}/pulse/native \
     --env PULSE_COOKIE=/run/pulse/cookie \
     --env GDK_SCALE=2 \
     --env GDK_DPI_SCALE=0.5 \
     --env QT_AUTO_SCREEN_SET_FACTOR=0 \
     --env QT_SCALE_FACTOR=2 \
     --env QT_FONT_DPI=96 \
     --device /dev/dri \
     --device /dev/input \
     --device /dev/nvidia0 \
     --device /dev/nvidiactl \
     --device /dev/nvidia-modeset \
     --device /dev/nvidia-uvm \
     --device /dev/nvidia-uvm-tools \
     --mount type=bind,source=/dev/bus/usb,target=/dev/bus/usb \
     --mount type=bind,source=$XAUTHORITY,target=/tmp/.host_Xauthority,readonly \
     --mount type=bind,source=/etc/localtime,target=/etc/localtime,readonly \
     --mount type=bind,source=/tmp/.X11-unix,target=/tmp/.X11-unix \
     --mount type=bind,source=${XDG_RUNTIME_DIR}/pulse/native,target=${XDG_RUNTIME_DIR}/pulse/native \
     --mount type=bind,source=${HOME}/.config/pulse/cookie,target=/run/pulse/cookie \
     --mount type=bind,source=${HOME}/.local/share/fonts,target=/usr/share/fonts,readonly \
     --mount type=bind,source=${RESOLVE_MOUNTS_PATH}/${MOUNTS_DIRNAME}/container-machine-id,target=/etc/machine-id \
     --mount type=bind,source=${RESOLVE_MOUNTS_PATH}/${RESOLVE_HOMEDIR},target=/home/resolve \
     --mount type=bind,source=${RESOLVE_MOUNTS_PATH}/${RESOLVE_LOGS},target=/opt/resolve/logs \
     --mount type=bind,source=${RESOLVE_MOUNTS_PATH}/${RESOLVE_CONFIGS},target=/opt/resolve/configs \
     --mount type=bind,source=${RESOLVE_MOUNTS_PATH}/${RESOLVE_EASYDCP},target=/opt/resolve/easyDCP \
     --mount type=bind,source=${RESOLVE_MOUNTS_PATH}/${RESOLVE_LICENSE},target=/opt/resolve/.license \
     --mount type=bind,source=${RESOLVE_MOUNTS_PATH}/${RESOLVE_COMMON_DATA_DIR},target=/var/BlackmagicDesign \
     --mount type=bind,source=${RESOLVE_MOUNTS_PATH}/${RESOLVE_DATABASE},target=/opt/resolve/Resolve\ Disk\ Database \
     --mount type=bind,source=${RESOLVE_MOUNTS_PATH}/${RESOLVE_MEDIA},target=/opt/resolve/Media \
     ${MOUNT_SYSTEM_FONTS} \
     ${MOUNTS_HIDRAW} \
     ${NET_DRIVER} \
     ${CONTAINER_RUN_ARGS} \
     --rm \
     --name="resolve_container" \
     resolve:${RESOLVE_TAG} $*

