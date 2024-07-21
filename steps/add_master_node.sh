#!/bin/bash

set -e

if [ "$#" -ne 5 ]; then
    echo "Usage: $0 <path_of_folder> <new_master_node_hostname> <new_master_node_ip> <existing_master_node_ip> <load_balancer_ip>"
    exit 1
fi

FOLDER_PATH=$1
NEW_MASTER_NODE_HOSTNAME=$2
NEW_MASTER_NODE_IP=$3
EXISTING_MASTER_NODE_IP=$4
LOAD_BALANCER_IP=$5
SSH_USER="root"

# Check if node is already part of the cluster
if ssh $SSH_USER@$NEW_MASTER_NODE_IP "kubectl get nodes -o wide | grep -q $NEW_MASTER_NODE_IP"; then
    echo "Node $NEW_MASTER_NODE_IP is already part of the cluster. Exiting."
    exit 1
elif ssh $SSH_USER@$NEW_MASTER_NODE_IP "kubectl get nodes -o wide" 2>&1 | grep -q -e 'connection refused' -e 'no route to host'; then
    echo "Kubernetes seems to be improperly configured on $NEW_MASTER_NODE_IP. Reinstalling..."
    ./remove_node_and_uninstall.sh $FOLDER_PATH $NEW_MASTER_NODE_HOSTNAME $NEW_MASTER_NODE_IP $EXISTING_MASTER_NODE_IP
fi

# Change to the specified directory
cd $FOLDER_PATH

# Execute the steps in sequence
#./set_hostname.sh $NEW_MASTER_NODE_HOSTNAME $NEW_MASTER_NODE_IP
./configure_sysctl.sh $NEW_MASTER_NODE_IP
./install_docker.sh $NEW_MASTER_NODE_IP
./configure_containerd.sh $NEW_MASTER_NODE_IP
./install_kubernetes.sh $NEW_MASTER_NODE_IP
./join_master.sh $NEW_MASTER_NODE_IP $EXISTING_MASTER_NODE_IP $LOAD_BALANCER_IP

echo "New master node setup complete."

