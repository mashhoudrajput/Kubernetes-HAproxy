#!/bin/bash

set -e

# Load environment variables
source ./env.sh

# Function to read host entries from a file and store them in an associative array
read_hosts_file() {
    local HOSTS_FILE=$1
    declare -A HOSTS_ENTRIES
    while IFS=" " read -r IP HOSTNAME; do
        HOSTS_ENTRIES["$IP"]=$HOSTNAME
    done < "$HOSTS_FILE"
    echo "$(declare -p HOSTS_ENTRIES)"
}

# Function to check and add host entries
update_hosts() {
    local SERVER_IP=$1
    local HOSTS_ENTRIES_STRING=$2
    eval "declare -A HOSTS_ENTRIES="${HOSTS_ENTRIES_STRING#*=}

    # Check SSH connectivity
    if ssh -o BatchMode=yes -o ConnectTimeout=5 $SSH_USER@$SERVER_IP "exit" >/dev/null; then
        echo "Updating /etc/hosts on $SERVER_IP"
        for IP in "${!HOSTS_ENTRIES[@]}"; do
            HOSTNAME=${HOSTS_ENTRIES[$IP]}
            if ssh $SSH_USER@$SERVER_IP "grep -q '$IP $HOSTNAME' /etc/hosts" >/dev/null; then
                #echo "Entry '$IP $HOSTNAME' already exists on $SERVER_IP"
                :
            else
                ssh $SSH_USER@$SERVER_IP "echo '$IP $HOSTNAME' | sudo tee -a /etc/hosts" >/dev/null
                echo "Added '$IP $HOSTNAME' to /etc/hosts on $SERVER_IP"
            fi
        done
    else
        echo "Unable to SSH into $SERVER_IP"
    fi
}

# Function to check and set the hostname on the server
set_hostname() {
    local SERVER_IP=$1
    local HOSTNAME=$2

    # Check SSH connectivity
    if ssh -o BatchMode=yes -o ConnectTimeout=5 $SSH_USER@$SERVER_IP "exit" >/dev/null; then
        CURRENT_HOSTNAME=$(ssh $SSH_USER@$SERVER_IP "hostname" 2>/dev/null)
        if [ "$CURRENT_HOSTNAME" != "$HOSTNAME" ]; then
            echo "Setting hostname to '$HOSTNAME' on $SERVER_IP"
            ssh $SSH_USER@$SERVER_IP "sudo hostnamectl set-hostname $HOSTNAME" >/dev/null
            echo "Hostname set to '$HOSTNAME' on $SERVER_IP"
        fi
    else
        echo "Unable to SSH into $SERVER_IP"
    fi
}

# Read the hosts file and get the associative array
HOSTS_ENTRIES_STRING=$(read_hosts_file "$HOSTS_FILE")

# Update hosts file and set hostname on each server
for SERVER_IP in $(awk '{print $1}' $HOSTS_FILE); do
    update_hosts $SERVER_IP "$HOSTS_ENTRIES_STRING"
    HOSTNAME=$(awk -v ip=$SERVER_IP '$1 == ip {print $2}' $HOSTS_FILE)
    set_hostname $SERVER_IP $HOSTNAME
done

