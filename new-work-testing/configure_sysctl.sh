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
    # Check if the value is already set
    if ssh $SSH_USER@$SERVER_IP "grep -q '^net.ipv4.ip_forward = 1' /etc/sysctl.d/k8s.conf" >/dev/null; then
        echo "net.ipv4.ip_forward is already set on $SERVER_IP"
    else
        ssh $SSH_USER@$SERVER_IP "echo 'net.ipv4.ip_forward = 1' | sudo tee /etc/sysctl.d/k8s.conf >/dev/null && sudo sysctl --system >/dev/null"
        echo "Sysctl configured on $SERVER_IP"
    fi
else
    echo "Unable to SSH into $SERVER_IP"
fi

