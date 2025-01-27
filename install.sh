# #!/bin/bash

# # Check update
# echo
# echo "#----------- Update apt packages -----------#"
# echo
# sudo apt update && sudo apt upgrade -y
# echo
# echo "A reboot is needed!"
# echo -e "Restart now? Y/n"
# read RESTART
# case $RESTART in
#     "Y" | "y")
#         # Restart the system
#         sudo reboot
#         exit
#         ;;
#     "N" | "n")
#         ;;
#     *)
#         echo "Invalid choice"
#         ;;
# esac

# # Disable swap
# echo
# echo "#----------- Disable swap -----------#"
# echo
# sudo swapoff -a
# sudo sed -i '/swap/d' /etc/fstab

# # Install containerd
# echo
# echo "#----------- Install containerd -----------#"
# echo
# cat <<EOF | sudo tee /etc/modules-load.d/containerd.conf
# overlay
# br_netfilter
# EOF
# sudo modprobe overlay
# sudo modprobe br_netfilter
# cat <<EOF | sudo tee /etc/sysctl.d/99-kubernetes-cri.conf
# net.bridge.bridge-nf-call-iptables  = 1
# net.ipv4.ip_forward                 = 1
# net.bridge.bridge-nf-call-ip6tables = 1
# EOF
# sudo sysctl --system
# sudo apt install containerd -y
# mkdir /etc/containerd
# containerd config default > /etc/containerd/config.toml
# sed -i 's/SystemdCgroup = false/SystemdCgroup = true/g' /etc/containerd/config.toml
# systemctl restart containerd

# # Install kubeadm, kubectl, kubelet
# echo
# echo "#----------- Install kubeadm, kubectl, kubelet -----------#"
# echo
# sudo apt-get update
# sudo apt-get install -y apt-transport-https ca-certificates curl gpg
# curl -fsSL https://pkgs.k8s.io/core:/stable:/v1.30/deb/Release.key | sudo gpg --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg
# echo "deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/v1.30/deb/ /" | sudo tee /etc/apt/sources.list.d/kubernetes.list
# sudo apt-get update
# sudo apt update
# sudo apt-get install -y kubelet kubeadm kubectl
# sudo apt-mark hold kubelet kubeadm kubectl

# # Check is Master node or not
# echo
# echo "#----------- Initiallize the Master Node -----------#"
# echo
# echo -e "\nAre you install on Master Node? Y/n"
# read MASTERNODE 
# case $MASTERNODE in
#     "Y" | "y")
#         # Prompt the user for the control plane endpoint
#         read -p "Enter the control plane endpoint (e.g., k8s-master.yourdomain.com): " CONTROL_PLANE_ENDPOINT

#         # Prompt the user for the node name
#         read -p "Enter the node name (e.g., k8s-master-1): " NODE_NAME

#         # Default pod network CIDR for Flannel
#         POD_NETWORK_CIDR="10.244.0.0/16"

#         # Display the inputs for confirmation
#         echo
#         echo "You entered:"
#         echo "Control Plane Endpoint: $CONTROL_PLANE_ENDPOINT"
#         echo "Node Name: $NODE_NAME"
#         echo "Pod Network CIDR: $POD_NETWORK_CIDR"
#         echo

#         # Confirm before proceeding
#         read -p "Are these values correct? (yes/no): " CONFIRMATION

#         if [[ "$CONFIRMATION" == "yes" ]]; then
#             # Run kubeadm init with the provided inputs
#             sudo kubeadm init \
#                 --control-plane-endpoint="$CONTROL_PLANE_ENDPOINT" \
#                 --node-name="$NODE_NAME" \
#                 --pod-network-cidr="$POD_NETWORK_CIDR"
            
#             mkdir -p $HOME/.kube
#             sudo cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
#             sudo chown $(id -u):$(id -g) $HOME/.kube/config
#         else
#             echo "Initialization canceled."
#             exit 1
#         fi

