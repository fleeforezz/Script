#!/bin/bash

# Check update
echo
echo "#----------- Update apt packages -----------#"
echo
sudo apt update && sudo apt upgrade -y
echo "\nA reboot is needed!"
echo -e "\nRestart now? Y/n"
read RESTART
case $RESTART in
    "Y" | "y")
        # Restart the system
        sudo reboot
        ;;
    "N" | "n")
        ;;
    *)
        echo "Invalid choice"
        ;;
esac

# Disable swap
echo
echo "#----------- Disable swap -----------#"
echo
sudo su
swapoff -a; sed -i '/swap/d' /etc/fstab

# Install containerd
echo
echo "#----------- Install containerd -----------#"
echo
cat <<EOF | sudo tee /etc/modules-load.d/containerd.conf
overlay
br_netfilter
EOF
sudo modprobe overlay
sudo modprobe br_netfilter
cat <<EOF | sudo tee /etc/sysctl.d/99-kubernetes-cri.conf
net.bridge.bridge-nf-call-iptables  = 1
net.ipv4.ip_forward                 = 1
net.bridge.bridge-nf-call-ip6tables = 1
EOF
sudo sysctl --system
sudo apt install containerd -y
mkdir /etc/containerd
containerd config default > /etc/containerd/config.toml
sed -i 's/SystemdCgroup = false/SystemdCgroup = true/g' /etc/containerd/config.toml
systemctl restart containerd

# Install kubeadm, kubectl, kubelet
echo
echo "#----------- Install kubeadm, kubectl, kubelet -----------#"
echo
sudo apt-get update
sudo apt-get install -y apt-transport-https ca-certificates curl gpg
curl -fsSL https://pkgs.k8s.io/core:/stable:/v1.30/deb/Release.key | sudo gpg --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg
echo "deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/v1.30/deb/ /" | sudo tee /etc/apt/sources.list.d/kubernetes.list
sudo apt-get update
sudo apt update
sudo apt-get install -y kubelet kubeadm kubectl
sudo apt-mark hold kubelet kubeadm kubectl

# Check is Master node or not
echo
echo "#----------- Initiallize the Master Node -----------#"
echo
echo -e "\nAre you install on Master Node? Y/n"
read MASTERNODE 
case $MASTERNODE in
    "Y" | "y")
        # Prompt the user for the control plane endpoint
        read -p "Enter the control plane endpoint (e.g., k8s-master.yourdomain.com): " CONTROL_PLANE_ENDPOINT

        # Prompt the user for the node name
        read -p "Enter the node name (e.g., k8s-master-1): " NODE_NAME

        # Default pod network CIDR for Flannel
        POD_NETWORK_CIDR="10.244.0.0/16"

        # Display the inputs for confirmation
        echo
        echo "You entered:"
        echo "Control Plane Endpoint: $CONTROL_PLANE_ENDPOINT"
        echo "Node Name: $NODE_NAME"
        echo "Pod Network CIDR: $POD_NETWORK_CIDR"
        echo

        # Confirm before proceeding
        read -p "Are these values correct? (yes/no): " CONFIRMATION

        if [[ "$CONFIRMATION" == "yes" ]]; then
            # Run kubeadm init with the provided inputs
            sudo kubeadm init \
                --control-plane-endpoint="$CONTROL_PLANE_ENDPOINT" \
                --node-name="$NODE_NAME" \
                --pod-network-cidr="$POD_NETWORK_CIDR"
        else
            echo "Initialization canceled."
            exit 1
        fi

        # Install Helm
        curl -fsSL -o get_helm.sh https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3
        chmod 700 get_helm.sh
        ./get_helm.sh

        # Install Calio
        helm repo add projectcalico https://docs.tigera.io/calico/charts
        kubectl create namespace tigera-operator
        helm install calico projectcalico/tigera-operator --version v3.28.0 --namespace tigera-operator
        ;;
    "N" | "n")
        echo
        echo "Install complete"
        ;;
    *)
        echo "Invalid choice"
        ;;
esac

