#!/bin/bash
helm uninstall -n linkerd linkerd-control-plane
helm uninstall -n linkerd linkerd-crds
