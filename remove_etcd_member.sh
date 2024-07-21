#!/bin/bash

set -e

CONTROL_PLANE_IP="172.31.45.63"
TARGET_MEMBER_IP="https://172.31.47.168:2379"
SSH_USER="root"

# Define file paths
ETCD_CA_CERT="/etc/kubernetes/pki/etcd/ca.crt"
ETCD_CERT="/etc/kubernetes/pki/etcd/peer.crt"
ETCD_KEY="/etc/kubernetes/pki/etcd/peer.key"

# Function to check SSH connectivity
check_ssh() {
    if ssh -o BatchMode=yes -o ConnectTimeout=5 $SSH_USER@$1 "exit"; then
        return 0
    else
        echo "Unable to SSH into $1"
        exit 1
    fi
}

# Check SSH connectivity
check_ssh $CONTROL_PLANE_IP

# Get the member list
members=$(ssh $SSH_USER@$CONTROL_PLANE_IP "etcdctl --endpoints=https://$CONTROL_PLANE_IP:2379 --cacert=$ETCD_CA_CERT --cert=$ETCD_CERT --key=$ETCD_KEY member list")

# Find the member ID by IP address
member_id=$(echo "$members" | grep "$TARGET_MEMBER_IP" | awk '{print $1}' | tr -d ',')

if [ -n "$member_id" ]; then
    echo "Removing etcd member with ID: $member_id"
    ssh $SSH_USER@$CONTROL_PLANE_IP "etcdctl --endpoints=https://$CONTROL_PLANE_IP:2379 --cacert=$ETCD_CA_CERT --cert=$ETCD_CERT --key=$ETCD_KEY member remove $member_id"
else
    echo "Etcd member with IP $TARGET_MEMBER_IP not found."
fi

# Verify the removal
ssh $SSH_USER@$CONTROL_PLANE_IP "etcdctl --endpoints=https://$CONTROL_PLANE_IP:2379 --cacert=$ETCD_CA_CERT --cert=$ETCD_CERT --key=$ETCD_KEY member list"

