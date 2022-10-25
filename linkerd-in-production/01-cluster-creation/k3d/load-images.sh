#!/bin/bash

set -e

# scriptdir is the directory this script lives in
scriptdir=$(cd $(dirname $0) ; pwd)
cd "${scriptdir}"

CLUSTER_NAME="$1"

if [ -z "${CLUSTER_NAME}" ]; then \
    echo "Usage: $0 <cluster-name>" >&2 ;\
    exit 1 ;\
fi

#@SHOW

#@echo
# After that, we're going to cheat a bit and pre-load a bunch of
# images for things we'll need. This will take a little bit of time,
# but save us a lot of bandwidth.

k3d image import -c ${CLUSTER_NAME} images.tar
