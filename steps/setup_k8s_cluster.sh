#!/bin/bash

HOSTS_FILE="hosts"
declare -A HOSTS

# Function to check SSH connectivity
check_ssh() {
    local ip=$1
    ssh -o BatchMode=yes -o ConnectTimeout=5 $ip "exit"
    return $?
}

# Function to check if a port is open
check_port() {
    local ip=$1
    local port=$2
    nc -z -v -w5 $ip $port
    return $?
}

# Read the hosts file
echo "Step 1: Reading the hosts file..."
if [[ -f "$HOSTS_FILE" ]]; then
    while IFS= read -r line
    do
        IP=$(echo $line | awk '{print $1}')
        HOSTNAME=$(echo $line | awk '{print $2}')
        HOSTS[$HOSTNAME]=$IP
    done < "$HOSTS_FILE"
fi

# Function to get load balancer details
get_load_balancer() {
    while true; do
        echo "Enter the IP or DNS of the load balancer: "
        read LB_INPUT
        if [[ $LB_INPUT =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
            LB_IP=$LB_INPUT
            if check_ssh $LB_IP; then
                echo "SSH to $LB_IP successful."
                ./install_setup_haproxy.sh
                break
            else
                echo "SSH to $LB_IP failed. Please check the IP and try again."
            fi
        else
            if nslookup $LB_INPUT > /dev/null; then
                LB_IP=$(nslookup $LB_INPUT | awk '/^Address: / { print $2 ; exit }')
                if check_port $LB_IP 6443; then
                    echo "Port 6443 on $LB_IP is open."
                    break
                else
                    echo "Port 6443 on $LB_IP is not open. Please enter a valid load balancer IP or DNS."
                fi
            else
                echo "Invalid DNS. Please enter a valid load balancer IP or DNS."
            fi
        fi
    done
}

# Get load balancer info if not found in hosts file
echo "Step 2: Checking load balancer details..."
LB_IP=""
for HOSTNAME in "${!HOSTS[@]}"
do
    if [[ $HOSTNAME == *"lb" ]]; then
        LB_IP=${HOSTS[$HOSTNAME]}
        break
    fi
done

if [[ -z $LB_IP ]]; then
    get_load_balancer
else
    if check_ssh $LB_IP; then
        echo "SSH to $LB_IP successful."
        ./install_setup_haproxy.sh
    elif check_port $LB_IP 6443; then
        echo "Port 6443 on $LB_IP is open."
    else
        echo "Port 6443 on $LB_IP is not open. Need to specify load balancer manually."
        get_load_balancer
    fi
fi

# Function to check and validate SSH connectivity for all nodes
validate_ssh() {
    for HOSTNAME in "${!HOSTS[@]}"
    do
        IP=${HOSTS[$HOSTNAME]}
        if ! check_ssh $IP; then
            echo "SSH to $IP ($HOSTNAME) failed. Please check the SSH configuration."
            exit 1
        fi
    done
}

echo "Step 3: Validating SSH connectivity for all nodes..."
validate_ssh

# Run the set_hosts_hostname.sh script
echo "Step 4: Running set_hosts_hostname.sh script..."
./set_hosts_hostname.sh

# Find the first master node to create the cluster
echo "Step 5: Finding the first master node..."
MASTER1_HOSTNAME=""
for HOSTNAME in "${!HOSTS[@]}"
do
    if [[ $HOSTNAME == *"master"* ]]; then
        MASTER1_HOSTNAME=$HOSTNAME
        MASTER1_IP=${HOSTS[$MASTER1_HOSTNAME]}
        break
    fi
done

# Run create_cluster.sh
echo "Step 6: Running create_cluster.sh script..."
./create_cluster.sh /home/ubuntu/kubernetes $MASTER1_HOSTNAME $MASTER1_IP $LB_IP

# Add master nodes
echo "Step 7: Adding master nodes..."
for HOSTNAME in "${!HOSTS[@]}"
do
    if [[ $HOSTNAME == *"master"* && $HOSTNAME != $MASTER1_HOSTNAME ]]; then
        IP=${HOSTS[$HOSTNAME]}
        ./add_master_node.sh /home/ubuntu/kubernetes $HOSTNAME $IP $MASTER1_IP $LB_IP
    fi
done

# Add worker nodes
echo "Step 8: Adding worker nodes..."
for HOSTNAME in "${!HOSTS[@]}"
do
    if [[ $HOSTNAME == *"worker"* ]]; then
        IP=${HOSTS[$HOSTNAME]}
	echo "./add_worker_node.sh /home/ubuntu/kubernetes $HOSTNAME $IP $MASTER1_IP $LB_IP"
        ./add_worker_node.sh /home/ubuntu/kubernetes $HOSTNAME $IP $MASTER1_IP $LB_IP
    fi
done

echo "Step 9: Kubernetes cluster setup is complete."

