#!/bin/bash

set -e

# Load environment variables
source ./env.sh

# Check if arguments are provided
if [ "$#" -ne 1 ]; then
    echo "Usage: $0 <server_ip>"
    exit 1
fi

SERVER_IP=$1

# Check SSH connectivity
if ssh -o BatchMode=yes -o ConnectTimeout=5 $SSH_USER@$SERVER_IP "exit" >/dev/null; then
    ssh $SSH_USER@$SERVER_IP << EOF
    sudo apt-get update >/dev/null
    sudo apt-get install -y apt-transport-https ca-certificates curl >/dev/null
    sudo rm -f /etc/apt/keyrings/kubernetes-apt-keyring.gpg >/dev/null
    curl -fsSL https://pkgs.k8s.io/core:/stable:/$K8S_VERSION/deb/Release.key | sudo gpg --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg >/dev/null
    echo 'deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/$K8S_VERSION/deb/ /' | sudo tee /etc/apt/sources.list.d/kubernetes.list >/dev/null
    sudo apt-get update >/dev/null
    sudo apt-get install -y kubelet kubeadm kubectl >/dev/null
    sudo apt-mark hold kubelet kubeadm kubectl >/dev/null
    sudo systemctl enable --now kubelet >/dev/null
EOF
    echo "Kubernetes installed on $SERVER_IP"
else
    echo "Unable to SSH into $SERVER_IP"
fi

