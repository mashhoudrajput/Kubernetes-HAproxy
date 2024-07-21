!/bin/bash

set -e

if [ "$#" -ne 2 ]; then
    echo "Usage: $0 <path_of_folder> <node_ip>"
    exit 1
fi

FOLDER_PATH=$1
NODE_IP=$2

# Change to the specified directory
cd $FOLDER_PATH

# Execute the steps in sequence
./uninstall_docker_kubernetes.sh $NODE_IP

