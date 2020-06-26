#!/usr/bin/env bash

if [[ $# -ne 1 ]]; then
echo "
Usage: $0 utils_folder"
    exit 1
fi
TOOLS_FOLDER=$1
DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
echo ${DIR}

mkdir -p "${DIR}/pkg/"
cp -r ${DIR}/../${TOOLS_FOLDER}/* "${DIR}/pkg/"

cd "${DIR}"
sed "s|ENV BUILD_UTILS=.*|ENV BUILD_UTILS=${TOOLS_FOLDER}|g" "${DIR}/BuildDockerfile" > Dockerfile
docker build -t tools-builder-${TOOLS_FOLDER}:1 -f "${DIR}/Dockerfile" "${DIR}"
rm -rf "${DIR}/pkg"
docker rm -f tools-builder-${TOOLS_FOLDER}; docker create --name tools-builder-${TOOLS_FOLDER} tools-builder-${TOOLS_FOLDER}:1
docker cp tools-builder-${TOOLS_FOLDER}:/${TOOLS_FOLDER} "${DIR}"


