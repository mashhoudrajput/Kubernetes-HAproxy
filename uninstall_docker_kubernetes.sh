#!/bin/bash

set -e

# Check if arguments are provided
if [ "$#" -ne 1 ]; then
    echo "Usage: $0 <server_ip>"
    exit 1
fi

SERVER_IP=$1
SSH_USER="root"

# Uninstall Docker and Kubernetes
ssh $SSH_USER@$SERVER_IP <<EOF
# Reset and stop services
sudo kubeadm reset -f
sudo systemctl stop kubelet
sudo systemctl stop docker

# Unhold packages
sudo apt-mark unhold kubelet kubeadm kubectl

# Remove Docker and Kubernetes packages
sudo apt-get purge -y kubeadm kubectl kubelet kubernetes-cni kube*
sudo apt-get purge -y docker-engine docker docker.io docker-ce docker-ce-cli docker* containerd containerd.io
sudo apt-get autoremove -y
sudo apt-get update

# Remove directories and files
sudo rm -rf /etc/kubernetes/ /var/lib/etcd /var/lib/kubelet /etc/cni/net.d /opt/cni
sudo rm -rf /var/lib/docker /etc/docker /var/run/docker.sock /usr/bin/docker-compose
sudo rm -rf ~/.kube /etc/systemd/system/kubelet.service.d /etc/systemd/system/kubelet.service /usr/bin/kube* /usr/local/bin/kubectl /var/lib/dockershim /var/lib/kubelet /var/lib/etcd /etc/kubernetes /var/run/kubernetes /etc/cni/net.d
sudo rm -rf /var/lib/containerd

# Ensure any remaining Kubernetes packages are removed
sudo dpkg --list | grep kube | awk '{print \$2}' | xargs -r sudo apt-get purge -y

# Ensure any remaining Docker packages are removed
sudo dpkg --list | grep docker | awk '{print \$2}' | xargs -r sudo apt-get purge -y

# Ensure apt sources lists are removed
sudo rm -rf /etc/apt/sources.list.d/*

# Double-check removal of any remaining directories and files
sudo rm -rf /var/lib/containerd /etc/docker /var/run/docker.sock /usr/bin/docker-compose /usr/local/bin/kubectl /var/lib/kubelet /var/lib/etcd /etc/kubernetes /etc/cni/net.d

sudo apt-get autoremove -y
sudo apt-get update

EOF

echo "Docker and Kubernetes uninstalled on $SERVER_IP"

