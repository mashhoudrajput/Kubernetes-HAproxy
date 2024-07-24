#!/bin/bash

# Load environment variables
source ./env.sh

#HOSTS_FILE="hosts"
CURRENT_HOSTS_FILE="current_hosts"
declare -A HOSTS
declare -A PREVIOUS_HOSTS
declare -A REMOVED_NODES

# Function to check SSH connectivity
check_ssh() {
    local ip=$1
    ssh -o BatchMode=yes -o ConnectTimeout=5 $ip "exit"
    return $?
}

# Function to read the hosts file and populate the HOSTS array
read_hosts_file() {
    if [[ -f "$HOSTS_FILE" ]]; then
        while IFS= read -r line
        do
            IP=$(echo $line | awk '{print $1}')
            HOSTNAME=$(echo $line | awk '{print $2}')
            HOSTS[$HOSTNAME]=$IP
        done < "$HOSTS_FILE"
    fi
}

# Function to read the current_hosts file and populate the PREVIOUS_HOSTS array
read_previous_hosts_file() {
    if [[ -f "$CURRENT_HOSTS_FILE" ]]; then
        while IFS= read -r line
        do
            IP=$(echo $line | awk '{print $1}')
            HOSTNAME=$(echo $line | awk '{print $2}')
            PREVIOUS_HOSTS[$HOSTNAME]=$IP
        done < "$CURRENT_HOSTS_FILE"
    fi
}

# Save the current hosts to a file
save_current_hosts() {
    > "$CURRENT_HOSTS_FILE"
    for HOSTNAME in "${!HOSTS[@]}"; do
        echo "${HOSTS[$HOSTNAME]} $HOSTNAME" >> "$CURRENT_HOSTS_FILE"
    done
}

# Function to get removed nodes
get_removed_nodes() {
    removed_nodes=()
    for host in "${!PREVIOUS_HOSTS[@]}"; do
        if [[ -z "${HOSTS[$host]}" ]]; then
            removed_nodes+=($host)
            REMOVED_NODES[$host]=${PREVIOUS_HOSTS[$host]}
        fi
    done
    echo ${removed_nodes[@]}
}

# Function to remove nodes
remove_nodes() {
    local nodes=("$@")
    for HOSTNAME in "${nodes[@]}"; do
        IP=${PREVIOUS_HOSTS[$HOSTNAME]}
        if [[ $HOSTNAME == *"master"* || $HOSTNAME == *"worker"* ]]; then
            echo "Removing $HOSTNAME $IP from the cluster"
            ./remove_node_and_uninstall.sh $HOSTNAME $IP $MASTER1_IP
            kubectl delete node $HOSTNAME --force --grace-period=0
        fi
    done
}

# Function to ensure no new node uses the removed node's IP
check_new_node_ip() {
    local new_ip=$1
    for removed_ip in "${REMOVED_NODES[@]}"; do
        if [[ $new_ip == $removed_ip ]]; then
            echo "Error: The IP address $new_ip is the same as a recently removed node. Please use a different IP address."
            exit 1
        fi
    done
}

# Function to remove nodes with role "none"
remove_none_role_nodes() {
    nodes_with_none_role=$(kubectl get nodes --no-headers | awk '$3 == "<none>" {print $1}')
    for NODE in $nodes_with_none_role; do
        IP=$(kubectl get node $NODE -o jsonpath='{.status.addresses[?(@.type=="InternalIP")].address}')
        echo "Removing $NODE $IP from the cluster because the ROLE is NONE, as shown by 'kubectl get nodes'"
        ./remove_node_and_uninstall.sh $NODE $IP $MASTER1_IP
        kubectl delete node $NODE --force --grace-period=0
    done
}

# Read the hosts file
echo "Step 1/12: Reading the hosts file..."
read_hosts_file

# Read previous hosts file
echo "Step 2/12: Reading previous hosts file..."
read_previous_hosts_file

# Find the first master node to create the cluster
MASTER1_HOSTNAME=""
for HOSTNAME in "${!HOSTS[@]}"
do
    if [[ $HOSTNAME == *"master"* ]]; then
        echo "$HOSTNAME ${HOSTS[$HOSTNAME]}"
	MASTER1_HOSTNAME=$HOSTNAME
        MASTER1_IP=${HOSTS[$MASTER1_HOSTNAME]}
        break
    fi
