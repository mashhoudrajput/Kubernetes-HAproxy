#!/bin/bash

# Function to populate master, worker, and load balancer arrays from the hosts file
populate_hosts() {
    HOSTS_FILE="hosts"
    while IFS= read -r line
    do
        IP=$(echo $line | awk '{print $1}')
        HOSTNAME=$(echo $line | awk '{print $2}')
        HOSTS[$HOSTNAME]=$IP
        if [[ $HOSTNAME == *"master"* ]]; then
            MASTERS[$HOSTNAME]=$IP
        elif [[ $HOSTNAME == *"worker"* ]]; then
            WORKERS[$HOSTNAME]=$IP
        elif [[ $HOSTNAME == *"lb"* ]]; then
            LB_IP=$IP
        fi
    done < "$HOSTS_FILE"
}

# Main script
declare -A HOSTS
declare -A MASTERS
declare -A WORKERS
SSH_USER="root"

populate_hosts

if [[ -z $LB_IP ]]; then
    echo "Load balancer not found in hosts file."
    exit 1
fi

# Check SSH connectivity to the load balancer
if ! ssh -o BatchMode=yes -o ConnectTimeout=5 $SSH_USER@$LB_IP 'exit'; then
    echo "Error: Unable to connect to load balancer at $LB_IP via SSH."
    exit 1
fi

# Create the install_haproxy.sh script
cat << 'EOF' > /tmp/install_haproxy.sh
#!/bin/bash

# Function to check if HAProxy is installed
check_haproxy_installed() {
    if haproxy -v > /dev/null 2>&1; then
        return 0
    else
        return 1
    fi
}

# Function to install HAProxy
install_haproxy() {
    echo "Installing HAProxy..."
    sudo apt-get update
    sudo apt-get install -y haproxy
}

# Function to generate haproxy.cfg
generate_haproxy_cfg() {
    cat <<EOL > /etc/haproxy/haproxy.cfg
global
    log /dev/log local0 notice
    log /dev/log local1 notice
    chroot /var/lib/haproxy
    stats socket /run/haproxy/admin.sock mode 660 level admin
    stats timeout 30s
    user haproxy
    group haproxy
    daemon

defaults
    log     global
    mode    http
    option  httplog
    option  dontlognull
    timeout connect 5000
    timeout client  50000
    timeout server  50000
    errorfile 400 /etc/haproxy/errors/400.http
    errorfile 403 /etc/haproxy/errors/403.http
    errorfile 408 /etc/haproxy/errors/408.http
    errorfile 500 /etc/haproxy/errors/500.http
    errorfile 502 /etc/haproxy/errors/502.http
    errorfile 503 /etc/haproxy/errors/503.http
    errorfile 504 /etc/haproxy/errors/504.http

frontend kubernetes
    bind *:6443
    option tcplog
    mode tcp
    default_backend kubernetes-masters

backend kubernetes-masters
    mode tcp
    balance roundrobin
EOL

    for HOSTNAME in "${!MASTERS[@]}"
    do
        echo "    server $HOSTNAME ${MASTERS[$HOSTNAME]}:6443 check fall 3 rise 2" >> /etc/haproxy/haproxy.cfg
    done

    cat <<EOL >> /etc/haproxy/haproxy.cfg

frontend kubernetes-frontend
    bind *:80
    bind *:443
    mode tcp
    option tcplog
    use_backend kubernetes-backend-http if { dst_port 80 }
    use_backend kubernetes-backend-https if { dst_port 443 }

backend kubernetes-backend-http
    mode tcp
    balance roundrobin
EOL

    for HOSTNAME in "${!WORKERS[@]}"
    do
        echo "    server $HOSTNAME ${WORKERS[$HOSTNAME]}:30080 check fall 3 rise 2" >> /etc/haproxy/haproxy.cfg
    done

    cat <<EOL >> /etc/haproxy/haproxy.cfg

backend kubernetes-backend-https
    mode tcp
    balance roundrobin
EOL

    for HOSTNAME in "${!WORKERS[@]}"
    do
        echo "    server $HOSTNAME ${WORKERS[$HOSTNAME]}:30443 check fall 3 rise 2" >> /etc/haproxy/haproxy.cfg
    done
}

# Function to verify haproxy.cfg
verify_haproxy_cfg() {
    local cfg_file="/etc/haproxy/haproxy.cfg"
    local masters_valid=true
    local workers_valid=true

    # Check masters
    for HOSTNAME in "${!MASTERS[@]}"
    do
        if ! grep -q "server $HOSTNAME ${MASTERS[$HOSTNAME]}:6443 check fall 3 rise 2" "$cfg_file"; then
            masters_valid=false
            break
        fi
    done

    # Check workers
    for HOSTNAME in "${!WORKERS[@]}"
    do
        if ! grep -q "server $HOSTNAME ${WORKERS[$HOSTNAME]}:30080 check fall 3 rise 2" "$cfg_file" ||
           ! grep -q "server $HOSTNAME ${WORKERS[$HOSTNAME]}:30443 check fall 3 rise 2" "$cfg_file"; then
            workers_valid=false
            break
        fi
    done

    if $masters_valid && $workers_valid; then
        echo "haproxy.cfg is valid."
    else
        echo "haproxy.cfg is invalid. Regenerating..."
        generate_haproxy_cfg
    fi
}

# Main script
declare -A MASTERS
declare -A WORKERS

# Function to populate master and worker arrays from the hosts file
populate_hosts() {
    HOSTS_FILE="/tmp/hosts"
    echo "Reading hosts file from $HOSTS_FILE..."
    if [[ ! -f $HOSTS_FILE ]]; then
        echo "Error: hosts file not found at $HOSTS_FILE"
        exit 1
    fi

    while IFS= read -r line
    do
        IP=$(echo $line | awk '{print $1}')
        HOSTNAME=$(echo $line | awk '{print $2}')
        if [[ $HOSTNAME == *"master"* ]]; then
            MASTERS[$HOSTNAME]=$IP
        elif [[ $HOSTNAME == *"worker"* ]]; then
            WORKERS[$HOSTNAME]=$IP
        fi
    done < "$HOSTS_FILE"
}

populate_hosts

if check_haproxy_installed; then
    echo "HAProxy is already installed. Verifying configuration..."
    verify_haproxy_cfg
else
    install_haproxy
    generate_haproxy_cfg
fi

# Restart HAProxy to apply changes
sudo systemctl restart haproxy

# Check HAProxy status
if sudo systemctl status haproxy > /dev/null; then
    echo "HAProxy is running successfully."
else
    echo "Error: HAProxy failed to start."
    exit 1
fi

echo "HAProxy configuration updated and service restarted."
EOF

# Copy the install_haproxy.sh script and hosts file to the load balancer server and execute it there
scp /tmp/install_haproxy.sh $SSH_USER@$LB_IP:/tmp/install_haproxy.sh
scp hosts $SSH_USER@$LB_IP:/tmp/hosts
ssh $SSH_USER@$LB_IP 'bash /tmp/install_haproxy.sh'

echo "HAProxy setup on the load balancer server is complete."

