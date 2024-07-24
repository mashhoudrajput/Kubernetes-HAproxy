#!/bin/bash

set -e

# Load environment variables
source ./env.sh

if [ "$#" -ne 4 ]; then
    echo "Usage: $0 <new_worker_node_hostname> <new_worker_node_ip> <existing_master_node_ip> <load_balancer_ip>"
    exit 1
fi

NEW_WORKER_NODE_HOSTNAME=$1
NEW_WORKER_NODE_IP=$2
EXISTING_MASTER_NODE_IP=$3
LOAD_BALANCER_IP=$4

# Change to the specified directory
cd $FOLDER_PATH

# Check if node is already part of the cluster
if ssh $SSH_USER@$EXISTING_MASTER_NODE_IP "kubectl get nodes -o wide | grep -q $NEW_WORKER_NODE_IP" >/dev/null; then
    echo "Node $NEW_WORKER_NODE_IP is already part of the cluster. Exiting."
    exit 1
fi

# Execute the steps in sequence
./configure_sysctl.sh $NEW_WORKER_NODE_IP
./install_docker.sh $NEW_WORKER_NODE_IP
./configure_containerd.sh $NEW_WORKER_NODE_IP
./install_kubernetes.sh $NEW_WORKER_NODE_IP
./join_worker.sh $NEW_WORKER_NODE_IP $EXISTING_MASTER_NODE_IP $LOAD_BALANCER_IP

echo "New worker node setup complete."