done

# Detect and remove nodes
echo "Step 3/12: Detecting and removing nodes..."
REMOVED_NODES=$(get_removed_nodes)
if [[ ! -z "$REMOVED_NODES" ]]; then
    echo "Removing nodes: $REMOVED_NODES"
    remove_nodes $REMOVED_NODES
fi

# Save current hosts to a file
echo "Step 4/12: Saving current hosts..."
save_current_hosts

# Remove nodes with role "none"
echo "Step 5/12: Removing nodes with role 'none'..."
remove_none_role_nodes

# Function to get load balancer details
get_load_balancer() {
    while true; do
        echo "Enter the IP or DNS of the load balancer: "
        read LB_INPUT
        check_new_node_ip $LB_INPUT
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
echo "Step 6/12: Checking load balancer details..."
LB_IP=""
for HOSTNAME in "${!HOSTS[@]}"
do
    if [[ $HOSTNAME == *"lb"* ]]; then
        LB_IP=${HOSTS[$HOSTNAME]}
        break
    fi
done

if [[ -z $LB_IP ]]; then
    get_load_balancer
else
    check_new_node_ip $LB_IP
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
        check_new_node_ip $IP
        if ! check_ssh $IP; then
            echo "SSH to $IP ($HOSTNAME) failed. Please check the SSH configuration."
            exit 1
        fi
    done
}

echo "Step 7/12: Validating SSH connectivity for all nodes..."
validate_ssh

# Function to update node hostname in Kubernetes
update_node_hostname() {
    local old_hostname=$1
    local new_hostname=$2
    local ip=$3
    echo "Removing $old_hostname $ip from the cluster"
    ./remove_node_and_uninstall.sh $old_hostname $ip $MASTER1_IP
    kubectl delete node $old_hostname --force --grace-period=0
}

# Check and update node hostnames if needed
echo "Step 8/12: Checking and updating node hostnames if needed..."
for HOSTNAME in "${!PREVIOUS_HOSTS[@]}"; do
    if [[ -z "${HOSTS[$HOSTNAME]}" ]]; then
        new_hostname=$(grep "${PREVIOUS_HOSTS[$HOSTNAME]}" "$HOSTS_FILE" | awk '{print $2}')
        if [[ ! -z "$new_hostname" && "$new_hostname" != "$HOSTNAME" ]]; then
            IP=${PREVIOUS_HOSTS[$HOSTNAME]}
            echo "Updating hostname from $HOSTNAME to $new_hostname"
            update_node_hostname $HOSTNAME $new_hostname $IP
        fi
    fi
done

# Run the set_hosts_hostname.sh script
echo "Step 9/12: Running hosts_hostname_set.sh script..."
./hosts_hostname_set.sh

# Run create_cluster.sh
echo "Step 10/12: Running create_cluster.sh script..."
echo "Checking if the Master1 node with hostname $MASTER1_HOSTNAME and IP address $MASTER1_IP is already added to the cluster."
./create_cluster.sh $MASTER1_HOSTNAME $MASTER1_IP $LB_IP

# Add master nodes
echo "Step 11/12: Adding master nodes..."
for HOSTNAME in "${!HOSTS[@]}"
do
    if [[ $HOSTNAME == *"master"* && $HOSTNAME != $MASTER1_HOSTNAME ]]; then
        IP=${HOSTS[$HOSTNAME]}
        check_new_node_ip $IP
        echo "Adding Master node $HOSTNAME $IP to the cluster"
        ./add_master_node.sh $HOSTNAME $IP $MASTER1_IP $LB_IP
    fi
done

# Add worker nodes
echo "Step 12/12: Adding worker nodes..."
for HOSTNAME in "${!HOSTS[@]}"
do
    if [[ $HOSTNAME == *"worker"* ]]; then
        IP=${HOSTS[$HOSTNAME]}
        check_new_node_ip $IP
        echo "Adding worker node $HOSTNAME $IP to the cluster"
        ./add_worker_node.sh $HOSTNAME $IP $MASTER1_IP $LB_IP
    fi
done

echo "Step 12/12: Kubernetes cluster setup is complete."

