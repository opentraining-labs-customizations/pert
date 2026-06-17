# Variable Aliases Feature

## Overview

The Variable Aliases feature allows you to map multiple source variable names to a single target variable name in your Quick Course content. This provides flexibility when different environments or playbooks use different naming conventions.

## Why Use Variable Aliases?

1. **Standardization**: Use consistent variable names in your content regardless of source variable names
2. **Migration**: Transition from old variable names to new ones without updating all playbooks
3. **Flexibility**: Support multiple naming conventions across different environments
4. **Compatibility**: Work with variables from different AgnosticD workloads or environments

## How It Works

The alias resolution process:

1. You define a target variable name and a list of possible source variable names
2. During deployment, the role searches for each source variable in order (top to bottom)
3. The first found source variable's value is used
4. The value is injected into your Quick Course content as the target variable name
5. If none of the source variables are found, the target is simply not injected (non-blocking)

## Configuration

Add the `quickcourse_variable_aliases` dictionary to your playbook or variables file:

```yaml
quickcourse_variable_aliases:
  target_variable_name:
    - first_source_to_try
    - second_source_to_try
    - third_source_to_try
```

## Example

### Configuration

```yaml
quickcourse_variable_aliases:
  controller_url:
    - aap_controller_web_url
    - tower_url
    - automation_controller_url
```

### Source Variables (your playbook/extra-vars)

```yaml
# Your environment provides this variable
aap_controller_web_url: "https://controller.example.com"
```

### In Quick Course Content

```asciidoc
Access the controller at {controller_url}
```

### Result

```
Access the controller at https://controller.example.com
```

The `controller_url` target receives the value from `aap_controller_web_url` (the first match found).

## Complete Examples

### Example 1: Basic Aliases

```yaml
quickcourse_variable_aliases:
  # OpenShift Console
  openshift_console_url:
    - openshift_cluster_console_url
    - ocp_console_url
    - console_url

  # AAP Controller
  controller_url:
    - aap_controller_web_url
    - tower_url
```

### Example 2: Comprehensive Mapping

See **[examples/variable-aliases-example.yml](./examples/variable-aliases-example.yml)** for a complete set of common aliases.

### Example 3: Deployment Playbook

See **[examples/deploy-with-aliases.yml](./examples/deploy-with-aliases.yml)** for a complete deployment example.

## Usage

### Option 1: Include in Variables File

```bash
# Create aliases-config.yml
cat > aliases-config.yml <<EOF
quickcourse_variable_aliases:
  controller_url:
    - aap_controller_web_url
    - tower_url
EOF

# Deploy with aliases
ansible-playbook deploy.yml \
  -e @aliases-config.yml \
  -e @your-vars.yml
```

### Option 2: Include in Playbook

```yaml
- name: Deploy Quick Course
  hosts: localhost
  vars:
    quickcourse_variable_aliases:
      controller_url:
        - aap_controller_web_url
        - tower_url
  roles:
    - pert.quickcourse.quickcourse_deployment
```

### Option 3: Use Pre-defined Examples

```bash
ansible-playbook pert.quickcourse.deploy-quickcourse-ocp \
  -e "quickcourse_git_repo=https://github.com/..." \
  -e @examples/variable-aliases-example.yml \
  -e @your-environment-vars.yml
```

## Common Alias Patterns

### AAP/Automation Controller

```yaml
quickcourse_variable_aliases:
  controller_url:
    - aap_controller_web_url
    - tower_url
    - automation_controller_url

  controller_admin_user:
    - aap_controller_admin_user
    - tower_admin_user
    - admin_user

  controller_admin_password:
    - aap_controller_admin_password
    - tower_admin_password
    - admin_password
```

### OpenShift

```yaml
quickcourse_variable_aliases:
  openshift_console_url:
    - openshift_cluster_console_url
    - ocp_console_url
    - console_url

  openshift_api_url:
    - openshift_api_server_url
    - ocp_api_url
    - api_url

  openshift_ingress_domain:
    - openshift_cluster_ingress_domain
    - ocp_ingress_domain
    - apps_domain
```

### Gitea

```yaml
quickcourse_variable_aliases:
  git_console_url:
    - gitea_console_url
    - gitea_url
    - git_url

  git_admin_user:
    - gitea_admin_username
    - git_admin_username
```

## Error Handling

The alias resolution feature is **non-blocking**:

- If alias resolution fails, it will **not** stop the deployment
- If no source variables are found for a target, the target is simply not injected
- Errors are logged at verbosity level 1 (`-v`)
- Use `ignore_errors: true` on the alias resolution block (already configured)

## Debugging

### Enable Verbose Output

```bash
ansible-playbook deploy.yml -e @aliases.yml -v
```

This will show:
- Which aliases were resolved
- Number of alias mappings processed

### Check Collected Variables

Add a debug task to your playbook:

```yaml
- name: Debug collected variables
  debug:
    var: quickcourse_collected_vars
```

## Best Practices

1. **Order Matters**: Put the most common/preferred source variable first in the list
2. **Document**: Add comments explaining why aliases are needed
3. **Test**: Verify aliases work with your environment before production use
4. **Keep It Simple**: Only alias when necessary - direct variable names are clearer
5. **Avoid Conflicts**: Don't create circular or overlapping aliases

## Compatibility

- ✅ Works with auto-collection (`quickcourse_auto_collect_vars: true`)
- ✅ Works with custom attributes (`quickcourse_custom_attributes`)
- ✅ Works with both OpenShift and local deployments
- ✅ Non-blocking - deployment continues even if alias resolution fails
- ✅ Backward compatible - existing deployments work without changes

## Troubleshooting

### Alias Not Working

**Problem**: Target variable not appearing in content

**Solutions**:
1. Verify source variable exists in your playbook/extra-vars
2. Check variable name spelling
3. Run with `-v` to see alias resolution messages
4. Add debug task to check `quickcourse_collected_vars`

### Wrong Value Injected

**Problem**: Unexpected value in content

**Solutions**:
1. Check the order of source variables in your alias list
2. Verify only one source variable is defined
3. Remember: first found source wins

### Deployment Fails

**Problem**: Playbook fails during alias resolution

**Solutions**:
1. This should not happen (it's non-blocking), but if it does:
2. Check YAML syntax in your alias configuration
3. Ensure source list is an array, not a single value
4. Report issue with full error message

## Related Documentation

- [README.md](./README.md) - Main collection documentation
- [OPENSHIFT_DEPLOYMENT.md](./OPENSHIFT_DEPLOYMENT.md) - OpenShift deployment guide
- [examples/variable-aliases-example.yml](./examples/variable-aliases-example.yml) - Complete alias examples
- [examples/deploy-with-aliases.yml](./examples/deploy-with-aliases.yml) - Deployment playbook example

## Version

Feature added in: v1.0.0 (2026-06-17)
