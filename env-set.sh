# DO NOT RUN THIS SCRIPT DIRECTLY!

# set the repo path (where these scripts + Dockerfile are)

REPO_DIR=$(dirname $(realpath -s $0))

# if RESOLVE_RC_PATH is set, source it to pull in additional ENV settings, run pre-flight commands, etc.

if ! [ -z ${RESOLVE_RC_PATH} ]; then
   echo "Running:  " ${RESOLVE_RC_PATH}
   source "${RESOLVE_RC_PATH}"
fi

# determine if podman or docker installed

if  [ -z "$(podman -v 2>&1 | grep -i 'not found')" ] && [ -z $(echo ${RESOLVE_CONTAINER_ENGINE} | grep -v -i podman) ]; then
   CONTAINER_ENGINE="podman"
   if command -v buildah 2>&1 > /dev/null; then
      CONTAINER_BUILD="buildah bud"
   else
      CONTAINER_BUILD="podman build ."
   fi
   CONTAINER_EXISTS="podman image exists"
   CONTAINER_RUN_ARGS=" --annotation run.oci.keep_original_groups=1 --userns=keep-id"
elif  [ -z "$(docker -v 2>&1 | grep -i 'not found')" ] && [ -n "$(docker -v 2>&1 | grep -i 'version')" ] && [ -z $(echo ${RESOLVE_CONTAINER_ENGINE} | grep -v -i docker) ]; then
   CONTAINER_ENGINE="docker"
   CONTAINER_BUILD="docker build ."
   CONTAINER_EXISTS="docker images -q"
   CONTAINER_RUN_ARGS=" --env PODMANOPT=no --env PODMANGROUPS=no"
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

# Read custom bind mounts from configuration file
if [ -f "${BASH_SOURCE%/*}/bind_mounts.conf" ]; then
   echo "Reading bind mounts from bind_mounts.conf..."
   while IFS= read -r source || [ -n "$source" ]; do
      # Skip empty lines
      [ -z "$source" ] && continue

      # Skip comment lines (lines starting with #)
      [ "${source:0:1}" = "#" ] && continue

      # Check if the line defines a TARGET
      if [[ "$source" =~ ^TARGET=.* ]]; then
         TARGET="${source#TARGET=}"
         echo "Setting target path within container to: $TARGET"
         continue
      fi

      # Trim whitespace from source path
      source="${source#"${source%%[![:space:]]*}"}"
      source="${source%"${source##*[![:space:]]}"}"

      # Replace ~ with the home directory
      source="${source//\~/$HOME}"

      if [ ! -e "$source" ]; then
         echo "Warning: Bind mount source path does not exist: $source"
         continue
      fi

      if [ ! -r "$source" ]; then
         echo "Warning: Bind mount source path is not readable: $source"
         continue
      fi

      # Create a sanitized target name from the source path's basename
      target_name=$(basename "$source" | tr ' ' '_')

      if [ -z "$TARGET" ]; then
         TARGET="/opt/resolve/Media"
      fi

      target="${TARGET}/${target_name}"
      RESOLVE_BIND_SOURCES+=("$source")
      RESOLVE_BIND_TARGETS+=("$target")
      echo "Added bind mount: $source -> $target"
   done <"${BASH_SOURCE%/*}/bind_mounts.conf"
fi

# and notify if other tags were overridden

if [ ! -z ${RESOLVE_TAG} ]; then
   echo "The container tag (RESOLVE_TAG) was manually set to : ${RESOLVE_TAG}"
fi

if [ ! -z ${RESOLVE_ZIP} ]; then
   echo "The Resolve zip file location (RESOLVE_ZIP) was manually set to : ${RESOLVE_ZIP}"
fi
