#!/bin/bash

# Check update
echo "#----------- Update apt packages -----------#"
sudo apt update && sudo apt upgrade -y
echo "\nA reboot is needed!"
echo "\nRestart now? Y/n"
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
echo "#----------- Disable swap -----------#"
sudo su
swapoff -a; sed -i '/swap/d' /etc/fstab

# Install containerd
echo "#----------- Install containerd -----------#"
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
echo "#----------- Install kubeadm, kubectl, kubelet -----------#"
sudo apt-get update
sudo apt-get install -y apt-transport-https ca-certificates curl gpg
curl -fsSL https://pkgs.k8s.io/core:/stable:/v1.30/deb/Release.key | sudo gpg --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg
echo "deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/v1.30/deb/ /" | sudo tee /etc/apt/sources.list.d/kubernetes.list
sudo apt-get update
sudo apt update
sudo apt-get install -y kubelet kubeadm kubectl
sudo apt-mark hold kubelet kubeadm kubectl
