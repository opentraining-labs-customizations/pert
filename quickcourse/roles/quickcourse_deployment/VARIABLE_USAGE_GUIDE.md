# Variable Usage Guide: quickcourse_deployment Role

## Overview

The `quickcourse_deployment` role supports **THREE methods** for injecting variables into your Quick Course template:

1. ✅ **Auto-Collection** (Recommended) - Automatically collect ALL variables from your playbook
2. ✅ **Explicit Definition** - Define specific variables in `quickcourse_custom_attributes`
3. ✅ **Hybrid** - Use both methods together (variables are merged)

---

## Method 1: Auto-Collection (Easiest)

**Best for:** Most use cases, especially when using --extra-vars

### How It Works

When you enable `quickcourse_auto_collect_vars: true`, the role automatically collects ALL user-defined variables from your playbook and injects them into the course template.

### Example Playbook

```yaml
---
- hosts: bastion
  vars:
    # Enable variable injection
    quickcourse_var_inject: true
    quickcourse_auto_collect_vars: true  # Enable auto-collection

    # Repository configuration
    quickcourse_git_repo: https://github.com/RedHatQuickCourses/my-course.git
    quickcourse_acme_email: admin@example.com

    # YOUR VARIABLES - Directly in vars section!
    bastion_public_hostname: "bastion.example.com"
    ssh_username: "labuser"
    ssh_password: "P@ssw0rd123"
    openshift_console_url: "https://console.apps.ocp.example.com"
    cluster_admin_user: "kubeadmin"
    rhel9_instance_image: "rhel-9.2-x86_64"

  roles:
    - quickcourse_deployment
```

###Using with --extra-vars

```bash
ansible-playbook deploy.yml \
  --extra-vars "bastion_public_hostname=bastion.example.com" \
  --extra-vars "ssh_username=lab123user" \
  --extra-vars "ssh_password=secret123123"
```

**All extra-vars are automatically collected and injected!**

### What Gets Collected

✅ **Included:**
- All user-defined variables
- Variables from `vars:` section
- Variables from `--extra-vars`
- String and number values

❌ **Excluded (automatically filtered out):**
- Ansible internal vars (`ansible_*`)
- Role vars (`quickcourse_*`)
- Temporary/internal vars (`f_*`, `r_*`, `__*`)
- Complex types (lists, dictionaries)
- Variables in `quickcourse_auto_collect_exclude` list

---

## Method 2: Explicit Definition

**Best for:** When you want explicit control over which variables are injected

### Example Playbook

```yaml
---
- hosts: bastion
  vars:
    # Enable variable injection
    quickcourse_var_inject: true
    # Auto-collection is OFF (default: false)

    # Repository configuration
    quickcourse_git_repo: https://github.com/RedHatQuickCourses/my-course.git
    quickcourse_acme_email: admin@example.com

    # Explicitly define which variables to inject
    quickcourse_custom_attributes:
      bastion_public_hostname: "bastion.example.com"
      ssh_username: "labuser"
      ssh_password: "P@ssw0rd123"
      openshift_console_url: "https://console.apps.ocp.example.com"
      cluster_admin_user: "kubeadmin"

  roles:
    - quickcourse_deployment
```

### When to Use

- You want explicit control over injected variables
- You have many playbook variables but only want to inject a few
- You want to rename variables (e.g., `my_hostname` → `bastion_public_hostname`)

---

## Method 3: Hybrid (Both Methods)

**Best for:** Maximum flexibility

### Example Playbook

```yaml
---
- hosts: bastion
  vars:
    # Enable BOTH features
    quickcourse_var_inject: true
    quickcourse_auto_collect_vars: true

    # Variables in playbook (will be auto-collected)
    bastion_public_hostname: "bastion.example.com"
    ssh_username: "labuser"

    # Explicit variables (for renaming or control)
    quickcourse_custom_attributes:
      server_url: "{{ my_internal_server_url }}"
      custom_message: "Welcome to the lab!"

  roles:
    - quickcourse_deployment
```

### Merge Priority

When the same variable is defined in both places:

**Explicit wins!** `quickcourse_custom_attributes` takes precedence over auto-collected vars.

Merge order:
1. AgnosticD user data (if available)
2. Auto-collected variables
3. `quickcourse_custom_attributes` (highest priority)

---

## Configuration Options

### Enable Variable Injection

```yaml
quickcourse_var_inject: true  # REQUIRED to enable any variable injection
```

### Enable Auto-Collection

```yaml
quickcourse_auto_collect_vars: true  # Collect ALL user-defined vars
```

### Exclude Specific Variables from Auto-Collection

```yaml
quickcourse_auto_collect_exclude:
  - "my_internal_var"
  - "temporary_value"
  - "secret_not_for_course"
```

Default exclusions (already configured):
- `hostvars`, `groups`, `group_names`
- `inventory_hostname`, `inventory_dir`, `inventory_file`
- `playbook_dir`, `role_path`
- `discovered_interpreter_python`, `module_setup`

---

## Using Variables in Your Course

Once variables are injected, use them in your `.adoc` files:

