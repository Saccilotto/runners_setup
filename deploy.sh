#!/bin/bash
set -e

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# Print colored message
function print_message() {
  echo -e "${GREEN}[INFO]${NC} $1"
}

function print_warning() {
  echo -e "${YELLOW}[WARNING]${NC} $1"
}

function print_error() {
  echo -e "${RED}[ERROR]${NC} $1"
  exit 1
}

# Check for required tools
if ! command -v terraform &> /dev/null; then
  print_error "Terraform is not installed. Please install it first."
fi

if ! command -v ansible-playbook &> /dev/null; then
  print_error "Ansible is not installed. Please install it first."
fi

# Check if vault variables file exists
if [ ! -f "./ansible/vault_vars.yml" ]; then
  print_warning "vault_vars.yml not found or not encrypted."
  read -p "Do you want to create and encrypt it now? (y/n): " create_vault
  if [[ $create_vault == "y" || $create_vault == "Y" ]]; then
    if [ ! -d "./ansible" ]; then
      mkdir -p ./ansible
    fi
    cp ./ansible/vault_vars.yml.example ./ansible/vault_vars.yml
    print_message "Edit the file with your secrets:"
    read -p "Press Enter to continue..."
    ${EDITOR:-vi} ./ansible/vault_vars.yml
    
    # Encrypt the file
    ansible-vault encrypt ./ansible/vault_vars.yml
    print_message "File encrypted successfully."
  else
    print_warning "Continuing without vault configuration. You'll need to provide GitHub token manually."
  fi
fi

# Ensure terraform configuration is valid
print_message "Validating Terraform configuration..."
cd terraform
terraform init
terraform validate || print_error "Terraform validation failed!"

# Ask for confirmation
read -p "This will create resources in your GCP account. Continue? (y/n): " confirm
if [[ $confirm != "y" && $confirm != "Y" ]]; then
  print_message "Deployment canceled."
  exit 0
fi

# Apply Terraform configuration
print_message "Applying Terraform configuration..."
terraform apply || print_error "Terraform apply failed!"

# Get the VM IP address
VM_IP=$(terraform output -raw vm_ip)
print_message "VM deployed with IP address: $VM_IP"

# Create ansible inventory file
print_message "Creating Ansible inventory..."
echo "[github_runners]" > ../ansible/inventory
echo "${VM_IP} ansible_user=ubuntu ansible_ssh_common_args='-o StrictHostKeyChecking=no'" >> ../ansible/inventory

# Wait for VM to be fully operational
print_message "Waiting for VM to become available..."
sleep 30

# Run Ansible playbook
print_message "Running Ansible playbook..."
cd ../ansible
ansible-playbook -i inventory setup.yml --ask-vault-pass || print_error "Ansible playbook execution failed!"

print_message "Deployment completed successfully!"
print_message "GitHub Runners should be active in a few minutes."
print_message "VM IP: ${VM_IP}"