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

# Uninstall Docker and Kubernetes
ssh -t $SSH_USER@$SERVER_IP <<EOF >/dev/null
# Reset and stop services
sudo kubeadm reset -f >/dev/null
sudo systemctl stop kubelet >/dev/null
sudo systemctl stop docker >/dev/null

# Unhold packages
sudo apt-mark unhold kubelet kubeadm kubectl >/dev/null

# Remove Docker and Kubernetes packages
sudo apt-get purge -y kubeadm kubectl kubelet kubernetes-cni kube* >/dev/null
sudo apt-get purge -y docker-engine docker docker.io docker-ce docker-ce-cli docker* containerd containerd.io >/dev/null
sudo apt-get autoremove -y >/dev/null
sudo apt-get update >/dev/null

# Remove directories and files
sudo rm -rf /etc/kubernetes/ /var/lib/etcd /var/lib/kubelet /etc/cni/net.d /opt/cni
sudo rm -rf /var/lib/docker /etc/docker /var/run/docker.sock /usr/bin/docker-compose
sudo rm -rf ~/.kube /etc/systemd/system/kubelet.service.d /etc/systemd/system/kubelet.service /usr/bin/kube* /usr/local/bin/kubectl /var/lib/dockershim /var/lib/kubelet /var/lib/etcd /etc/kubernetes /var/run/kubernetes /etc/cni/net.d
sudo rm -rf /var/lib/containerd

# Ensure any remaining Kubernetes packages are removed
sudo dpkg --list | grep kube | awk '{print \$2}' | xargs -r sudo apt-get purge -y >/dev/null

# Ensure any remaining Docker packages are removed
sudo dpkg --list | grep docker | awk '{print \$2}' | xargs -r sudo apt-get purge -y >/dev/null

# Ensure apt sources lists are removed
sudo rm -rf /etc/apt/sources.list.d/*

# Double-check removal of any remaining directories and files
sudo rm -rf /var/lib/containerd /etc/docker /var/run/docker.sock /usr/bin/docker-compose /usr/local/bin/kubectl /var/lib/kubelet /var/lib/etcd /etc/kubernetes /etc/cni/net.d

sudo apt-get autoremove -y >/dev/null
sudo apt-get update >/dev/null
EOF

echo "Docker and Kubernetes uninstalled on $SERVER_IP"

