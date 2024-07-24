#!/bin/bash

set -e

# Check if arguments are provided
if [ "$#" -ne 1 ]; then
    echo "Usage: $0 <server_ip>"
    exit 1
fi

SERVER_IP=$1
SSH_USER=root

# Function to perform SSH actions
reset_node() {
    ssh $SSH_USER@$SERVER_IP << 'EOF' > /dev/null 2>&1
set -e
{
    sudo kubeadm reset -f
    sudo systemctl stop kubelet
    sudo systemctl stop docker
    sudo rm -rf /var/lib/cni/ /var/lib/kubelet/* /var/lib/etcd/* /etc/cni /opt/cni /etc/kubernetes/* /var/run/kubernetes/* ~/.kube
    sudo systemctl start kubelet
    sudo systemctl start docker
} > /dev/null 2>&1
EOF

    if [ $? -eq 0 ]; then
        echo "Node reset on $SERVER_IP"
    else
        echo "An error occurred while resetting the node on $SERVER_IP"
    fi
}

# Check SSH connectivity and reset node
if ssh -o BatchMode=yes -o ConnectTimeout=5 $SSH_USER@$SERVER_IP "exit" > /dev/null 2>&1; then
    reset_node
else
    echo "Unable to SSH into $SERVER_IP"
fi

