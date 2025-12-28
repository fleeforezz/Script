#!/bin/bash

set -e # Exit on error

# Default variables
USER="jso"
ANSIBLE_PLAYBOOK="playbooks.yml"
HOSTS="hosts.ini"

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

# Function: Check for Ansible installation
check_ansible() {
    print_status "Checking for Ansible installation..."

    if ! command -v ansible &> /dev/null; then
        print_warning "Ansible not found. Installing Ansible..."
        sudo apt update
        sudo apt install -y ansible
        print_success "Ansible installed successfully."
    else
        print_success "Ansible is already installed."
    fi
}

# Function: Run Ansible Playbooks
ansible_run() {
    print_status "Running Ansible Playbooks..."
    ansible-playbook $ANSIBLE_PLAYBOOK --user $USER -i $HOSTS
}

# Main execution
main() {
    update_system
    check_ansible

    echo -n "Do you want to run the Ansible playbooks now? (Y/n): "
    read RUN_ANSIBLE </dev/tty
    case $RUN_ANSIBLE in
        "Y" | "y") ansible_run && print_success "All tasks completed successfully!" ;;
        "N" | "n") print_success "Skipping Ansible playbooks." ;;
        *) print_warning "Invalid choice. Skipping Ansible playbooks." ;;
    esac
}

# Execute main function
main
