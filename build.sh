#!/bin/bash
#
# This builds the resolve image

source ${BASH_SOURCE%/*}/env-set.sh

if [ "$PWD" != "${REPO_DIR}" ]; then
   echo "Exiting as not running from ${REPO_DIR}"
   exit 1
fi

# is the nvidia-driver installed?

if ! command -v nvidia-smi &> /dev/null; then
   echo "Install the nvidia driver and try again."
   exit 1
fi

# is the .zip in the right place?

if [ -z "${RESOLVE_ZIP}" ]; then
   export ZIPNAME=`ls -1rt DaVinci_Resolve_*_Linux.zip | sort -n | tail -1`
else
# we need to make a link to the context since this could be outside the build context
   CONTEXT_ZIP=".tmp_$(date +%s)_$(basename ${RESOLVE_ZIP})"
   ln ${RESOLVE_ZIP} ${CONTEXT_ZIP}
   export ZIPNAME=${CONTEXT_ZIP}
fi

if ! ls "${ZIPNAME}" 1> /dev/null 2>&1; then
    echo "The Resolve zip file cannot be found.  It should be named similar to \"DaVinci_Resolve_Studio_17.4.3_Linux.zip\".  Exiting."
    exit 1
fi

# get resolve version for image tag

export REGEX='.*[Resolve|Studio]_([0-9|\.|b]+)_Linux.zip'

[[ $ZIPNAME =~ $REGEX ]]

export VER=${BASH_REMATCH[1]}

if ! [[ "${RESOLVE_LICENSE_AGREE,,}" =~ ^(y|yes)$ || "${RESOLVE_LICENSES_AGREE,,}" =~ ^(y|yes)$ ]]; then
    echo "During this build process, Blackmagic Design Pty. Ltd.'s License"
    echo "Agreement for DaVinci Resolve [Studio] (${VER}) will be extracted from"
    echo "the zip file and displayed. You must carefully read the License Agreement"
    echo "and agree to its terms and conditions before using DaVinci Resolve."
    echo "Similarly, some versions of NVIDIA's drivers also require acceptance of"
    echo "a license, which is available at nvidia.com. You must review any applicable"
    echo "license and agree to its terms and conditions before using the NVIDIA driver."
    read -r -p "Do you agree to the above [y/N] " agree
    if ! [[ "${agree,,}" =~ ^(y|yes)$ ]]; then
       echo "You must agree to continue.  Exiting."
       exit 0
    fi
fi

# if RESOLVE_NO_PIPEWIRE set, use that.  Otherwise check.

if [ ! -z "${RESOLVE_NO_PIPEWIRE}" ]; then
   export NO_PIPEWIRE=1
elif `pgrep pipewire &>/dev/null` ; then
   export NO_PIPEWIRE=0
else
   export NO_PIPEWIRE=1
fi

# allow user to override base container image for this build
# otherwise pick a default based on whether pipewire is chosen

if [ ! -z "$RESOLVE_BASE_CONTAINER_IMAGE" ]; then
   export BASE_IMAGE="${RESOLVE_BASE_CONTAINER_IMAGE}"
elif [[ "${NO_PIPEWIRE}" == 1 ]]; then
   export BASE_IMAGE="quay.io/centos/centos:stream8"
else
   export BASE_IMAGE="docker.io/rockylinux:8.6"
fi

# allow user to override tag for this build

if [ ! -z "$RESOLVE_TAG" ]; then
   export TAG="${RESOLVE_TAG}"
else
   export TAG=${VER}
fi

if [ ! -z "$RESOLVE_USER_ID" ]; then
   export USER_ID="${RESOLVE_USER_ID}"
else
   export USER_ID=`id -u`
fi

if [ -z "$RESOLVE_NVIDIA_VERSION" ]; then
   export NVIDIA_VERSION=`nvidia-smi --id-0 --query-gpu=driver_version --format=csv,noheader`
else
   export NVIDIA_VERSION="${RESOLVE_NVIDIA_VERSION}"
fi

# default to NOT building the plugin unless it's explicitly set.
if [ ! -z "${RESOLVE_BUILD_X264_ENCODER_PLUGIN}" ]; then
   export BUILD_X264_ENCODER_PLUGIN=1
else
   export BUILD_X264_ENCODER_PLUGIN=0
fi

echo "Building the resolve:${TAG} image..."

${CONTAINER_BUILD} -t "resolve:${TAG}" -t "resolve" --build-arg ARCH=`uname -m` --build-arg ZIPNAME="${ZIPNAME}" --build-arg BASE_IMAGE="${BASE_IMAGE}" --build-arg NVIDIA_VERSION="${NVIDIA_VERSION}" --build-arg USER_ID="${USER_ID}" --build-arg NO_PIPEWIRE="${NO_PIPEWIRE}" --build-arg BUILD_X264_ENCODER_PLUGIN="${BUILD_X264_ENCODER_PLUGIN}"

# remove any context link
if [ -f "${CONTEXT_ZIP}" ]; then
   rm -f "${CONTEXT_ZIP}"
fi

echo -e "Build of resolve:${TAG} is complete.  To run resolve, try:\n\n./resolve.sh\n"
