#!/bin/bash

set -e

# Define the hosts entries as an associative array
declare -A HOSTS_ENTRIES=(
    ["172.31.45.63"]="kmaster1"
    ["172.31.33.95"]="kmaster2"
    ["172.31.47.168"]="kmaster3"
    ["172.31.37.166"]="kworker1"
    ["172.31.44.85"]="kworker2"
    ["172.31.45.81"]="lb"
)

# Function to check and add host entries
update_hosts() {
    local SERVER_IP=$1
    local SSH_USER="root"
    local ENTRY

    # Check SSH connectivity
    if ssh -o BatchMode=yes -o ConnectTimeout=5 $SSH_USER@$SERVER_IP "exit"; then
        echo "Updating /etc/hosts on $SERVER_IP"
        for IP in "${!HOSTS_ENTRIES[@]}"; do
            HOSTNAME=${HOSTS_ENTRIES[$IP]}
            if ssh $SSH_USER@$SERVER_IP "grep -q '$IP $HOSTNAME' /etc/hosts"; then
                #echo "Entry '$IP $HOSTNAME' already exists on $SERVER_IP"
            else
                ssh $SSH_USER@$SERVER_IP "echo '$IP $HOSTNAME' | sudo tee -a /etc/hosts"
                echo "Added '$IP $HOSTNAME' to /etc/hosts on $SERVER_IP"
            fi
        done
    else
        echo "Unable to SSH into $SERVER_IP"
    fi
}

# Update hosts file on each server
for SERVER_IP in "${!HOSTS_ENTRIES[@]}"; do
    update_hosts $SERVER_IP
done

