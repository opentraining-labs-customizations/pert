# PERT Ansible Collections

This namespace contains Ansible collections for deploying and managing training content.

## Author

**Amrinder Singh**

## Available Collections

### pert.quickcourse

Ansible collection for deploying Red Hat Quick Course content to both local systems and OpenShift environments with automatic variable injection.

**Features:**
- Dual deployment modes (local bare metal and OpenShift)
- Automatic variable injection from extra-vars into course content
- Support for any Quick Course repository
- Podman + Traefik for local deployments
- Pod + Service + Route for OpenShift deployments

**Installation:**

```bash
# Install from Git
ansible-galaxy collection install git+https://github.com/YOUR-USERNAME/opentraining.git

# Or using requirements.yml
collections:
  - name: pert.quickcourse
    source: https://github.com/YOUR-USERNAME/opentraining.git
    type: git
    version: main
```

**Quick Start:**

```bash
# Deploy to OpenShift
ansible-playbook pert.quickcourse.deploy-quickcourse-ocp \
  -e "quickcourse_git_repo=https://github.com/RedHatQuickCourses/aap-on-openshift.git" \
  -e @./vars.yml
```

**Documentation:**
- [Full Collection Documentation](./quickcourse/README.md)
- [Git Setup Guide](../../COLLECTION_GIT_SETUP_GUIDE.md)
- [Deployment Summary](../../QUICKCOURSE_DEPLOYMENT_SUMMARY.md)

## Installation

### From Git Repository

```bash
# Latest version
ansible-galaxy collection install git+https://github.com/YOUR-USERNAME/opentraining.git

# Specific version
ansible-galaxy collection install git+https://github.com/YOUR-USERNAME/opentraining.git,v1.0.0
```

### Using requirements.yml

Create `requirements.yml`:

```yaml
---
collections:
  - name: pert.quickcourse
    source: https://github.com/YOUR-USERNAME/opentraining.git
    type: git
    version: main
```

Install:

```bash
ansible-galaxy collection install -r requirements.yml
```

## Usage Example

```yaml
---
- name: Deploy Quick Course
  hosts: localhost
  connection: local
  gather_facts: false

  collections:
    - pert.quickcourse

  vars:
    # Toggle deployment mode
    quickcourse_deployment_ocp: yes  # 'yes' for OpenShift, 'no' for local
    
    # Repository (required)
    quickcourse_git_repo: "https://github.com/RedHatQuickCourses/aap-on-openshift.git"
    quickcourse_git_ref: main
    
    # Auto-collect variables for injection
    quickcourse_auto_collect_vars: true

  pre_tasks:
    - name: Load environment variables
      include_vars:
        file: ./environment-vars.yml

  roles:
    - quickcourse_deployment

  post_tasks:
    - name: Display URL
      debug:
        msg: "Quick Course URL: {{ quickcourse_primary_view_url }}"
```

## Variable Injection

All variables from extra-vars and playbook vars are automatically collected and injected into the Quick Course content.

**Example variables file** (`vars.yml`):

```yaml
---
# OpenShift Environment
aap_controller_web_url: "https://aap-aap.apps.cluster-xxxxx.redhatworkshops.io"
aap_controller_admin_user: "admin"
aap_controller_admin_password: "changeme"

gitea_console_url: "https://gitea.apps.cluster-xxxxx.redhatworkshops.io"
openshift_cluster_ingress_domain: "apps.cluster-xxxxx.redhatworkshops.io"
openshift_cluster_console_url: "https://console-openshift-console.apps.cluster-xxxxx.redhatworkshops.io"

ssh_command: "ssh lab-user@ssh.example.com -p 22"
guid: "xxxxx-1"

# Any other custom variables
# They will be available in Quick Course content as {variable_name}
```

These variables become available in Quick Course AsciiDoc content:

```asciidoc
Access the AAP Controller at {aap_controller_web_url}

Your OpenShift cluster domain is {openshift_cluster_ingress_domain}

SSH to bastion: {ssh_command}
```

## Key Variables

| Variable | Required | Default | Description |
|----------|----------|---------|-------------|
| `quickcourse_deployment_ocp` | No | `no` | Toggle: `yes` for OpenShift, `no` for local |
| `quickcourse_git_repo` | **Yes** | `""` | Quick Course repository URL (must be provided at runtime) |
| `quickcourse_git_ref` | No | `main` | Git branch/tag to checkout |
| `quickcourse_auto_collect_vars` | No | `true` | Auto-collect variables for injection |
| `quickcourse_ocp_namespace` | No | `quickcourse-{{ guid }}` | OpenShift namespace |
| `quickcourse_primary_view_url` | Output | - | Deployed Quick Course URL |

## Deployment Modes

### OpenShift Deployment

```bash
ansible-playbook your-playbook.yml \
  -e "quickcourse_deployment_ocp=yes" \
  -e "quickcourse_git_repo=https://github.com/RedHatQuickCourses/aap-on-openshift.git" \
  -e @./vars.yml
```

**Creates:**
- Namespace: `quickcourse-{{ guid }}`
- Pod with init container (builder) + nginx container (server)
- Service exposing port 80
- Route with TLS edge termination

### Local Deployment

```bash
ansible-playbook your-playbook.yml \
  -e "quickcourse_deployment_ocp=no" \
  -e "quickcourse_git_repo=https://github.com/RedHatQuickCourses/aap-on-openshift.git" \
  -e @./vars.yml
```

**Creates:**
- System user: `quickcourse`
- Podman containers: Traefik (reverse proxy) + httpd (web server)
- systemd service: `quickcourse.service`
- Serves from: `/opt/quickcourse/content/build/site/`

## Requirements

### Local Deployment
- Podman
- Python podman-compose
- Node.js 18+
- Git

### OpenShift Deployment
- OpenShift cluster access (oc login)
- kubernetes.core Ansible collection
- Python kubernetes library

## Directory Structure

```
pert/
├── README.md                           # This file
└── quickcourse/
    ├── galaxy.yml                      # Collection metadata
    ├── README.md                       # Detailed documentation
    ├── CHANGELOG.md                    # Version history
    ├── roles/
    │   └── quickcourse_deployment/     # Main deployment role
    │       ├── defaults/
    │       │   └── main.yml
    │       ├── tasks/
    │       │   ├── main.yml
    │       │   ├── 10-quickcourse-dependencies.yml
    │       │   ├── 20-quickcourse-user-setup.yml
    │       │   ├── 30-quickcourse-clone-and-build.yml
    │       │   ├── 70-quickcourse-deploy-openshift.yml
    │       │   └── ...
    │       ├── templates/
    │       └── meta/
    ├── playbooks/
    │   └── deploy-quickcourse-ocp.yml  # Example OpenShift playbook
    └── examples/
        └── ocp-vars-example.yml        # Example variables file
```

## Support

For issues, questions, or contributions, please refer to the individual collection documentation in the `quickcourse/` directory.

## License

GPL-2.0-or-later

---

**Quick Links:**
- [Quick Course Collection Documentation](./quickcourse/README.md)
- [Example Playbooks](./quickcourse/playbooks/)
- [Example Variables](./quickcourse/examples/)
