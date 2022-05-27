# DO NOT RUN THIS SCRIPT DIRECTLY!

# set the repo path (where these scripts + Dockerfile are)

REPO_DIR=$(dirname $(realpath -s $0))

# if RESOLVE_RC_PATH is set, source it to pull in additional ENV settings, run pre-flight commands, etc.

if ! [ -z ${RESOLVE_RC_PATH} ]; then
   echo "Running:  " ${RESOLVE_RC_PATH}
   source "${RESOLVE_RC_PATH}"
fi

# determine if podman or docker installed

if ! command -v podman &> /dev/null; then
   CONTAINER_TYPE="docker"
   CONTAINER_BUILD="docker build ."
   CONTAINER_EXISTS="docker images -q"
   CONTAINER_RUN_ARGS=" --env PODMANOPT=no --env PODMANGROUPS=no"
elif ! command -v docker &> /dev/null; then
   CONTAINER_TYPE="podman"
   CONTAINER_BUILD="buildah bud"
   CONTAINER_EXISTS="podman image exists"
   CONTAINER_RUN_ARGS=" --annotation run.oci.keep_original_groups=1 --userns=keep-id"
else
   echo "You must install either podman or docker and try again."
   exit 1
fi

# set the mount path

if [ -z ${RESOLVE_MOUNTS_PATH+x} ]; then
   RESOLVE_MOUNTS_PATH=${REPO_DIR}

else
   echo "The container's bind-mounts path (RESOLVE_MOUNTS_PATH) was manually set to : ${RESOLVE_MOUNTS_PATH}"
fi

# and notify if other tags were overridden

if [ ! -z ${RESOLVE_TAG} ]; then
   echo "The container tag (RESOLVE_TAG) was manually set to : ${RESOLVE_TAG}"
fi

if [ ! -z ${RESOLVE_ZIP} ]; then
   echo "The Resolve zip file location (RESOLVE_ZIP) was manually set to : ${RESOLVE_ZIP}"
fi

