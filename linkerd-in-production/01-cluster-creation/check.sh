#!/bin/bash

check () {
    cmd="$1"
    source="$2"

    if ! command -v $cmd >/dev/null 2>&1; then
        echo "Error: $cmd not found. You can get it from $source" >&2
        exit 1
    fi
}

# check k3d "https://k3d.io"
check step "https://smallstep.com/docs/step-cli/installation"
check kubectl "https://kubernetes.io/docs/tasks/tools/#kubectl"
check helm "https://helm.sh/docs/intro/install/"

#@print "# Great, you have all the tools we need!"
