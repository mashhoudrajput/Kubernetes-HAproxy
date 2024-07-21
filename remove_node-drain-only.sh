#!/bin/bash

set -e

# Check if arguments are provided
if [ "$#" -ne 1 ]; then
    echo "Usage: $0 <node_name>"
    exit 1
fi

NODE_NAME=$1

# Remove node from Kubernetes cluster
kubectl drain $NODE_NAME --delete-emptydir-data --force --ignore-daemonsets
kubectl delete node $NODE_NAME

echo "Node $NODE_NAME drained and removed from the Kubernetes cluster"

