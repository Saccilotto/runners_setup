# GitHub Runners on GCP

This repository contains the necessary files to deploy GitHub Runners on Google Cloud Platform (GCP) using Terraform and Ansible.

## Project Structure

```plaintext
github-runners-gcp/
├── ansible/
│   ├── inventory                  # Created automatically by deploy.sh
│   ├── setup.yml                  # Main Ansible playbook
│   ├── vault_vars.yml            # Encrypted variables (created with ansible-vault)
│   ├── vault_vars.yml.example    # Template for vault variables
│   └── templates/
│       └── stack.yml.j2  # Docker Compose template
├── terraform/
│   ├── main.tf                   # Main Terraform configuration
│   ├── variables.tf              # Terraform variables definition
│   ├── terraform.tfvars          # Your variable values
│   └── outputs.tf                # Output values
└── deploy.sh                     # Main deployment ```
