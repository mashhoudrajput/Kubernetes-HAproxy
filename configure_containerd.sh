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
    ssh $SSH_USER@$SERVER_IP "
    if grep -q 'SystemdCgroup = true' /etc/containerd/config.toml; then
        echo 'SystemdCgroup is already set to true on $SERVER_IP'
    else
	sudo containerd config default | sudo tee /etc/containerd/config.toml > /dev/null
        sudo sed -i 's/\(SystemdCgroup = \).*/\1true/' /etc/containerd/config.toml > /dev/null
        sudo systemctl restart containerd
        echo 'SystemdCgroup set to true and containerd restarted on $SERVER_IP'
    fi
    "
else
    echo "Unable to SSH into $SERVER_IP"
fi

