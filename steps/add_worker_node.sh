#!/bin/bash

set -e

if [ "$#" -ne 5 ]; then
    echo "Usage: $0 <path_of_folder> <new_worker_node_hostname> <new_worker_node_ip> <existing_master_node_ip> <load_balancer_ip>"
    exit 1
fi

FOLDER_PATH=$1
NEW_WORKER_NODE_HOSTNAME=$2
NEW_WORKER_NODE_IP=$3
EXISTING_MASTER_NODE_IP=$4
LOAD_BALANCER_IP=$5
SSH_USER="root"

# Change to the specified directory
cd $FOLDER_PATH

# Check if node is already part of the cluster
if ssh $SSH_USER@$EXISTING_MASTER_NODE_IP "kubectl get nodes -o wide | grep -q $NEW_WORKER_NODE_IP"; then
    echo "Node $NEW_WORKER_NODE_IP is already part of the cluster. Exiting."
    exit 1
fi

# Execute the steps in sequence
#./set_hostname.sh $NEW_WORKER_NODE_HOSTNAME $NEW_WORKER_NODE_IP
./configure_sysctl.sh $NEW_WORKER_NODE_IP
./install_docker.sh $NEW_WORKER_NODE_IP
./configure_containerd.sh $NEW_WORKER_NODE_IP
./install_kubernetes.sh $NEW_WORKER_NODE_IP
./join_worker.sh $NEW_WORKER_NODE_IP $EXISTING_MASTER_NODE_IP $LOAD_BALANCER_IP

echo "New worker node setup complete."

