#!/bin/bash

set -e

# Check if arguments are provided
if [ "$#" -ne 3 ]; then
    echo "Usage: $0 <node_name> <server_ip> <existing_master_ip>"
    exit 1
fi

NODE_NAME=$1
SERVER_IP=$2
EXISTING_MASTER_IP=$3
SSH_USER="root"

# Define file paths
ETCD_CA_CERT="/etc/kubernetes/pki/etcd/ca.crt"
ETCD_CERT="/etc/kubernetes/pki/etcd/peer.crt"
ETCD_KEY="/etc/kubernetes/pki/etcd/peer.key"

# Check if node exists in the cluster
if kubectl get node $NODE_NAME > /dev/null 2>&1; then
    # Get the node's IP from the cluster
    NODE_IP=$(kubectl get node $NODE_NAME -o jsonpath='{.status.addresses[?(@.type=="InternalIP")].address}')

    # Verify that the provided IP matches the node's IP
    if [ "$SERVER_IP" == "$NODE_IP" ]; then
        echo "Node $NODE_NAME with IP $SERVER_IP exists in the cluster."
	
	action=3
        # Prompt for action
        #echo "Select action to perform:"
        #echo "1. Drain only"
        #echo "2. SSH only"
        #echo "3. Both drain and SSH"
        #read -p "Enter choice [1-3]: " action

        if [ "$action" == "1" ]; then
            # Drain node from Kubernetes cluster
            kubectl drain $NODE_NAME --delete-emptydir-data --force --ignore-daemonsets
            kubectl delete node $NODE_NAME
            echo "Node $NODE_NAME drained and removed from the Kubernetes cluster"

        elif [ "$action" == "2" ]; then
            # Check SSH connectivity and reset node
            if ssh -o BatchMode=yes -o ConnectTimeout=5 $SSH_USER@$SERVER_IP "exit"; then
                ssh $SSH_USER@$SERVER_IP "sudo kubeadm reset -f && sudo systemctl stop kubelet && sudo systemctl stop docker && sudo rm -rf /var/lib/cni/ /var/lib/kubelet/* /var/lib/etcd/* /etc/cni/ /etc/kubernetes/* /var/run/kubernetes/*"
                echo "Node $NODE_NAME reset on $SERVER_IP"
            else
                echo "Unable to SSH into $SERVER_IP"
            fi

        elif [ "$action" == "3" ]; then
            # Remove etcd member if exists
            members=$(ssh $SSH_USER@$EXISTING_MASTER_IP "etcdctl --endpoints=https://$EXISTING_MASTER_IP:2379 --cacert=$ETCD_CA_CERT --cert=$ETCD_CERT --key=$ETCD_KEY member list")
            member_id=$(echo "$members" | grep "$SERVER_IP" | awk '{print $1}' | tr -d ',')

            if [ -n "$member_id" ]; then
                echo "Removing etcd member with ID: $member_id"
                ssh $SSH_USER@$EXISTING_MASTER_IP "etcdctl --endpoints=https://$EXISTING_MASTER_IP:2379 --cacert=$ETCD_CA_CERT --cert=$ETCD_CERT --key=$ETCD_KEY member remove $member_id"
                echo "Etcd member with ID $member_id removed"
            else
                echo "Etcd member with IP $SERVER_IP not found."
            fi

	    # Drain node from Kubernetes cluster
    	if ! ssh $SSH_USER@$SERVER_IP "kubectl drain $NODE_NAME --delete-emptydir-data --force --ignore-daemonsets --timeout=60s"; then
        	echo "Warning: Draining node $NODE_NAME failed or timed out. Proceeding to delete the node."
    	fi
    	#kubectl drain $NODE_NAME --delete-emptydir-data --force --ignore-daemonsets
            kubectl delete node $NODE_NAME
            echo "Node $NODE_NAME drained and removed from the Kubernetes cluster"

            # Check SSH connectivity and reset node
            if ssh -o BatchMode=yes -o ConnectTimeout=5 $SSH_USER@$SERVER_IP "exit"; then
                ssh $SSH_USER@$SERVER_IP "sudo kubeadm reset -f && sudo systemctl stop kubelet && sudo systemctl stop docker && sudo rm -rf /var/lib/cni/ /var/lib/kubelet/* /var/lib/etcd/* /etc/cni/ /etc/kubernetes/* /var/run/kubernetes/*"
                echo "Node $NODE_NAME reset on $SERVER_IP"
            else
                echo "Unable to SSH into $SERVER_IP"
            fi
        else
            echo "Invalid choice. Please enter 1, 2, or 3."
            exit 1
        fi
    else
        echo "Provided IP $SERVER_IP does not match the IP of node $NODE_NAME ($NODE_IP). No actions will be performed."
        echo "Current node details:"
        kubectl get nodes -o wide
    fi
else
    echo "Node $NODE_NAME does not exist in the Kubernetes cluster. No actions will be performed."
    echo "Current node details:"
    kubectl get nodes -o wide
fi

