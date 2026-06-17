#!/bin/bash
# Generate complete login variables from AgnosticD vars.yaml
#
# Usage:
#   ./generate-login-vars.sh /path/to/vars.yaml > login-complete.yml
#
# Example:
#   ./generate-login-vars.sh /home/amrsingh/vars.yaml > /home/amrsingh/login-complete.yml

VARS_FILE="${1:-/home/amrsingh/vars.yaml}"

if [ ! -f "$VARS_FILE" ]; then
    echo "Error: vars.yaml not found at: $VARS_FILE" >&2
    exit 1
fi

# Extract values using jq (vars.yaml is JSON format)
OPENSHIFT_API_URL=$(jq -r '.openshift_api_url // empty' "$VARS_FILE")
OPENSHIFT_INGRESS=$(jq -r '.openshift_cluster_ingress_domain // empty' "$VARS_FILE")
GUID=$(jq -r '.guid // empty' "$VARS_FILE")
BASTION_HOST=$(jq -r '.bastion_ansible_host // empty' "$VARS_FILE")
BASTION_PORT=$(jq -r '.bastion_ansible_port // empty' "$VARS_FILE")
BASTION_USER=$(jq -r '.bastion_ansible_user // empty' "$VARS_FILE")
BASTION_PASS=$(jq -r '.bastion_ansible_ssh_pass // empty' "$VARS_FILE")
GITEA_HOSTNAME=$(jq -r '.ocp4_workload_gitea_operator_gitea_hostname // "gitea"' "$VARS_FILE")
GITEA_ADMIN=$(jq -r '.ocp4_workload_gitea_operator_admin_user // "opentlc-mgr"' "$VARS_FILE")
USER_BASE=$(jq -r '.ocp4_workload_authentication_htpasswd_user_base // "user"' "$VARS_FILE")
NUM_USERS=$(jq -r '.num_users // "1"' "$VARS_FILE")

# Generate YAML
cat <<EOF
---
# Generated from: $VARS_FILE
# Generated at: $(date -u +"%Y-%m-%d %H:%M:%S UTC")

# ============================================================
# OpenShift Cluster
# ============================================================
openshift_api_url: $OPENSHIFT_API_URL
openshift_console_url: https://console-openshift-console.$OPENSHIFT_INGRESS
openshift_cluster_ingress_domain: $OPENSHIFT_INGRESS

# ============================================================
# Gitea
# ============================================================
gitea_console_url: https://$GITEA_HOSTNAME.$OPENSHIFT_INGRESS
gitea_admin_username: $GITEA_ADMIN
gitea_user: ${USER_BASE}${NUM_USERS}

# Note: Passwords (common_admin_password, common_user_password) are
# dynamically generated and stored in the output_dir. Reference them
# from vars.yaml or use the computed-vars-helper.yml

# ============================================================
# SSH/Bastion Access
# ============================================================
ssh_command: "ssh $BASTION_USER@$BASTION_HOST -p $BASTION_PORT"
ssh_password: "$BASTION_PASS"
ssh_username: $BASTION_USER
ssh_address: $BASTION_HOST
ssh_port: "$BASTION_PORT"

# ============================================================
# Environment
# ============================================================
guid: $GUID

# ============================================================
# Usage
# ============================================================
# Deploy QuickCourse with:
#   ansible-playbook pert.quickcourse.deploy-quickcourse-ocp \\
#     -e "quickcourse_git_repo=https://github.com/..." \\
#     -e @this-file.yml \\
#     -e @computed-vars-helper.yml
EOF
