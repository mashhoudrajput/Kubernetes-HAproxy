#!/bin/bash

set -e

# Load environment variables
source ./env.sh

if [ "$#" -ne 3 ]; then
    echo "Usage: $0 <master_node_hostname> <master_node_ip> <load_balancer_ip>"
    exit 1
fi

MASTER_NODE_HOSTNAME=$1
MASTER_NODE_IP=$2
LOAD_BALANCER_IP=$3

# Change to the specified directory
cd $FOLDER_PATH

# Check if cluster already exists
if ssh $SSH_USER@$MASTER_NODE_IP "[ -f /etc/kubernetes/admin.conf ]" >/dev/null; then
    echo "Cluster already exists on $MASTER_NODE_IP. Exiting."
    exit 1
fi

# Execute the steps in sequence
./configure_sysctl.sh $MASTER_NODE_IP
./install_docker.sh $MASTER_NODE_IP
./configure_containerd.sh $MASTER_NODE_IP
./install_kubernetes.sh $MASTER_NODE_IP
./initialize_master.sh $MASTER_NODE_IP $LOAD_BALANCER_IP
./install_kubectl_haproxy.sh $LOAD_BALANCER_IP $MASTER_NODE_IP

echo "Cluster setup complete."

