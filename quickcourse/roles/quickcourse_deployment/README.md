# quickcourse_deployment

Ansible role for deploying Red Hat Quick Course content using Antora and containerized services.

## Description

This role deploys Quick Course template repositories (such as `aap-on-openshift`) by:
- Cloning the course repository from GitHub
- Installing Node.js and npm dependencies
- Building the Antora documentation site using `npm run build`
- Serving the built static site via containerized httpd with Traefik reverse proxy
- Optional terminal/IDE tab support for hands-on lab components

The role is based on the `showroom` role pattern but adapted specifically for the Quick Course template structure which uses Node.js-based builds instead of containerized Antora rendering.

## Requirements

- **Ansible**: 2.9 or higher
- **Host System**: RHEL 8/9 or Fedora
- **Podman**: Will be installed by the role if not present
- **Node.js**: 18+ (will be installed by the role)
- **Python**: Python 3 with pip support

## Role Variables

### Hostname Variable (like showroom_host)

**`quickcourse_host`** - The FQDN of the system where Quick Course is deployed.

- **Default:** Auto-computed from `{{ groups['bastions'][0] }}.{{ guid }}{{ subdomain_base_suffix }}`
- **Example:** `bastion.a1b2c.example.com`
- **Override:** Set `quickcourse_host: "your-hostname.com"` in your playbook

This is the equivalent of `showroom_host` in the showroom role.

### Required Variables

These variables must be set when using the role:

```yaml
quickcourse_git_repo: https://github.com/RedHatQuickCourses/aap-on-openshift.git
quickcourse_acme_email: admin@example.com
```

### Core Configuration Variables

```yaml
# Deployment control
quickcourse_deploy: true                    # Master enable/disable flag

# Repository settings
quickcourse_git_ref: main                   # Git branch/tag to deploy
quickcourse_primary_path: "quickcourse"     # URL path prefix

# Build configuration
quickcourse_nodejs_version: "18"            # Node.js major version
quickcourse_npm_install: true               # Run npm install
quickcourse_npm_build: true                 # Run npm build
quickcourse_build_command: "npm run build"  # Build command from package.json
```

### User and Directory Configuration

```yaml
quickcourse_user: quickcourse                           # System user for orchestration
quickcourse_user_uid: 1889                              # UID for the user
quickcourse_user_home_dir: /opt/quickcourse             # Base directory
quickcourse_user_content_dir: /opt/quickcourse/content  # Git clone location
quickcourse_user_build_dir: /opt/quickcourse/content/build/site  # Antora output
```

### Service Configuration

```yaml
quickcourse_primary_port: 443               # HTTPS port
quickcourse_http_port: 80                   # HTTP port (for ACME challenges)
quickcourse_frontend_service: traefik       # Reverse proxy (traefik or nginx)
```

### TLS/ACME Configuration

```yaml
quickcourse_tls_provider: zerossl           # TLS provider: zerossl, letsencrypt, or none
quickcourse_acme_email: john.doe@rhdp.net   # Email for certificate registration

# ZeroSSL settings (when using zerossl provider)
quickcourse_acme_zerossl_eab_kid: ""        # External Account Binding Key ID
quickcourse_acme_zerossl_eab_hmac_key: ""   # External Account Binding HMAC key
```

### Optional Terminal Support

Most quick courses are pure documentation and don't need terminals. Enable this for hands-on lab courses:

```yaml
quickcourse_enable_terminals: false         # Enable terminal tabs
quickcourse_tab_services: []                # List of terminal services to enable
                                            # Options: single_terminal, double_terminal
quickcourse_ssh_method: password            # SSH authentication: password or sshkey
quickcourse_lab_users:                      # Lab users for SSH access
  - rhel
```

### Container Images

```yaml
quickcourse_reverse_proxy_image: quay.io/rhpds/traefik
quickcourse_httpd_image: quay.io/redhat-gpte/showroom/httpd
quickcourse_tty_image: quay.io/rhpds/wetty  # Only if terminals enabled
```

### Variable Injection (Optional)

Quick courses typically don't need dynamic variable injection, but it's available:

```yaml
quickcourse_var_inject: false               # Enable variable injection into antora.yml
quickcourse_custom_attributes: {}           # Custom AsciiDoc attributes to inject
```

## Dependencies

None. This role manages all its dependencies internally.

## Example Playbooks

### Basic Quick Course Deployment (Documentation Only)

```yaml
---
- hosts: bastion
  vars:
    quickcourse_git_repo: https://github.com/RedHatQuickCourses/aap-on-openshift.git
    quickcourse_git_ref: main
    quickcourse_acme_email: training@example.com
    quickcourse_tls_provider: zerossl
    quickcourse_acme_zerossl_eab_kid: "{{ vault_zerossl_kid }}"
    quickcourse_acme_zerossl_eab_hmac_key: "{{ vault_zerossl_hmac }}"
    
  roles:
    - quickcourse_deployment
```

### Hands-On Lab Course with Terminals

