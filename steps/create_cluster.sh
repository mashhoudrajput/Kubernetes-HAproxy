#!/bin/bash

set -e

if [ "$#" -ne 4 ]; then
    echo "Usage: $0 <path_of_folder> <master_node_hostname> <master_node_ip> <load_balancer_ip>"
    exit 1
fi

FOLDER_PATH=$1
MASTER_NODE_HOSTNAME=$2
MASTER_NODE_IP=$3
LOAD_BALANCER_IP=$4
SSH_USER="root"

# Change to the specified directory
cd $FOLDER_PATH

# Check if cluster already exists
if ssh $SSH_USER@$MASTER_NODE_IP "[ -f /etc/kubernetes/admin.conf ]"; then
    echo "Cluster already exists on $MASTER_NODE_IP. Exiting."
    exit 1
fi

# Execute the steps in sequence
#./set_hostname.sh $MASTER_NODE_HOSTNAME $MASTER_NODE_IP
./configure_sysctl.sh $MASTER_NODE_IP
./install_docker.sh $MASTER_NODE_IP
./configure_containerd.sh $MASTER_NODE_IP
./install_kubernetes.sh $MASTER_NODE_IP
./initialize_master.sh $MASTER_NODE_IP $LOAD_BALANCER_IP
./install_kubectl_haproxy.sh $LOAD_BALANCER_IP $MASTER_NODE_IP

echo "Cluster setup complete."

