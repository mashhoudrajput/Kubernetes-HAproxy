#!/bin/bash

set -e

# Load environment variables
source ./env.sh

if [ "$#" -ne 3 ]; then
    echo "Usage: $0 <node_hostname> <node_ip> <existing_master_ip>"
    exit 1
fi

NODE_HOSTNAME=$1
NODE_IP=$2
EXISTING_MASTER_IP=$3

# Change to the specified directory
cd $FOLDER_PATH

# Execute the steps in sequence
./remove_node.sh $NODE_HOSTNAME $NODE_IP $EXISTING_MASTER_IP
./uninstall_docker_kubernetes.sh $NODE_IP

echo "Node removed and Docker and Kubernetes uninstalled from $NODE_IP."