#         # Install Helm
#         curl -fsSL -o get_helm.sh https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3
#         chmod 700 get_helm.sh
#         ./get_helm.sh

#         # Install Calio
#         helm repo add projectcalico https://docs.tigera.io/calico/charts
#         kubectl create namespace tigera-operator
#         helm install calico projectcalico/tigera-operator --version v3.28.0 --namespace tigera-operator
#         ;;
#     "N" | "n")
#         echo
#         echo "Install complete"
#         ;;
#     *)
#         echo "Invalid choice"
#         ;;
# esac

#!/bin/bash

# Variables
POD_NETWORK_CIDR="10.244.0.0/16"
KUBE_APT_KEYRING="/etc/apt/keyrings/kubernetes-apt-keyring.gpg"
KUBE_APT_SOURCE="/etc/apt/sources.list.d/kubernetes.list"

# Function: Update and Upgrade System
update_system() {
    echo -e "\n#----------- Update apt packages -----------#\n"
    sudo apt update && sudo apt upgrade -y
    echo -e "\nA reboot is needed!"
    read -p "Restart now? (Y/n): " RESTART
    case $RESTART in
        "Y" | "y") sudo reboot; exit ;;
        "N" | "n") ;;
        *) echo "Invalid choice. Continuing...";;
    esac
}

# Function: Disable Swap
disable_swap() {
    echo -e "\n#----------- Disable swap -----------#\n"
    sudo swapoff -a
    sudo sed -i '/swap/d' /etc/fstab
}

# Function: Install containerd
install_containerd() {
    echo -e "\n#----------- Install containerd -----------#\n"
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
    echo -e "\n#----------- Install kubeadm, kubectl, kubelet -----------#\n"
    sudo apt-get install -y apt-transport-https ca-certificates curl gpg
    curl -fsSL https://pkgs.k8s.io/core:/stable:/v1.30/deb/Release.key | sudo gpg --dearmor -o $KUBE_APT_KEYRING
    echo "deb [signed-by=$KUBE_APT_KEYRING] https://pkgs.k8s.io/core:/stable:/v1.30/deb/ /" | sudo tee $KUBE_APT_SOURCE
    sudo apt-get update
    sudo apt-get install -y kubelet kubeadm kubectl
    sudo apt-mark hold kubelet kubeadm kubectl
}

# Function: Initialize Master Node
initialize_master_node() {
    read -p "Enter the control plane endpoint (e.g., k8s-master.yourdomain.com): " CONTROL_PLANE_ENDPOINT
    read -p "Enter the node name (e.g., k8s-master-1): " NODE_NAME

    echo -e "\nYou entered:\nControl Plane Endpoint: $CONTROL_PLANE_ENDPOINT\nNode Name: $NODE_NAME\nPod Network CIDR: $POD_NETWORK_CIDR"
    echo
    read -p "Are these values correct? (yes/no): " CONFIRMATION

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
    echo -e "\n#----------- Install Helm -----------#\n"
    curl -fsSL -o get_helm.sh https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3
    chmod 700 get_helm.sh
    ./get_helm.sh
}

# Function: Install Calico
install_calico() {
    echo -e "\n#----------- Install Calico -----------#\n"
    helm repo add projectcalico https://docs.tigera.io/calico/charts
    kubectl create namespace tigera-operator
    helm install calico projectcalico/tigera-operator --version v3.28.0 --namespace tigera-operator
}

# Main Script Execution
update_system
disable_swap
install_containerd
install_kubernetes_tools

# Master Node Check
echo -e "\n#----------- Initialize the Master Node -----------#\n"
read -p "Are you installing on the Master Node? (Y/n): " MASTERNODE
case $MASTERNODE in
    "Y" | "y") initialize_master_node ;;
    "N" | "n") echo -e "\nInstallation complete." ;;
    *) echo "Invalid choice. Exiting..."; exit 1 ;;
esac
