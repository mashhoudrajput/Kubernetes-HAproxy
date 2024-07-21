#!/bin/bash

set -e

if [ "$#" -ne 4 ]; then
    echo "Usage: $0 <path_of_folder> <node_hostname> <node_ip> <existing_master_ip>"
    exit 1
fi

FOLDER_PATH=$1
NODE_HOSTNAME=$2
NODE_IP=$3
EXISTING_MASTER_IP=$4

# Change to the specified directory
cd $FOLDER_PATH

# Execute the steps in sequence
./remove_node.sh $NODE_HOSTNAME $NODE_IP $EXISTING_MASTER_IP
./uninstall_docker_kubernetes.sh $NODE_IP

echo "Node removed and Docker and Kubernetes uninstalled from $NODE_IP."

