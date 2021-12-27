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

export REGEX='.*[Resolve|Studio]_([0-9|\.]+)_Linux.zip'

[[ $ZIPNAME =~ $REGEX ]]

export VER=${BASH_REMATCH[1]}

if ! [[ "${RESOLVE_LICENSE_AGREE,,}" =~ ^(y|yes)$ ]]; then
    echo "During this build process, Blackmagic Design Pty. Ltd.'s License"
    echo "Agreement for DaVinci Resolve [Studio] (${VER}) will be extracted from"
    echo "the zip file and displayed. You must carefully read the License Agreement"
    echo "and agree to its terms and conditions before using DaVinci Resolve."
    read -r -p "Do you agree to the above [y/N] " agree
    if ! [[ "${agree,,}" =~ ^(y|yes)$ ]]; then
       echo "You must agree to continue.  Exiting."
       exit 0
    fi
fi
# allow user to override tag for this build

if [ ! -z "$RESOLVE_TAG" ]; then
   export TAG="${RESOLVE_TAG}"
else
   export TAG=${VER}
fi

if [ -z "$RESOLVE_NVIDIA_VERSION" ]; then
   export NVIDIA_VERSION=`nvidia-smi --query-gpu=driver_version --format=csv,noheader`
else
   export NVIDIA_VERSION="${RESOLVE_NVIDIA_VERSION}"
fi

echo "Building the resolve:${TAG} image..."

${CONTAINER_BUILD} -t "resolve:${TAG}" -t "resolve" --build-arg ARCH=`arch` --build-arg ZIPNAME="${ZIPNAME}" --build-arg NVIDIA_VERSION="${NVIDIA_VERSION}"

# remove any context link
if [ -f "${CONTEXT_ZIP}" ]; then
   rm -f "${CONTEXT_ZIP}"
fi

echo -e "Build of resolve:${TAG} is complete.  To run resolve, try:\n\n./resolve.sh\n"
