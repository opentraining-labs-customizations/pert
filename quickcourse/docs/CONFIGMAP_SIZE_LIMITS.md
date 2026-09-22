# ConfigMap Size Limits - Automatic Chunking

## Problem

Kubernetes ConfigMaps have a hard size limit of **1,048,576 bytes (1MB)**. When deploying QuickCourse with a large number of variables, the ConfigMap containing variables can exceed this limit and cause deployment failures:

```
ConfigMap "quickcourse-vars" is invalid: []: Too long: may not be more than 1048576 bytes
```

## Solution

The deployment playbook now **automatically splits large variable sets across multiple ConfigMaps** to avoid this limit. Each ConfigMap is limited to ~900KB to provide a safety buffer.

### How it Works

1. **Variables are collected** from:
   - Extra variables passed via command line (`-e`)
   - Custom attributes from `quickcourse_custom_attributes`
   - Variable aliases from `quickcourse_variable_aliases`
   - Auto-collected variables when `quickcourse_auto_collect_vars: true`

2. **Large variable sets are automatically split into chunks**:
   - Each chunk is ~900KB (leaving 100KB safety buffer from 1MB limit)
   - Multiple ConfigMaps are created: `quickcourse-vars-0`, `quickcourse-vars-1`, etc.
   - The init container merges all chunks before injecting variables

3. **Merged in the init container**:
   - All ConfigMap chunks are mounted to `/var/quickcourse/{chunk-number}/`
   - The init container concatenates `variables.txt` from all chunks
   - Variables are injected into `antora-playbook.yml` as a single block

### Example Output

```
TASK [Display ConfigMap Distribution] *****
========================================
ConfigMap Distribution
========================================
Total ConfigMaps: 3
Chunk sizes (bytes):
- Chunk 0: 876543 bytes
- Chunk 1: 892341 bytes
- Chunk 2: 234567 bytes
```

## Best Practices (Still Recommended)

While automatic chunking prevents the hard failure, you should still aim to reduce variable count:

### 1. **Audit Variables**
```bash
ansible-playbook deploy.yml -e "quickcourse_custom_attributes={...}" \
  --check 2>&1 | grep -A 20 "Variables injected:"
```

### 2. **Use Variable Aliases Instead of Duplication**
```yaml
# Define once, reference multiple times via aliases
quickcourse_variable_aliases:
  api_url:
    - api_endpoint
    - backend_url
    - service_endpoint

# Now only pass: -e "api_endpoint=https://example.com"
# It becomes available as api_url, api_endpoint, backend_url, service_endpoint
```

### 3. **Shorten Variable Names and Values**
```yaml
# DON'T: Long descriptive values
api_endpoint_url: "https://very-long-domain-name-with-many-subdomains.example.com/api/v1/endpoint"

# DO: Keep values concise
api_endpoint: "https://example.com/api"
```

### 4. **Remove Unnecessary Variables**
```yaml
# Only pass what QuickCourse actually needs
quickcourse_custom_attributes:
  essential_var: value
  feature_flag: true

# Not needed:
# temp_var_1, unused_setting, placeholder_data
```

## Architecture

```
┌─ Playbook
│
├─ Collect variables from multiple sources
│  └─ quickcourse_collected_vars (dict)
│
├─ Build variable lines (YAML format)
│  └─ quickcourse_var_lines (list)
│
├─ Split into chunks (900KB each)
│  └─ _var_chunks (list of lists)
│
├─ Create multiple ConfigMaps
│  ├─ quickcourse-vars-0: chunk 0
│  ├─ quickcourse-vars-1: chunk 1
│  └─ quickcourse-vars-N: chunk N
│
├─ Create Pod with volume mounts
│  ├─ /var/quickcourse/0/variables.txt
│  ├─ /var/quickcourse/1/variables.txt
│  └─ /var/quickcourse/N/variables.txt
│
└─ Init container
   ├─ Merge: cat /var/quickcourse/*/variables.txt > /tmp/vars.txt
   ├─ Inject into antora-playbook.yml
   └─ Build QuickCourse
```

## Migration from Old Approach

If you were previously hitting the 1MB limit, no action needed:

1. The chunking is **automatic**
2. Existing deployments continue to work
3. Your variable count stays the same
4. The init container handles merging transparently

## Troubleshooting

### Still hitting limits?

If you're seeing errors about merged variables exceeding limits:

1. **Check ConfigMap creation**: Verify all chunks were created
   ```bash
   kubectl get configmap -n quickcourse | grep quickcourse-vars
   ```

2. **Check pod volumes**: Verify volume mounts are correct
   ```bash
   kubectl describe pod quickcourse -n quickcourse | grep -A 10 "Mounts:"
   ```

3. **Check init container logs**: See if merge worked
   ```bash
   kubectl logs quickcourse -c builder -n quickcourse
   ```

### Variables not injected?

1. Check that at least one ConfigMap chunk exists
2. Verify init container logs show "Variables Injected"
3. Check `antora-playbook.yml` in the pod's /build directory

## Performance Impact

- **Minimal**: Creating multiple ConfigMaps adds ~100ms per extra chunk
- **Volume mounts**: Multiple mounts have negligible overhead
- **Init container**: Merge operation is fast (cat + awk)

## References

- [Kubernetes ConfigMap Size Limits](https://kubernetes.io/docs/concepts/configuration/configmap/#motivation)
- [etcd Size Limits](https://etcd.io/docs/current/dev-guide/limit/#request-size-limit)