```yaml
---
- hosts: bastion
  vars:
    quickcourse_git_repo: https://github.com/RedHatQuickCourses/my-lab-course.git
    quickcourse_git_ref: main
    quickcourse_acme_email: training@example.com
    
    # Enable terminal support
    quickcourse_enable_terminals: true
    quickcourse_tab_services:
      - single_terminal
    
    # SSH configuration for terminal access
    quickcourse_ssh_method: password
    quickcourse_lab_users:
      - labuser
      - student
    
  roles:
    - quickcourse_deployment
```

### Development/Testing Without TLS

```yaml
---
- hosts: bastion
  vars:
    quickcourse_git_repo: https://github.com/RedHatQuickCourses/test-course.git
    quickcourse_git_ref: develop
    quickcourse_tls_provider: none          # Disable TLS for testing
    quickcourse_primary_port: 80            # Use HTTP
    
  roles:
    - quickcourse_deployment
```

## Directory Structure Created

The role creates the following structure on the target host:

```
/opt/quickcourse/
├── content/                           # Git clone of the course repository
│   ├── antora.yml                     # Antora site configuration
│   ├── antora-playbook.yml            # Antora build configuration
│   ├── package.json                   # npm dependencies
│   ├── modules/                       # Course modules (ROOT, chapter1, etc.)
│   ├── ui-bundle/ui-bundle.zip        # Pre-built UI theme
│   ├── supplemental-ui/               # UI customizations
│   ├── node_modules/                  # Installed npm packages
│   └── build/site/                    # Built static site (served by httpd)
│       └── index.html
└── orchestration/
    ├── container-compose.yml          # Podman compose configuration
    └── acme.json                      # TLS certificate storage
```

## Workflow

The role executes in the following sequence:

1. **Dependencies** (10-quickcourse-dependencies.yml)
   - Install system packages (git, podman, systemd-container, unzip)
   - Install Python packages (podman-compose)
   - Install Node.js and npm

2. **User Setup** (20-quickcourse-user-setup.yml)
   - Create quickcourse user and directories
   - Configure sudoers
   - Set up podman network
   - Configure unprivileged port binding (for Traefik)
   - Enable systemd user linger

3. **SSH Configuration** (22-quickcourse-users-security.yml) - *Only if terminals enabled*
   - Configure SSH password or key-based authentication
   - Set up lab users
   - Restart sshd

4. **Clone and Build** (30-quickcourse-clone-and-build.yml) - **Core Task**
   - Clone the Git repository
   - Run `npm install` to install dependencies
   - Run `npm run build` to build the Antora site
   - Optional: Inject dynamic variables into antora.yml

5. **Optional Terminals** (32-quickcourse-optional-terminals.yml) - *Only if terminals enabled*
   - Set up terminal user directories
   - Configure terminal services

6. **Post-Build** (40-quickcourse-render.yml)
   - Verify build output directory exists
   - Optional: Inject HTML wrapper for terminals

7. **Service Deployment** (50-quickcourse-service.yml)
   - Template container-compose.yml
   - Create systemd service files
   - Start quickcourse.service
   - Wait for TLS certificate generation
   - Verify TLS (with retries)

8. **Verification** (60-quickcourse-verify.yml)
   - Output course URL to users
   - Provide access information

## Key Differences from Showroom Role

This role is based on the `showroom` role but adapted for Quick Course templates:

| Aspect | Showroom | Quick Course |
|--------|----------|--------------|
| **Content Rendering** | Containerized Antora | Node.js npm build |
| **Build Output** | Renders to `www/` | Builds to `build/site/` |
| **UI Management** | Injects UI overlays | Uses pre-built ui-bundle.zip |
| **Primary Use Case** | Interactive labs with terminals | Documentation courses |
| **Terminal Support** | Default enabled | Default disabled (optional) |
| **Variable Injection** | Common pattern | Optional (rarely used) |

## Verification

After deployment, verify the role execution:

```bash
# Check user created
id quickcourse

# Check directories
ls -la /opt/quickcourse/content
ls -la /opt/quickcourse/content/build/site

# Check build output
ls /opt/quickcourse/content/node_modules
ls /opt/quickcourse/content/build/site/index.html

# Check service status
systemctl status quickcourse.service

# Check containers
su - quickcourse -c "podman ps"

# Test URL access
curl -k https://$(hostname)/quickcourse/
```

## Troubleshooting

### Build Fails

Check npm build logs:
```bash
su - quickcourse
cd /opt/quickcourse/content
npm run build
```

### TLS Certificate Issues

Check Traefik logs:
```bash
su - quickcourse -c "podman logs reverse-proxy"
```

Verify acme.json permissions:
```bash
ls -la /opt/quickcourse/orchestration/acme.json
# Should be 600 (rw-------)
```

### Service Won't Start

Check systemd service status:
```bash
systemctl status quickcourse.service
journalctl -u quickcourse.service -n 50
```

Check podman-compose:
```bash
su - quickcourse
cd /opt/quickcourse/orchestration
podman-compose -f container-compose.yml ps
```

## License

GPL-2.0-or-later

## Author Information

Red Hat Training Team

This role was created as part of the AgnosticD project for deploying training content at scale.
