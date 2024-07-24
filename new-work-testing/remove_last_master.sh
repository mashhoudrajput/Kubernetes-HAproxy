#!/bin/bash

set -e

# Load environment variables
source ./env.sh

if [ "$#" -ne 1 ]; then
    echo "Usage: $0 <node_ip>"
    exit 1
fi

NODE_IP=$1

# Change to the specified directory
cd $FOLDER_PATH

# Execute the steps in sequence
./uninstall_docker_kubernetes.sh $NODE_IP

