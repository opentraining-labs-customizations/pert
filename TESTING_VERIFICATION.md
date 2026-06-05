# Quick Course Collection - Testing Verification

## Variable Format Support

✅ **VERIFIED**: Both JSON and YAML formats are fully supported for variable injection.

### Test Results

#### 1. JSON Format Test
- **Test File**: `/home/amrsingh/test-vars.json`
- **Status**: ✅ PASSED
- **Pod Status**: Running (1/1)
- **Variable Injection**: Confirmed
- **Test Variable**: `test_json_format: "This is from JSON file"` successfully injected

#### 2. YAML Format Test
- **Test File**: `/home/amrsingh/test-vars.yaml`
- **Status**: ✅ PASSED
- **Pod Status**: Running (1/1)
- **Variable Injection**: Confirmed
- **Test Variable**: `test_yaml_format: "This is from YAML file"` successfully injected

## Usage Examples

### Using JSON Format
```bash
ansible-playbook deploy.yml -e @variables.json
```

Example `variables.json`:
```json
{
  "guid": "889ws",
  "openshift_api_url": "https://api.cluster-889ws.dynamic2.redhatworkshops.io:6443",
  "openshift_cluster_ingress_domain": "apps.cluster-889ws.dynamic2.redhatworkshops.io",
  "quickcourse_deployment_ocp": true,
  "quickcourse_git_repo": "https://github.com/RedHatQuickCourses/aap-on-openshift.git"
}
```

### Using YAML Format
```bash
ansible-playbook deploy.yml -e @variables.yml
```

Example `variables.yml`:
```yaml
guid: "889ws"
openshift_api_url: "https://api.cluster-889ws.dynamic2.redhatworkshops.io:6443"
openshift_cluster_ingress_domain: "apps.cluster-889ws.dynamic2.redhatworkshops.io"
quickcourse_deployment_ocp: true
quickcourse_git_repo: "https://github.com/RedHatQuickCourses/aap-on-openshift.git"
```

### Using vars_files in Playbook
Both formats work with `vars_files`:

```yaml
---
- name: Deploy Quick Course
  hosts: localhost
  vars_files:
    - /path/to/variables.json   # JSON format
    # OR
    - /path/to/variables.yml    # YAML format
  
  tasks:
    - include_role:
        name: pert.quickcourse.quickcourse_deployment
```

## Auto-Collection Feature

The collection automatically collects all variables passed via:
- Command-line `-e` flags
- `vars_files` directive
- Playbook `vars` section

Variables are then automatically injected into the Quick Course content as Asciidoc attributes.

### Excluded Variables

The following Ansible internal variables are automatically excluded:
- `ansible_*` - All Ansible facts and magic variables
- `quickcourse_*` - Collection internal variables
- `hostvars`, `groups`, `group_names`
- `inventory_*`, `playbook_*`
- `play_hosts`, `play_batch`, `ansible_play_hosts`, `ansible_play_batch`
- `vars`, `environment`
- `omit`, `item`, `role_*`

## Collection Location

All fixes are in: `/home/amrsingh/pert/quickcourse/`

## Build and Install

```bash
cd /home/amrsingh/pert
ansible-galaxy collection build quickcourse --force
ansible-galaxy collection install pert-quickcourse-1.0.0.tar.gz --force
```

## Deployment Verification

All tests performed on:
- **Cluster**: cluster-889ws.dynamic2.redhatworkshops.io
- **Namespace**: quickcourse-889ws-1
- **Pod Name**: quickcourse
- **Pod Status**: Running (1/1)
- **Build Status**: Successful
- **Variable Formats**: JSON ✅ | YAML ✅

## Final Status

🎉 **Collection is production-ready** with full support for both JSON and YAML variable formats!
