#!/bin/bash

set -e

if [ "$#" -ne 4 ]; then
    echo "Usage: $0 <path_of_folder> <node_hostname> <node_ip> <existing_master_ip>"
    exit 1
fi

FOLDER_PATH=$1
NODE_HOSTNAME=$2
NODE_IP=$3
EXISTING_MASTER_IP=$4
SSH_USER="root"

# Change to the specified directory
cd $FOLDER_PATH

# Prompt for action
echo "Select action to perform:"
echo "1. Add as Master"
echo "2. Add as Worker"
echo "3. Add as both Master and Worker"
read -p "Enter choice [1-3]: " action

if [ "$action" == "1" ]; then
    # Check if node is already part of the cluster as a master
    if ssh $SSH_USER@$EXISTING_MASTER_IP "kubectl get nodes -o wide | grep -q $SERVER_IP"; then
        echo "Node $SERVER_IP is already part of the cluster. Exiting."
        exit 1
    fi

    # Add as Master
    ./set_hostname.sh $NODE_HOSTNAME $NODE_IP
    ./configure_sysctl.sh $NODE_IP
    ./install_docker.sh $NODE_IP
    ./configure_containerd.sh $NODE_IP
    ./install_kubernetes.sh $NODE_IP
    ./join_master.sh $NODE_IP $EXISTING_MASTER_IP
    echo "New master node setup complete."

elif [ "$action" == "2" ]; then
    # Check if node is already part of the cluster as a worker
    if ssh $SSH_USER@$EXISTING_MASTER_IP "kubectl get nodes -o wide | grep -q $SERVER_IP"; then
        echo "Node $SERVER_IP is already part of the cluster. Exiting."
        exit 1
    fi

    # Add as Worker
    ./set_hostname.sh $NODE_HOSTNAME $NODE_IP
    ./configure_sysctl.sh $NODE_IP
    ./install_docker.sh $NODE_IP
    ./configure_containerd.sh $NODE_IP
    ./install_kubernetes.sh $NODE_IP
    ./join_worker.sh $NODE_IP $EXISTING_MASTER_IP
    echo "New worker node setup complete."

elif [ "$action" == "3" ]; then
    # Check if node is already part of the cluster as a master or worker
    if ssh $SSH_USER@$EXISTING_MASTER_IP "kubectl get nodes -o wide | grep -q $SERVER_IP"; then
        echo "Node $SERVER_IPE is already part of the cluster. Exiting."
        exit 1
    fi

    # Add as both Master and Worker
    ./set_hostname.sh $NODE_HOSTNAME $NODE_IP
    ./configure_sysctl.sh $NODE_IP
    ./install_docker.sh $NODE_IP
    ./configure_containerd.sh $NODE_IP
    ./install_kubernetes.sh $NODE_IP
    ./join_master.sh $NODE_IP $EXISTING_MASTER_IP
    
    # Remove taints to allow scheduling of workloads and add worker label
    if kubectl get node $NODE_HOSTNAME -o json | jq -e '.spec.taints[] | select(.key=="node-role.kubernetes.io/master")' > /dev/null; then
        kubectl taint nodes $NODE_HOSTNAME node-role.kubernetes.io/master:NoSchedule-
    fi
    if kubectl get node $NODE_HOSTNAME -o json | jq -e '.spec.taints[] | select(.key=="node-role.kubernetes.io/control-plane")' > /dev/null; then
        kubectl taint nodes $NODE_HOSTNAME node-role.kubernetes.io/control-plane:NoSchedule-
    fi
    kubectl label nodes $NODE_HOSTNAME node-role.kubernetes.io/worker=

    echo "New node setup complete as both master and worker."

else
    echo "Invalid choice. Please enter 1, 2, or 3."
    exit 1
fi

