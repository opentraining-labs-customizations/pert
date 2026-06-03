# Quick Course Ansible Collection

Ansible collection for deploying Red Hat Quick Course content to both local systems and OpenShift environments with automatic variable injection.

## Collection Contents

### Roles

- **quickcourse_deployment**: Deploy Quick Course content with npm build
  - Supports local (bare metal) deployment with Podman + Traefik
  - Supports OpenShift deployment with Pod + Service + Route
  - Auto-collects variables from playbook/extra-vars and injects into content

### Playbooks

- **playbooks/deploy-quickcourse-ocp.yml**: Example OpenShift deployment playbook

## Installation

```bash
# From local collection
ansible-galaxy collection install /home/amrsingh/ansible_collections/pert/quickcourse

# Or add to requirements.yml
collections:
  - name: pert.quickcourse
    source: /home/amrsingh/ansible_collections/pert/quickcourse
    type: dir
```

## Usage

### OpenShift Deployment

Deploy Quick Course to OpenShift with automatic variable injection:

```bash
ansible-playbook pert.quickcourse.deploy-quickcourse-ocp \
  -e "quickcourse_git_repo=https://github.com/RedHatQuickCourses/aap-on-openshift.git" \
  -e @/path/to/variables.yml
```

**Required Variables:**
- `quickcourse_git_repo`: URL of the Quick Course repository

**Example Variables File** (`variables.yml`):
```yaml
---
# All variables defined here are automatically injected into Quick Course content

# OpenShift Environment
aap_controller_web_url: "https://aap-aap.apps.cluster-xxxxx.redhatworkshops.io"
aap_controller_admin_user: "admin"
aap_controller_admin_password: "changeme"

gitea_console_url: "https://gitea.apps.cluster-xxxxx.redhatworkshops.io"
gitea_admin_username: "opentlc-mgr"
gitea_admin_password: "changeme"

openshift_cluster_console_url: "https://console-openshift-console.apps.cluster-xxxxx.redhatworkshops.io"
openshift_cluster_ingress_domain: "apps.cluster-xxxxx.redhatworkshops.io"

ssh_command: "ssh lab-user@ssh.example.com -p 22"
ssh_password: "changeme"

guid: "xxxxx-1"
```

### Local Deployment

Deploy Quick Course to local system (bare metal):

```bash
ansible-playbook your-playbook.yml \
  -e "quickcourse_deployment_ocp=no" \
  -e "quickcourse_git_repo=https://github.com/RedHatQuickCourses/aap-on-openshift.git" \
  -e @/path/to/variables.yml
```

## Key Variables

### Deployment Mode

- `quickcourse_deployment_ocp`: Toggle deployment mode
  - `yes`: Deploy to OpenShift (default for OCP playbook)
  - `no`: Deploy locally with Podman (default for local playbook)

### Repository Configuration

- `quickcourse_git_repo`: **(Required)** URL of Quick Course repository
- `quickcourse_git_ref`: Git branch/tag (default: `main`)

### Variable Injection

- `quickcourse_auto_collect_vars`: Auto-collect variables for injection (default: `true`)
- `quickcourse_custom_attributes`: Additional custom variables to inject

### OpenShift Configuration

- `quickcourse_ocp_namespace`: OpenShift namespace (default: `quickcourse-{{ guid }}`)
- `quickcourse_ocp_builder_image`: Builder image (default: `registry.access.redhat.com/ubi9/nodejs-18:latest`)
- `quickcourse_ocp_webserver_image`: Web server image (default: `docker.io/library/nginx:alpine`)

### Output Variables

- `quickcourse_primary_view_url`: URL where Quick Course is accessible after deployment

## How Variable Injection Works

1. **Auto-Collection**: All variables from extra-vars and playbook vars are automatically collected
2. **Filtering**: System variables (ansible_*, quickcourse_*, etc.) are excluded
3. **Injection**: Variables are injected into `antora-playbook.yml` under `asciidoc.attributes`
4. **Usage in Content**: Variables are available in AsciiDoc as `{variable_name}`

Example in Quick Course content:
```asciidoc
Access the AAP Controller at {aap_controller_web_url}

Your OpenShift cluster domain is {openshift_cluster_ingress_domain}

SSH to bastion: {ssh_command}
```

## Example Playbook

```yaml
---
- name: Deploy Quick Course to OpenShift
  hosts: localhost
  connection: local
  gather_facts: false

  vars:
    quickcourse_deployment_ocp: yes
    quickcourse_git_ref: main
    quickcourse_auto_collect_vars: true

  pre_tasks:
    - name: Load environment variables
      include_vars:
        file: /path/to/environment-vars.yml

  roles:
    - pert.quickcourse.quickcourse_deployment

  post_tasks:
    - name: Display URL
      debug:
        msg: "Quick Course URL: {{ quickcourse_primary_view_url }}"
```

## Requirements

### Local Deployment
- Podman
- Python podman-compose
- Node.js 18+
- Git

### OpenShift Deployment
- OpenShift cluster access (oc login)
- kubernetes.core collection
- Python kubernetes library

## License

GPL-2.0-or-later

## Author

Amrinder Singh
