#!/bin/bash

set -e

# Load environment variables
source ./env.sh

# Check if arguments are provided
if [ "$#" -ne 2 ]; then
    echo "Usage: $0 <server_ip> <load_balancer_ip>"
    exit 1
fi

SERVER_IP=$1
LOAD_BALANCER_IP=$2

# Function to write details to file
write_details_to_file() {
    echo "token=$token" > "$DETAILS_FILE"
    echo "hash_key=$hash_key" >> "$DETAILS_FILE"
    echo "certificate_key=$certificate_key" >> "$DETAILS_FILE"
}

# Function to check if Kubernetes is already initialized
is_kubernetes_initialized() {
    ssh $SSH_USER@$SERVER_IP "[ -f /etc/kubernetes/admin.conf ]" >/dev/null
}

# Check SSH connectivity
if ssh -o BatchMode=yes -o ConnectTimeout=5 $SSH_USER@$SERVER_IP "exit" >/dev/null; then
    if is_kubernetes_initialized; then
        echo "Kubernetes is already initialized on $SERVER_IP"
    else
        ssh $SSH_USER@$SERVER_IP <<EOF
        sudo kubeadm init --control-plane-endpoint "$LOAD_BALANCER_IP:6443" --upload-certs | tee /root/kubeadm-init.out >/dev/null
        mkdir -p \$HOME/.kube
        sudo cp /etc/kubernetes/admin.conf \$HOME/.kube/config >/dev/null
        sudo chown \$(id -u):\$(id -g) \$HOME/.kube/config >/dev/null
        kubectl apply -f https://docs.projectcalico.org/manifests/calico.yaml >/dev/null
EOF
        scp $SSH_USER@$SERVER_IP:/root/kubeadm-init.out ./kubeadm-init.out >/dev/null

        # Get the latest kubeadm-init.out file
        latest_file="kubeadm-init.out"

        # Extract join command details
        token=$(grep -oP '(?<=--token )\S+' "$latest_file")
        hash_key=$(grep -oP '(?<=--discovery-token-ca-cert-hash )\S+' "$latest_file")
        certificate_key=$(grep -oP '(?<=--certificate-key )\S+' "$latest_file")

        # Write details to file
        write_details_to_file

        echo "Kubernetes master initialized on $SERVER_IP and output saved locally."
        echo "Join details saved to $DETAILS_FILE."
    fi
else
    echo "Unable to SSH into $SERVER_IP"
fi