```asciidoc
= Lab Instructions

Connect to the bastion host:

[source,bash]
----
ssh {ssh_username}@{bastion_public_hostname}
----

Password: `{ssh_password}`

OpenShift Console: {openshift_console_url}

Login as: {cluster_admin_user}
```

### Important Syntax Rules

✅ **Correct:** `{variable_name}` (no spaces)  
❌ **Wrong:** `{ variable_name }` (spaces cause literal text)

The role automatically fixes spacing issues during build, but use correct syntax in your source files.

---

## Complete Example: Production Deployment

```yaml
---
- name: Deploy Quick Course with Auto-Collection
  hosts: bastion
  vars:
    # ===========================================
    # Repository Configuration
    # ===========================================
    quickcourse_git_repo: https://github.com/RedHatQuickCourses/aap-on-openshift.git
    quickcourse_git_ref: main

    # ===========================================
    # TLS Configuration
    # ===========================================
    quickcourse_acme_email: training@example.com
    quickcourse_tls_provider: zerossl
    quickcourse_acme_zerossl_eab_kid: "{{ vault_zerossl_kid }}"
    quickcourse_acme_zerossl_eab_hmac_key: "{{ vault_zerossl_hmac }}"

    # ===========================================
    # Variable Injection (ENABLE AUTO-COLLECTION)
    # ===========================================
    quickcourse_var_inject: true
    quickcourse_auto_collect_vars: true

    # ===========================================
    # Lab Variables (AUTO-COLLECTED)
    # ===========================================
    bastion_public_hostname: "{{ hostvars[groups['bastions'][0]].public_dns_name }}"
    bastion_ssh_user_name: "ec2-user"
    bastion_ssh_password: "{{ common_password }}"
    
    ssh_username: "{{ student_name }}"
    ssh_password: "{{ student_password }}"
    
    openshift_cluster_console_url: "https://console-openshift-console.apps.{{ guid }}.{{ cluster_dns_zone }}"
    openshift_cluster_ingress_domain: "apps.{{ guid }}.{{ cluster_dns_zone }}"
    
    aap_controller_web_url: "https://aap-controller.apps.{{ guid }}.{{ cluster_dns_zone }}"
    aap_admin_username: "admin"
    aap_admin_password: "{{ vault_aap_password }}"

  roles:
    - quickcourse_deployment
```

---

## Verification

After deployment, verify variables were injected:

### 1. Check antora-playbook.yml

```bash
cat /opt/quickcourse/content/antora-playbook.yml
```

You should see your variables under `asciidoc.attributes`.

### 2. Check Rendered HTML

Open your course URL and navigate to pages that use variables. They should show actual values, not `{variable_name}`.

### 3. Test a Specific Variable

```bash
grep "bastion.example.com" /opt/quickcourse/content/build/site/*/chapter1/*.html
```

---

## Troubleshooting

### Variables Not Showing in HTML

**Problem:** Variables appear as `{variable_name}` in the rendered page.

**Causes:**
1. Variable has spaces: `{ var }` instead of `{var}`
2. Variable not defined in `quickcourse_custom_attributes` and auto-collection is OFF
3. Variable name mismatch

**Solution:**
- Enable auto-collection: `quickcourse_auto_collect_vars: true`
- Check variable syntax in `.adoc` files (no spaces)
- Verify variable is actually defined in your playbook

### Too Many Variables Injected

**Problem:** Auto-collection is injecting variables you don't want.

**Solution:**
Add them to the exclude list:

```yaml
quickcourse_auto_collect_exclude:
  - "my_internal_var"
  - "temp_value"
```

Or use Method 2 (explicit definition) instead.

### Variable Value is Wrong

**Problem:** Variable shows old/cached value.

**Solution:**
The role rebuilds on every deployment. Check:
1. Is the variable correctly defined in your playbook?
2. Are you passing the right value via `--extra-vars`?
3. Is there a conflict with `quickcourse_custom_attributes`? (It takes precedence)

---

## Best Practices

✅ **DO:**
- Use auto-collection for simplicity (`quickcourse_auto_collect_vars: true`)
- Pass sensitive values via Ansible Vault
- Use meaningful variable names (`bastion_hostname` not `h1`)
- Test variable injection in a dev environment first

❌ **DON'T:**
- Hardcode credentials in playbooks (use Vault)
- Use spaces in variable syntax `{ var }`
- Mix auto-collection and explicit definition without understanding merge priority
- Commit sensitive values to git

---

## Summary Table

| Feature | Auto-Collection | Explicit | Hybrid |
|---------|----------------|----------|--------|
| Enable with | `quickcourse_auto_collect_vars: true` | `quickcourse_custom_attributes: {}` | Both enabled |
| Ease of use | ⭐⭐⭐⭐⭐ | ⭐⭐⭐ | ⭐⭐⭐⭐ |
| Control | ⭐⭐⭐ | ⭐⭐⭐⭐⭐ | ⭐⭐⭐⭐⭐ |
| Works with --extra-vars | ✅ Yes | ❌ No | ✅ Yes |
| Variable renaming | ❌ No | ✅ Yes | ✅ Yes |
| Best for | Most cases | Fine control | Complex scenarios |

**Recommendation:** Start with auto-collection. Switch to explicit/hybrid only if needed.
