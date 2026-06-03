# Variable Mapping: Showroom vs Quick Course

## Quick Answer

The equivalent of `showroom_host` in the quickcourse_deployment role is:

**`quickcourse_host`**

This variable contains the **hostname** of the system where the deployment is done.

---

## Complete Variable Comparison

| Purpose | Showroom Role | Quick Course Role |
|---------|--------------|-------------------|
| **Hostname** | `showroom_host` | `quickcourse_host` |
| **Full URL** | `f_lab_ui_url` (computed) | `f_lab_ui_url` (computed) |
| **Primary View URL** | `showroom_primary_view_url` | `quickcourse_primary_view_url` |
| **Primary Port** | `showroom_primary_port` | `quickcourse_primary_port` |
| **Primary Path** | `showroom_primary_path` | `quickcourse_primary_path` |
| **User** | `showroom_user` | `quickcourse_user` |
| **Home Directory** | `showroom_user_home_dir` | `quickcourse_user_home_dir` |
| **Content Directory** | `showroom_user_content_dir` | `quickcourse_user_content_dir` |
| **TLS Provider** | `showroom_tls_provider` | `quickcourse_tls_provider` |
| **ACME Email** | `showroom_acme_email` | `quickcourse_acme_email` |
| **Git Repository** | `showroom_git_repo` | `quickcourse_git_repo` |
| **Git Reference** | `showroom_git_ref` | `quickcourse_git_ref` |
| **Enable Deployment** | `showroom_deploy` | `quickcourse_deploy` |
| **Variable Injection** | `showroom_var_inject` | `quickcourse_var_inject` |
| **Custom Attributes** | `showroom_custom_attributes` | `quickcourse_custom_attributes` |

---

## Hostname Variable Details

### `quickcourse_host`

**Purpose:** The FQDN (fully qualified domain name) of the system where Quick Course is deployed.

**Default Behavior:**
- Automatically computed from: `{{ groups['bastions'][0] }}.{{ guid }}{{ subdomain_base_suffix }}`
- Falls back to: `{{ inventory_hostname }}` if bastions group doesn't exist

**You can override it:**
```yaml
vars:
  quickcourse_host: "training.example.com"
```

**Where it's used:**
- TLS certificate generation (for hostname verification)
- URL construction for user access
- Traefik routing rules

---

## URL Variables (Computed at Runtime)

These are **automatically generated** by the role during deployment:

### `f_lab_ui_url` (Temporary Variable)

**Format:** `https://{{ quickcourse_host }}:{{ quickcourse_primary_port }}/{{ quickcourse_primary_path }}`

**Example:** `https://bastion.guid.example.com/quickcourse/`

**Saved as AgnosticD user data:**
- `lab_ui_url`
- `quickcourse_primary_view_url`

### Port Handling

- If `quickcourse_primary_port: 443` → No port in URL
- If `quickcourse_primary_port: 8080` → URL includes `:8080`

---

## How to Access These Variables

### In Your Playbook

After the `quickcourse_deployment` role runs, you can access the generated URL:

```yaml
- name: Deploy Quick Course
  hosts: bastion
  roles:
    - quickcourse_deployment

- name: Use the generated URL
  debug:
    msg: "Course deployed at: {{ f_lab_ui_url }}"
```

### In AgnosticD User Data

The role outputs these to AgnosticD user data (accessible to students):

```yaml
data:
  lab_ui_url: "https://bastion.guid.example.com/quickcourse/"
  quickcourse_primary_view_url: "https://bastion.guid.example.com/quickcourse/"
  quickcourse_host: "bastion.guid.example.com"
```

Students receive these in their lab information email.

---

## Common Use Cases

### 1. Override the Hostname

If you're deploying on a specific host:

```yaml
vars:
  quickcourse_host: "training-server.company.com"
```

### 2. Change the URL Path

Default path is `/quickcourse/`. To change it:

```yaml
vars:
  quickcourse_primary_path: "course"
```

