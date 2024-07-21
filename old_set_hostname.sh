#!/bin/bash

set -e

# Check if arguments are provided
if [ "$#" -ne 2 ]; then
    echo "Usage: $0 <hostname> <server_ip>"
    exit 1
fi

HOSTNAME=$1
SERVER_IP=$2
SSH_USER="root"

# Check SSH connectivity
if ssh -o BatchMode=yes -o ConnectTimeout=5 $SSH_USER@$SERVER_IP "exit"; then
    ssh $SSH_USER@$SERVER_IP "sudo hostnamectl set-hostname $HOSTNAME"
    echo "Hostname set to $HOSTNAME on $SERVER_IP"
else
    echo "Unable to SSH into $SERVER_IP"
fi

