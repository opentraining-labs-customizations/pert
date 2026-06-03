# Quick Course Deployment Role - Implementation Summary

## Overview

Successfully created a new Ansible role `quickcourse_deployment` at:
`/home/amrsingh/agnosticd/ansible/roles/quickcourse_deployment/`

This role deploys Red Hat Quick Course content (Antora-based documentation) following the same pattern as the `showroom` role but adapted for the Quick Course template structure.

## Key Differences from Showroom

| Feature | Showroom | Quick Course |
|---------|----------|--------------|
| Rendering | Containerized Antora | Node.js npm build |
| Output Directory | www/ | build/site/ |
| UI Management | Runtime injection | Pre-built ui-bundle.zip |
| Terminal Support | Default ON | Default OFF (optional) |
| Primary Use Case | Interactive labs | Documentation courses |

## Role Structure Created

```
quickcourse_deployment/
├── defaults/main.yml              # 100+ configuration variables
├── meta/main.yml                  # Galaxy metadata
├── README.md                      # Comprehensive documentation
├── files/                         # Empty (reserved for future use)
├── tasks/
│   ├── main.yml                   # Main orchestrator
│   ├── 10-quickcourse-dependencies.yml
│   ├── 20-quickcourse-user-setup.yml
│   ├── 22-quickcourse-users-security.yml
│   ├── 30-quickcourse-clone-and-build.yml  # Core: npm install + build
│   ├── 32-quickcourse-optional-terminals.yml
│   ├── 40-quickcourse-render.yml
│   ├── 50-quickcourse-service.yml
│   ├── 60-quickcourse-verify.yml
│   ├── extract_cert_key.yml       # TLS cert extraction
│   └── verify_tls_attempt.yml     # TLS verification
└── templates/
    ├── container-compose.yml.j2
    ├── quickcourse.service.j2
    ├── quickcourse-start.j2
    ├── quickcourse-stop.j2
    ├── quickcourse-user-socket.yml.j2
    ├── index.html.j2              # Terminal wrapper UI
    ├── base_service_traefik_httpd/
    │   └── base_service_traefik_httpd.j2
    ├── service_single_terminal/   # Optional terminal service
    │   ├── service_single_terminal.j2
    │   ├── tab_single_terminal.j2
    │   └── tablink_single_terminal.j2
    └── service_double_terminal/   # Optional dual terminals
        ├── service_double_tty.j2
        ├── tab_double_tty.j2
        └── tablink_double_tty.j2
```

## Core Workflow

1. **Install Dependencies** → podman, git, Node.js, npm, python packages
2. **Create User** → quickcourse user (UID 1889), directories, podman network
3. **Clone & Build** → git clone → npm install → npm run build
4. **Deploy Services** → Traefik + httpd (serving build/site/) + optional terminals
5. **Start & Verify** → systemd service, TLS verification, output URLs

## Key Variables

### Required
- `quickcourse_git_repo`: GitHub repository URL
- `quickcourse_acme_email`: Email for TLS certificates

### Important Defaults
- `quickcourse_user`: quickcourse (UID 1889)
- `quickcourse_user_build_dir`: /opt/quickcourse/content/build/site
- `quickcourse_primary_port`: 443 (HTTPS)
- `quickcourse_tls_provider`: zerossl
- `quickcourse_enable_terminals`: false
- `quickcourse_nodejs_version`: "18"
- `quickcourse_build_command`: "npm run build"

## Example Usage

### Basic Documentation Course
```yaml
- hosts: bastion
  vars:
    quickcourse_git_repo: https://github.com/RedHatQuickCourses/aap-on-openshift.git
    quickcourse_acme_email: admin@example.com
  roles:
    - quickcourse_deployment
```

### Hands-On Lab with Terminals
```yaml
- hosts: bastion
  vars:
    quickcourse_git_repo: https://github.com/RedHatQuickCourses/my-lab.git
    quickcourse_acme_email: admin@example.com
    quickcourse_enable_terminals: true
    quickcourse_tab_services:
      - single_terminal
  roles:
    - quickcourse_deployment
```

## Files Adapted from Showroom

**Direct Copies (no changes):**
- tasks/extract_cert_key.yml
- tasks/verify_tls_attempt.yml (variable names updated)
- templates/service_*_terminal/* (variable names updated)

**Pattern Reused:**
- Task file numbering and organization
- Traefik + httpd service composition
- TLS/ACME configuration
- Systemd service management

**Newly Created for Quick Course:**
- tasks/30-quickcourse-clone-and-build.yml (npm workflow)
- templates/base_service_traefik_httpd/base_service_traefik_httpd.j2 (serves build/site/)
- All variable definitions in defaults/main.yml

## Testing Recommendations

1. **Syntax Check:**
   ```bash
   ansible-playbook --syntax-check playbook.yml
   ```

2. **Dry Run:**
   ```bash
   ansible-playbook --check playbook.yml
   ```

3. **Test Deployment:**
   ```yaml
   - hosts: test_bastion
     vars:
       quickcourse_git_repo: https://github.com/RedHatQuickCourses/aap-on-openshift.git
       quickcourse_tls_provider: none  # Skip TLS for testing
       quickcourse_primary_port: 80
   ```

4. **Verify:**
   - User created: `id quickcourse`
   - Directories: `ls /opt/quickcourse/content/build/site`
   - Build output: `ls /opt/quickcourse/content/build/site/index.html`
   - Service: `systemctl status quickcourse.service`
   - Containers: `su - quickcourse -c "podman ps"`

## Implementation Notes

1. **Variable Consistency**: All variables use `quickcourse_` prefix for clarity
2. **Build Path**: Critical that httpd serves `build/site/` not `www/`
3. **Node.js Required**: Unlike showroom which uses containerized Antora
4. **Terminal Support**: Optional and defaults to disabled (most courses are docs-only)
5. **TLS Providers**: Supports zerossl, letsencrypt, or none
6. **Podman Network**: Creates dedicated `quickcourse_network` for container isolation
7. **User UID**: Uses 1889 (showroom uses 1888) to avoid conflicts

## Next Steps

1. Test the role in a development environment
2. Verify npm build works with real course repositories
3. Test TLS certificate generation with zerossl
4. Test terminal integration if needed
5. Add role to AgnosticD configs where appropriate