Result: `https://hostname/course/`

### 3. Use Non-Standard Port

```yaml
vars:
  quickcourse_primary_port: 8080
  quickcourse_tls_provider: none  # Disable TLS for HTTP
```

Result: `http://hostname:8080/quickcourse/`

### 4. Access Hostname in Your Course Template

The hostname is **automatically available** as a variable in your course if you enable auto-collection:

```yaml
vars:
  quickcourse_var_inject: true
  quickcourse_auto_collect_vars: true
  
  # quickcourse_host will be auto-collected!
```

Then in your `.adoc` file:
```asciidoc
Your course is running on: {quickcourse_host}
```

---

## Variable Lifecycle

### 1. Before Deployment

```yaml
# You can set (optional):
quickcourse_host: "my-server.example.com"  # Or let it auto-compute
quickcourse_primary_port: 443
quickcourse_primary_path: "quickcourse"
```

### 2. During Deployment (40-quickcourse-render.yml)

```yaml
# If quickcourse_host not defined, it's computed:
quickcourse_host: "bastion.guid.example.com"
```

### 3. At Verification (60-quickcourse-verify.yml)

```yaml
# URL is constructed:
f_lab_ui_url: "https://bastion.guid.example.com/quickcourse/"

# Saved to AgnosticD user data:
lab_ui_url: "https://bastion.guid.example.com/quickcourse/"
quickcourse_primary_view_url: "https://bastion.guid.example.com/quickcourse/"
quickcourse_host: "bastion.guid.example.com"
```

---

## Examples

### Example 1: Default Behavior (AgnosticD)

```yaml
- hosts: bastions
  vars:
    guid: "a1b2c"
    subdomain_base_suffix: ".example.com"
  roles:
    - quickcourse_deployment

# Result:
# quickcourse_host = "bastion.a1b2c.example.com"
# f_lab_ui_url = "https://bastion.a1b2c.example.com/quickcourse/"
```

### Example 2: Custom Hostname

```yaml
- hosts: webserver
  vars:
    quickcourse_host: "training.mycompany.com"
  roles:
    - quickcourse_deployment

# Result:
# quickcourse_host = "training.mycompany.com"
# f_lab_ui_url = "https://training.mycompany.com/quickcourse/"
```

### Example 3: Local Testing

```yaml
- hosts: localhost
  vars:
    quickcourse_host: "localhost"
    quickcourse_tls_provider: none
    quickcourse_primary_port: 8080
  roles:
    - quickcourse_deployment

# Result:
# quickcourse_host = "localhost"
# f_lab_ui_url = "http://localhost:8080/quickcourse/"
```

---

## Injecting Hostname into Course Content

If you want students to see the hostname in your course content:

### Method 1: Auto-Collection (Recommended)

```yaml
vars:
  quickcourse_var_inject: true
  quickcourse_auto_collect_vars: true
```

The `quickcourse_host` variable is automatically available in your `.adoc` files:

```asciidoc
Your lab is hosted on: {quickcourse_host}
Access URL: https://{quickcourse_host}/quickcourse/
```

### Method 2: Explicit

```yaml
vars:
  quickcourse_var_inject: true
  quickcourse_custom_attributes:
    course_hostname: "{{ quickcourse_host }}"
    course_url: "https://{{ quickcourse_host }}/quickcourse/"
```

Then in `.adoc`:
```asciidoc
Access URL: {course_url}
```

---

## Summary

| Question | Answer |
|----------|--------|
| What's the equivalent of `showroom_host`? | `quickcourse_host` |
| How do I get the full URL? | Use `f_lab_ui_url` (computed variable) |
| Can I override the hostname? | Yes: `quickcourse_host: "myhost.com"` |
| Is it available in course content? | Yes, enable `quickcourse_auto_collect_vars: true` |
| Where is it saved? | AgnosticD user data as `quickcourse_host` |

**Bottom Line:** Just replace `showroom_host` with `quickcourse_host` and everything works the same way! 🎉
