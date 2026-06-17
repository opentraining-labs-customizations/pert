# OpenShift Deployment Guide

Complete guide for deploying Quick Course to OpenShift with automatic variable injection.

## Table of Contents

- [Overview](#overview)
- [Requirements](#requirements)
- [Quick Start](#quick-start)
- [OpenShift-Specific Variables](#openshift-specific-variables)
- [Variable Injection](#variable-injection)
- [Deployment Process](#deployment-process)
- [Troubleshooting](#troubleshooting)

## Overview

The Quick Course collection supports deploying to OpenShift by setting `quickcourse_deployment_ocp: yes`. This creates:

- **Pod** with init container (builder) + nginx container (server)
- **Service** exposing port 80
- **Route** with TLS edge termination
- **Automatic variable injection** from extra-vars into course content

## Requirements

### Prerequisites

- OpenShift cluster access (4.x or later)
- `oc` CLI installed and authenticated (`oc login`)
- Ansible 2.9+
- `kubernetes.core` collection installed
- Python `kubernetes` library

### Install Dependencies

```bash
# Install kubernetes.core collection
ansible-galaxy collection install kubernetes.core

# Install Python kubernetes library
pip install kubernetes
```

## Quick Start

### 1. Login to OpenShift

```bash
oc login --server=https://api.cluster-xxxxx.example.com:6443 --token=YOUR-TOKEN
```

### 2. Deploy with Auto-Discovery (Recommended)

The role automatically discovers most variables from the cluster using `oc` commands:

```bash
# Minimal deployment - auto-discovers all cluster variables
ansible-playbook pert.quickcourse.deploy-quickcourse-ocp \
  -e "quickcourse_git_repo=https://github.com/RedHatQuickCourses/aap-on-openshift.git"
```

**Auto-Discovered Variables:**
- OpenShift ingress domain, API URL, console URL
- GUID (from namespace or cluster name)
- Gitea console URL, admin username, admin password
- AAP Controller URL and admin password

### 3. (Optional) Prepare Variables File

If you need to override auto-discovered values or add custom variables, create `ocp-vars.yml`:

```yaml
---
# OpenShift Environment Variables
aap_controller_web_url: "https://aap-aap.apps.cluster-xxxxx.example.com"
aap_controller_admin_user: "admin"
aap_controller_admin_password: "changeme"

gitea_console_url: "https://gitea.apps.cluster-xxxxx.example.com"
gitea_admin_username: "opentlc-mgr"
gitea_admin_password: "changeme"
gitea_user: "user1"
gitea_password: "changeme"

openshift_cluster_console_url: "https://console-openshift-console.apps.cluster-xxxxx.example.com"
openshift_cluster_admin_username: "admin"
openshift_cluster_admin_password: "changeme"
openshift_cluster_ingress_domain: "apps.cluster-xxxxx.example.com"
openshift_api_server_url: "https://api.cluster-xxxxx.example.com:6443"

ssh_command: "ssh lab-user@bastion.example.com -p 22"
ssh_password: "changeme"
ssh_address: "bastion.example.com"
ssh_port: "22"
ssh_username: "lab-user"

guid: "xxxxx-1"

# Add any other custom variables you want injected
```

### 4. Deploy to OpenShift

```bash
# With auto-discovery (recommended)
ansible-playbook pert.quickcourse.deploy-quickcourse-ocp \
  -e "quickcourse_git_repo=https://github.com/RedHatQuickCourses/aap-on-openshift.git"

# Or with custom variables file
ansible-playbook pert.quickcourse.deploy-quickcourse-ocp \
  -e "quickcourse_git_repo=https://github.com/RedHatQuickCourses/aap-on-openshift.git" \
  -e @ocp-vars.yml
```

### 5. Access Quick Course

The playbook will output the URL:

```
Quick Course URL: https://quickcourse-quickcourse-xxxxx-1.apps.cluster-xxxxx.example.com/
```

## OpenShift-Specific Variables

### Core Deployment Variables

| Variable | Required | Default | Description |
|----------|----------|---------|-------------|
| `quickcourse_deployment_ocp` | No | `no` | **Set to `yes` to enable OpenShift deployment** |
| `quickcourse_git_repo` | **YES** | `""` | Quick Course repository URL (must be provided at runtime) |
| `quickcourse_git_ref` | No | `main` | Git branch or tag to deploy |

### OpenShift Configuration Variables

| Variable | Required | Default | Description |
|----------|----------|---------|-------------|
| `quickcourse_ocp_namespace` | No | `quickcourse-{{ guid }}` | OpenShift namespace/project name |
| `quickcourse_ocp_builder_image` | No | `registry.access.redhat.com/ubi9/nodejs-18:latest` | Container image for build init container |
| `quickcourse_ocp_webserver_image` | No | `docker.io/library/nginx:alpine` | Container image for web server |

### Variable Injection Configuration

| Variable | Required | Default | Description |
|----------|----------|---------|-------------|
| `quickcourse_auto_discover_vars` | No | `true` | Automatically discover missing variables from OpenShift cluster using `oc` commands |
| `quickcourse_auto_collect_vars` | No | `true` | Automatically collect all extra-vars for injection |
| `quickcourse_custom_attributes` | No | `{}` | Dictionary of additional variables to inject |
| `quickcourse_variable_aliases` | No | `{}` | Map multiple source variable names to single target names (see below) |

### Output Variables

| Variable | Type | Description |
|----------|------|-------------|
| `quickcourse_primary_view_url` | Output | Full HTTPS URL where Quick Course is accessible after deployment |

## Variable Injection

### How It Works

1. **Auto-Discovery**: Missing variables are discovered from OpenShift cluster using `oc` commands (if logged in)
   - Discovers: ingress domain, API URL, console URL, GUID, Gitea URL/credentials, AAP URL/password
   - Non-blocking: deployment continues if discovery fails
   - Only discovers variables that are not already defined
2. **Auto-Collection**: All variables from `-e` extra-vars and playbook vars are collected
3. **Filtering**: System variables are excluded (ansible_*, quickcourse_*, hostvars, groups, etc.)
4. **Alias Resolution**: Variable aliases are resolved (optional - maps multiple names to one target)
5. **Injection**: Variables are injected into `antora-playbook.yml` under `asciidoc.attributes`
6. **Build**: npm build runs with injected variables
7. **Usage**: Variables available in AsciiDoc content as `{variable_name}`

### Example

**Variables file** (`ocp-vars.yml`):
```yaml
aap_controller_web_url: "https://aap-aap.apps.cluster-h955j.example.com"
openshift_cluster_ingress_domain: "apps.cluster-h955j.example.com"
guid: "h955j-1"
```

**In Quick Course content** (`.adoc` files):
```asciidoc
Access the AAP Controller at {aap_controller_web_url}

Your OpenShift cluster domain is {openshift_cluster_ingress_domain}

Your GUID is {guid}
```

**Rendered output**:
```
Access the AAP Controller at https://aap-aap.apps.cluster-h955j.example.com

Your OpenShift cluster domain is apps.cluster-h955j.example.com

Your GUID is h955j-1
```

### Common Variables for OpenShift Deployments

```yaml
# AAP/Automation Controller
aap_controller_web_url: ""
aap_controller_admin_user: ""
aap_controller_admin_password: ""

# Gitea
gitea_console_url: ""
gitea_admin_username: ""
gitea_admin_password: ""
gitea_user: ""
gitea_password: ""

# OpenShift Cluster
openshift_cluster_console_url: ""
openshift_cluster_admin_username: ""
openshift_cluster_admin_password: ""
openshift_cluster_ingress_domain: ""
openshift_api_server_url: ""

# SSH/Bastion Access
ssh_command: ""
ssh_password: ""
ssh_address: ""
ssh_port: ""
ssh_username: ""

# Environment
guid: ""

# Windows (if applicable)
windows_user: ""
windows_password: ""

# Custom variables
# Add any other variables needed by your Quick Course content
```

### Variable Aliases (Advanced)

Variable aliases allow you to map multiple source variable names to a single target variable name in your content. This is useful when:
- Different environments use different naming conventions
- You want to standardize variable names across courses
- You're migrating from old variable names to new ones

**Example configuration:**
```yaml
quickcourse_variable_aliases:
  # Content uses {controller_url}, accepts multiple sources
  controller_url:
    - aap_controller_web_url    # Try this first
    - tower_url                  # Then this
    - automation_controller_url  # Finally this
  
  openshift_console_url:
    - openshift_cluster_console_url
    - ocp_console_url
    - console_url
```

**How it works:**
1. The role searches for each source variable in order (top to bottom)
2. The first found source variable's value is used
3. The value is injected as the target variable name
4. If none are found, the target variable is not injected (non-blocking)

**Example usage:**
```bash
# Use pre-defined aliases with your variables
ansible-playbook pert.quickcourse.deploy-quickcourse-ocp \
  -e "quickcourse_git_repo=https://github.com/..." \
  -e @examples/variable-aliases-example.yml \
  -e @your-ocp-vars.yml
```

See **[examples/variable-aliases-example.yml](./examples/variable-aliases-example.yml)** for complete examples.

## Deployment Process

### What Happens During Deployment

1. **Pre-flight Checks**
   - Validates `quickcourse_git_repo` is provided
   - Collects all variables for injection

2. **Namespace Creation**
   - Creates/verifies OpenShift namespace
   - Default: `quickcourse-{{ guid }}`

3. **Variable Preparation**
   - Collects all extra-vars
   - Filters system variables
   - Formats for injection into antora-playbook.yml

4. **Pod Deployment**
   - **Init Container** (builder):
     - Installs git
     - Clones repository
     - Injects variables into antora-playbook.yml
     - Runs `npm install`
     - Runs `npm run build`
     - Copies build output to shared volume
   - **Main Container** (nginx):
     - Serves static content from shared volume

5. **Service Creation**
   - Creates ClusterIP service
   - Exposes port 80

6. **Route Creation**
   - Creates Route with TLS edge termination
   - Auto-generated hostname: `quickcourse-<namespace>.<ingress_domain>`

7. **Wait for Ready**
   - Polls pod status until Running
   - Maximum 10 minutes wait time

8. **URL Output**
   - Sets `quickcourse_primary_view_url`
   - Displays URL for access

### Resource Overview

**Created Resources:**
```
Namespace: quickcourse-h955j-1
├── Pod: quickcourse
│   ├── Init Container: builder (build Quick Course)
│   └── Container: nginx (serve content)
├── Service: quickcourse (ClusterIP, port 80)
└── Route: quickcourse (TLS edge, auto hostname)
```

**Pod Spec:**
```yaml
spec:
  initContainers:
  - name: builder
    image: registry.access.redhat.com/ubi9/nodejs-18:latest
    # Clones repo, injects vars, builds with npm
    
  containers:
  - name: nginx
    image: nginx:alpine
    ports:
    - containerPort: 80
    # Serves from /usr/share/nginx/html
    
  volumes:
  - name: app
    emptyDir: {}  # Shared between init and main container
  - name: build
    emptyDir: {}  # Build workspace
```

## Advanced Usage

### Custom Namespace

```bash
ansible-playbook pert.quickcourse.deploy-quickcourse-ocp \
  -e "quickcourse_deployment_ocp=yes" \
  -e "quickcourse_ocp_namespace=my-training" \
  -e "quickcourse_git_repo=https://github.com/RedHatQuickCourses/REPO.git" \
  -e @vars.yml
```

### Different Git Branch

```bash
ansible-playbook pert.quickcourse.deploy-quickcourse-ocp \
  -e "quickcourse_deployment_ocp=yes" \
  -e "quickcourse_git_repo=https://github.com/RedHatQuickCourses/REPO.git" \
  -e "quickcourse_git_ref=develop" \
  -e @vars.yml
```

### Custom Container Images

```bash
ansible-playbook pert.quickcourse.deploy-quickcourse-ocp \
  -e "quickcourse_deployment_ocp=yes" \
  -e "quickcourse_ocp_builder_image=registry.access.redhat.com/ubi9/nodejs-20:latest" \
  -e "quickcourse_ocp_webserver_image=docker.io/library/nginx:1.25-alpine" \
  -e "quickcourse_git_repo=https://github.com/RedHatQuickCourses/REPO.git" \
  -e @vars.yml
```

### Manual Variable Injection (Override Auto-collect)

```bash
ansible-playbook pert.quickcourse.deploy-quickcourse-ocp \
  -e "quickcourse_deployment_ocp=yes" \
  -e "quickcourse_auto_collect_vars=false" \
  -e "quickcourse_custom_attributes={'my_var': 'value', 'another_var': 'value2'}" \
  -e "quickcourse_git_repo=https://github.com/RedHatQuickCourses/REPO.git"
```

## Troubleshooting

### Check Pod Status

```bash
# Get namespace from your deployment
NAMESPACE="quickcourse-xxxxx-1"

# Check pod status
oc get pod -n $NAMESPACE

# Check pod logs (builder init container)
oc logs quickcourse -n $NAMESPACE -c builder

# Check pod logs (nginx main container)
oc logs quickcourse -n $NAMESPACE -c nginx

# Describe pod
oc describe pod quickcourse -n $NAMESPACE
```

### Check Service and Route

```bash
# Check service
oc get svc -n $NAMESPACE

# Check route
oc get route -n $NAMESPACE

# Get route URL
oc get route quickcourse -n $NAMESPACE -o jsonpath='{.spec.host}'
```

### Common Issues

#### Issue: Pod stuck in Init:0/1

**Cause**: Init container (builder) is still running or failed

**Solution**:
```bash
# Check builder logs
oc logs quickcourse -n $NAMESPACE -c builder

# Common causes:
# - Git clone failed (check repo URL)
# - npm install failed (check network/registry access)
# - npm build failed (check Quick Course repo is valid)
```

#### Issue: Variables showing as {variable_name} in content

**Cause**: Variables not injected or wrong variable names

**Solution**:
1. Check variable names match exactly (case-sensitive)
2. Verify variables passed via `-e @vars.yml`
3. Check builder logs to see injected variables:
   ```bash
   oc logs quickcourse -n $NAMESPACE -c builder | grep -A 20 "Variables Injected"
   ```

#### Issue: Route returns 503 Service Unavailable

**Cause**: Pod not running or nginx not serving correctly

**Solution**:
```bash
# Check pod is Running
oc get pod quickcourse -n $NAMESPACE

# Check nginx logs
oc logs quickcourse -n $NAMESPACE -c nginx

# Test service directly
oc port-forward quickcourse 8080:80 -n $NAMESPACE
# Access http://localhost:8080 in browser
```

#### Issue: Permission denied errors

**Cause**: OpenShift security context constraints

**Solution**: The init container runs as root (runAsUser: 0) which is allowed in most OpenShift environments. If denied:
```bash
# Check SCC
oc get pod quickcourse -n $NAMESPACE -o yaml | grep -A 5 securityContext

# Grant anyuid SCC to default service account (if allowed)
oc adm policy add-scc-to-user anyuid -z default -n $NAMESPACE
```

### Debugging Tips

**Enable verbose logging:**
```bash
ansible-playbook pert.quickcourse.deploy-quickcourse-ocp \
  -e "quickcourse_git_repo=https://github.com/RedHatQuickCourses/REPO.git" \
  -e @vars.yml \
  -vvv
```

**Check what variables were collected:**
Add debug task to playbook:
```yaml
- name: Debug collected variables
  debug:
    var: quickcourse_collected_vars
```

**Verify antora-playbook.yml in running pod:**
```bash
# Access running pod
oc exec -it quickcourse -n $NAMESPACE -- /bin/sh

# View injected variables (from builder container artifacts)
# Note: This won't work in nginx container as build dir is separate
```

## Complete Example Playbook

```yaml
---
- name: Deploy Quick Course to OpenShift
  hosts: localhost
  connection: local
  gather_facts: false

  vars:
    # Enable OpenShift deployment
    quickcourse_deployment_ocp: yes
    
    # Repository configuration
    quickcourse_git_ref: main
    
    # Auto-collect variables
    quickcourse_auto_collect_vars: true
    
    # Optional: Custom namespace
    # quickcourse_ocp_namespace: "my-training"

  pre_tasks:
    - name: Verify oc login
      command: oc whoami
      register: oc_user
      changed_when: false
      
    - name: Display OpenShift user
      debug:
        msg: "Deploying as OpenShift user: {{ oc_user.stdout }}"
    
    - name: Load environment variables
      include_vars:
        file: ./ocp-vars.yml

  roles:
    - pert.quickcourse.quickcourse_deployment

  post_tasks:
    - name: Display deployment summary
      debug:
        msg: |
          ========================================
          Quick Course Deployment Complete!
          ========================================
          
          Quick Course URL: {{ quickcourse_primary_view_url }}
          
          Namespace: {{ quickcourse_ocp_namespace }}
          
          All variables from ocp-vars.yml have been injected
          ========================================
```

## Next Steps

- [Main Collection README](./README.md)
- [Example Variables File](./examples/ocp-vars-example.yml)
- [Example Playbook](./playbooks/deploy-quickcourse-ocp.yml)
- [Git Setup Guide](../../COLLECTION_GIT_SETUP_GUIDE.md)
