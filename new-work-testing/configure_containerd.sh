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
    ssh $SSH_USER@$SERVER_IP "
    if grep -q 'SystemdCgroup = true' /etc/containerd/config.toml; then
        echo 'SystemdCgroup is already set to true on $SERVER_IP'
    else
        sudo containerd config default >/dev/null | sudo tee /etc/containerd/config.toml >/dev/null
        sudo sed -i 's/\(SystemdCgroup = \).*/\1true/' /etc/containerd/config.toml >/dev/null
        sudo systemctl restart containerd >/dev/null
        echo 'SystemdCgroup set to true and containerd restarted on $SERVER_IP'
    fi
    " >/dev/null
else
    echo "Unable to SSH into $SERVER_IP"
fi

