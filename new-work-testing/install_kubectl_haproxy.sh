#!/bin/bash

set -e

# Load environment variables
source ./env.sh

# Check if arguments are provided
if [ "$#" -ne 2 ]; then
    echo "Usage: $0 <load_balancer_ip> <master_node_ip>"
    exit 1
fi

LOAD_BALANCER_IP=$1
MASTER_NODE_IP=$2

# Function to extract the load balancer hostname from /tmp/hosts file
extract_load_balancer_hostname() {
    local HOSTS_FILE="/tmp/hosts"
    if [ -f "$HOSTS_FILE" ]; then
        LOAD_BALANCER_HOSTNAME=$(grep "$LOAD_BALANCER_IP" "$HOSTS_FILE" | awk '{print $2}')
        if [ -z "$LOAD_BALANCER_HOSTNAME" ]; then
            echo "Load balancer hostname not found in $HOSTS_FILE"
            exit 1
        fi
    else
        echo "$HOSTS_FILE not found"
        exit 1
    fi
}

# Function to check SSH connection
check_ssh() {
    local IP=$1
    echo "Checking SSH connection to $IP..."
    ssh -o BatchMode=yes -o ConnectTimeout=5 $SSH_USER@$IP "exit" >/dev/null
    if [ $? -eq 0 ]; then
        echo "SSH connection to $IP successful"
    else
        echo "SSH connection to $IP failed"
        exit 1
    fi
}

# Function to verify hostname
verify_hostname() {
    local IP=$1
    local EXPECTED_HOSTNAME=$2
    echo "Verifying hostname for $IP..."
    local HOSTNAME=$(ssh $SSH_USER@$IP "hostname" 2>/dev/null)
    if [ "$HOSTNAME" == "$EXPECTED_HOSTNAME" ]; then
        echo "Hostname verification successful: $HOSTNAME"
    else
        echo "Hostname verification failed: Expected $EXPECTED_HOSTNAME, but got $HOSTNAME"
        exit 1
    fi
}

# Function to install kubectl
install_kubectl() {
    echo "Checking if kubectl is already installed..."
    if command -v kubectl &> /dev/null; then
        echo "kubectl is already installed"
    else
        echo "Installing kubectl..."
        sudo apt-get update -qq >/dev/null
        sudo apt-get install -y apt-transport-https ca-certificates curl telnet net-tools jq -qq >/dev/null
        sudo rm -f /etc/apt/keyrings/kubernetes-apt-keyring.gpg >/dev/null
        curl -fsSL https://pkgs.k8s.io/core:/stable:/v1.28/deb/Release.key | sudo gpg --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg >/dev/null
        echo 'deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/v1.28/deb/ /' | sudo tee /etc/apt/sources.list.d/kubernetes.list >/dev/null
        sudo apt-get update -qq >/dev/null
        sudo apt-get install -y kubectl -qq >/dev/null
    fi
}

# Function to configure kubectl
configure_kubectl() {
    echo "Configuring kubectl on $LOAD_BALANCER_IP..."
    ssh $SSH_USER@$LOAD_BALANCER_IP "sudo mkdir -p /etc/kubernetes" >/dev/null
    scp /tmp/admin.conf $SSH_USER@$LOAD_BALANCER_IP:/etc/kubernetes/admin.conf >/dev/null
    ssh $SSH_USER@$LOAD_BALANCER_IP << EOF
        mkdir -p \$HOME/.kube
        sudo rm -rf \$HOME/.kube/*
        sudo cp /etc/kubernetes/admin.conf \$HOME/.kube/config
        sudo chown \$(id -u):\$(id -g) \$HOME/.kube/config
EOF
    echo "kubectl configured on $LOAD_BALANCER_IP using the configuration from master node: $MASTER_NODE_IP"
}

# Extract load balancer hostname
extract_load_balancer_hostname

# Check SSH connections
check_ssh $LOAD_BALANCER_IP
check_ssh $MASTER_NODE_IP

# Verify hostname for load balancer
verify_hostname $LOAD_BALANCER_IP $LOAD_BALANCER_HOSTNAME

# SSH into the HAProxy server and install kubectl
ssh $SSH_USER@$LOAD_BALANCER_IP "$(typeset -f install_kubectl); install_kubectl"
echo "kubectl installed on $LOAD_BALANCER_IP"

# Copy Kubernetes configuration from master node to the HAProxy server
echo "Copying Kubernetes configuration from master node..."
scp $SSH_USER@$MASTER_NODE_IP:/etc/kubernetes/admin.conf /tmp/admin.conf >/dev/null

# Configure kubectl on HAProxy server
configure_kubectl

