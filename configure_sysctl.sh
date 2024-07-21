#!/bin/bash

set -e

# Check if arguments are provided
if [ "$#" -ne 1 ]; then
    echo "Usage: $0 <server_ip>"
    exit 1
fi

SERVER_IP=$1
SSH_USER="root"

# Check SSH connectivity
if ssh -o BatchMode=yes -o ConnectTimeout=5 $SSH_USER@$SERVER_IP "exit"; then
    # Check if the value is already set
    if ssh $SSH_USER@$SERVER_IP "grep -q '^net.ipv4.ip_forward = 1' /etc/sysctl.d/k8s.conf"; then
        echo "net.ipv4.ip_forward is already set on $SERVER_IP"
    else
        ssh $SSH_USER@$SERVER_IP "echo 'net.ipv4.ip_forward = 1' | sudo tee /etc/sysctl.d/k8s.conf && sudo sysctl --system"
        echo "Sysctl configured on $SERVER_IP"
    fi
else
    echo "Unable to SSH into $SERVER_IP"
fi

