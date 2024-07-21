#!/bin/bash

set -e

# Check if arguments are provided
if [ "$#" -ne 3 ]; then
    echo "Usage: $0 <server_ip> <existing_master_node_ip> <load_balancer_ip>"
    exit 1
fi

SERVER_IP=$1
EXISTING_MASTER_NODE_IP=$2
LOAD_BALANCER_IP=$3

SSH_USER="root"
DETAILS_FILE="kubeadm-join-details.txt"

# Function to check SSH connectivity
check_ssh() {
    if ssh -o BatchMode=yes -o ConnectTimeout=5 $SSH_USER@$1 "exit"; then
        return 0
    else
        echo "Unable to SSH into $1"
        exit 1
    fi
}

# Function to read details from file
read_details_from_file() {
    if [ -f "$DETAILS_FILE" ]; then
        source "$DETAILS_FILE"
        if [ -n "$token" ] && [ -n "$hash_key" ]; then
            return 0
        fi
    fi
    return 1
}

# Function to write details to file
write_details_to_file() {
    echo "token=$token" > "$DETAILS_FILE"
    echo "hash_key=$hash_key" >> "$DETAILS_FILE"
    if [ -n "$certificate_key" ]; then
        echo "certificate_key=$certificate_key" >> "$DETAILS_FILE"
    fi
}

# Function to validate token
validate_token() {
    ssh $SSH_USER@$EXISTING_MASTER_NODE_IP "kubeadm token list | grep -q $token"
}

# Check SSH connectivity
check_ssh $SERVER_IP

# Get the node's hostname
NODE_NAME=$(ssh $SSH_USER@$SERVER_IP "hostname")

# Check if the node is already part of the cluster
if ssh $SSH_USER@$EXISTING_MASTER_NODE_IP "kubectl get nodes -o wide | grep -w $SERVER_IP"; then
    echo "Node $SERVER_IP is already part of the cluster."
else
    if read_details_from_file && validate_token; then
        echo "Using existing valid details from $DETAILS_FILE"
    else
        echo "Generating new token and hash key."
        certificate_key=$(ssh $SSH_USER@$EXISTING_MASTER_NODE_IP "kubeadm init phase upload-certs --upload-certs | tail -n 1")
        join_command=$(ssh $SSH_USER@$EXISTING_MASTER_NODE_IP "kubeadm token create --print-join-command --certificate-key $certificate_key")
        token=$(echo $join_command | grep -oP '(?<=--token\s)[^\s]+')
        hash_key=$(echo $join_command | grep -oP '(?<=--discovery-token-ca-cert-hash\s)[^\s]+')
        write_details_to_file
    fi

    # Construct the kubeadm join command
    KUBEADM_JOIN_CMD="kubeadm join $LOAD_BALANCER_IP:6443 --token $token --discovery-token-ca-cert-hash $hash_key"
    echo $KUBEADM_JOIN_CMD

    # Validate the kubeadm join command by checking token and hash_key
    token_valid=$(ssh $SSH_USER@$EXISTING_MASTER_NODE_IP "kubeadm token list | grep -q $token && echo valid || echo invalid")
    echo "Token validation: $token_valid"
    echo "Hash key: $hash_key"

    if [ "$token_valid" == "valid" ]; then
        echo "Token is valid."
    else
        echo "Token is invalid."
    fi

    if [[ $hash_key =~ ^sha256:[a-f0-9]{64}$ ]]; then
        echo "Hash key is valid."
    else
        echo "Hash key is invalid."
    fi

    ssh $SSH_USER@$SERVER_IP "$KUBEADM_JOIN_CMD"
    ssh $SSH_USER@$EXISTING_MASTER_NODE_IP "kubectl label node $NODE_NAME node-role.kubernetes.io/worker=worker"
fi

