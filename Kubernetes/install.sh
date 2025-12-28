#!/bin/bash

set -e # Exit on error

# Define the Kubernetes version you want
K8S_VERSION="v1.35"
CALICO="v3.31.3"

# Default variables
POD_NETWORK_CIDR="192.168.0.0/16"
KUBE_APT_KEYRING="/etc/apt/keyrings/kubernetes-apt-keyring.gpg"
KUBE_APT_SOURCE="/etc/apt/sources.list.d/kubernetes.list"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to print colored messages
print_status() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Function: Update and Upgrade System
update_system() {
    print_status "Updating and upgrading system packages..."
    sudo apt update && sudo apt upgrade -y
}

# Function: Disable Swap
disable_swap() {
    print_status "Disabling swap..."
    sudo swapoff -a
    sudo sed -i '/swap/d' /etc/fstab
}

# Function: Install containerd
install_containerd() {
    print_status "Installing containerd..."
    sudo tee /etc/modules-load.d/containerd.conf <<EOF
overlay
br_netfilter
EOF
    sudo modprobe overlay br_netfilter
    sudo tee /etc/sysctl.d/99-kubernetes-cri.conf <<EOF
net.bridge.bridge-nf-call-iptables  = 1
net.ipv4.ip_forward                 = 1
net.bridge.bridge-nf-call-ip6tables = 1
EOF
    sudo sysctl --system
    sudo apt install -y containerd
    sudo mkdir -p /etc/containerd
    sudo containerd config default | sudo tee /etc/containerd/config.toml
    sudo sed -i 's/SystemdCgroup = false/SystemdCgroup = true/' /etc/containerd/config.toml
    sudo systemctl restart containerd
}

# Function: Install Kubernetes Tools
install_kubernetes_tools() {
    print_status "Installing kubeadm, kubectl, kubelet..."
    sudo apt-get install -y apt-transport-https ca-certificates curl gpg
    curl -fsSL https://pkgs.k8s.io/core:/stable:/${K8S_VERSION}/deb/Release.key | sudo gpg --dearmor -o $KUBE_APT_KEYRING
    echo "deb [signed-by=$KUBE_APT_KEYRING] https://pkgs.k8s.io/core:/stable:/${K8S_VERSION}/deb/ /" | sudo tee $KUBE_APT_SOURCE
    sudo apt-get update
    sudo apt-get install -y kubelet kubeadm kubectl
    sudo apt-mark hold kubelet kubeadm kubectl
}

# Function: Initialize Master Node
initialize_master_node() {
    read -p "Enter the control plane endpoint (e.g., k8s-master.yourdomain.com): " CONTROL_PLANE_ENDPOINT </dev/tty
    read -p "Enter the node name (e.g., k8s-master-1): " NODE_NAME </dev/tty

    echo -e "\nYou entered:\nControl Plane Endpoint: $CONTROL_PLANE_ENDPOINT\nNode Name: $NODE_NAME\nPod Network CIDR: $POD_NETWORK_CIDR"
    echo
    read -p "Are these values correct? (yes/no): " CONFIRMATION </dev/tty

    if [[ "$CONFIRMATION" == "yes" ]]; then
        sudo kubeadm init --control-plane-endpoint="$CONTROL_PLANE_ENDPOINT" --node-name="$NODE_NAME" --pod-network-cidr="$POD_NETWORK_CIDR"
        mkdir -p $HOME/.kube
        sudo cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
        sudo chown $(id -u):$(id -g) $HOME/.kube/config

        # Install Helm and Calico
        install_helm
        install_calico
    else
        echo "Initialization canceled."
        exit 1
    fi
}

# Function: Install Helm
install_helm() {
    print_status "Installing Helm..."
    curl -fsSL -o get_helm.sh https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3
    chmod 700 get_helm.sh
    ./get_helm.sh
}

# Function: Install Calico
install_calico() {
    print_status "Installing Calico..."
    helm repo add projectcalico https://docs.tigera.io/calico/charts
    kubectl create namespace tigera-operator
    helm install calico projectcalico/tigera-operator --version $CALICO --namespace tigera-operator
}

# Function: Check Prerequisites
check_prerequistites() {
    print_status "Checking system prerequisites..."

    update_system

    # Check if swap is disabled
    if free | grep -q 'Swap: *0 *0 *0'; then
        print_success "Swap is disabled."
        echo -n "Do you want to disable swap now? (Y/n): "
        read DISABLE_SWAP_CHOICE </dev/tty
        case $DISABLE_SWAP_CHOICE in
            "Y" | "y" ) disable_swap ;;
            "N" | "n" ) ;;
            * ) print_warning "Invalid choice. Continuing..." ;;
        esac
    else
        print_warning "Swap is enabled. It should be disabled for Kubernetes."
    fi

    # Check if containerd is installed
    if command -v containerd >/dev/null 2>&1; then
        print_success "containerd is installed."
    else
        print_warning "containerd is not installed."
        echo -n "Do you want to install containerd now? (Y/n): "
        read INSTALL_CONTAINERD_CHOICE </dev/tty
        case $INSTALL_CONTAINERD_CHOICE in
            "Y" | "y" ) install_containerd ;;
            "N" | "n" ) ;;
            * ) print_warning "Invalid choice. Continuing..." ;;
        esac
    fi

    # Check if kubeadm, kubectl, and kubelet are installed
    if command -v kubeadm >/dev/null 2>&1 && command -v kubectl >/dev/null 2>&1 && command -v kubelet >/dev/null 2>&1; then
        print_success "kubeadm, kubectl, and kubelet are installed."
    else
        print_warning "kubeadm, kubectl, and/or kubelet are not installed."
        echo -n "Do you want to install Kubernetes tools now? (Y/n): "
        read INSTALL_K8S_TOOLS_CHOICE </dev/tty
        case $INSTALL_K8S_TOOLS_CHOICE in
            "Y" | "y" ) install_kubernetes_tools ;;
            "N" | "n" ) ;;
            * ) print_warning "Invalid choice. Continuing..." ;;
        esac
    fi
}

# Main Script Execution
main() {
    print_status "Starting installation script..."

    check_prerequistites

    # Check if check prerequisites passed successfully
    if [ $? -ne 0 ]; then
        print_error "Prerequisite checks failed. Please resolve the issues and rerun the script."
        exit 1
    else
        print_success "All prerequisite checks passed."
        # Master Node Check 
        print_status "Initializing Master Node..."
        read -p "Are you installing on the Master Node? (Y/n): " MASTERNODE </dev/tty
        case $MASTERNODE in
            "Y" | "y") initialize_master_node && install_helm && install_calico ;;
            "N" | "n") print_success "Not in master node. Installation complete." ;;
            *) echo "Invalid choice. Exiting..."; exit 1 ;;
        esac
    fi
}

# Execute main function
main