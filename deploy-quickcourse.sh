#!/bin/bash
set -e

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}QuickCourse Deployment Script v1.0.3${NC}"
echo -e "${BLUE}========================================${NC}\n"

# Function to print colored output
print_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Check if running as root (optional but recommended for some tasks)
if [ "$EUID" -eq 0 ]; then
    print_warning "Running as root - this is not required"
fi

# Parse command line arguments
CLEAR_CACHE=true
FORCE_INSTALL=true
API_URL=""
API_KEY=""
NAMESPACE="quickcourse"
GIT_REPO=""
CUSTOM_ATTRIBUTES=""
PLAYBOOK_PATH=""

# Help function
show_help() {
    cat << EOF
Usage: $0 [OPTIONS]

QuickCourse OpenShift Deployment Script

OPTIONS:
    -u, --api-url URL              OpenShift API URL (required)
    -k, --api-key TOKEN            OpenShift API token (required)
    -r, --git-repo URL             QuickCourse git repository URL (required)
    -n, --namespace NS             OpenShift namespace (default: quickcourse)
    -a, --attributes FILE          Path to custom attributes YAML file
    -p, --playbook PATH            Path to playbook file (auto-detected if not set)
    --no-cache-clear               Skip cache clearing
    --no-force-install             Don't force collection reinstall
    -h, --help                     Show this help message

EXAMPLES:
    # Interactive mode
    $0

    # With all options
    $0 -u "https://api.cluster.example.com:6443" \\
         -k "your-token" \\
         -r "https://github.com/RedHatQuickCourses/aap-on-openshift.git" \\
         -a /path/to/vars.yml

EOF
}

# Parse arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        -u|--api-url)
            API_URL="$2"
            shift 2
            ;;
        -k|--api-key)
            API_KEY="$2"
            shift 2
            ;;
        -r|--git-repo)
            GIT_REPO="$2"
            shift 2
            ;;
        -n|--namespace)
            NAMESPACE="$2"
            shift 2
            ;;
        -a|--attributes)
            CUSTOM_ATTRIBUTES="$2"
            shift 2
            ;;
        -p|--playbook)
            PLAYBOOK_PATH="$2"
            shift 2
            ;;
        --no-cache-clear)
            CLEAR_CACHE=false
            shift
            ;;
        --no-force-install)
            FORCE_INSTALL=false
            shift
            ;;
        -h|--help)
            show_help
            exit 0
            ;;
        *)
            print_error "Unknown option: $1"
            show_help
            exit 1
            ;;
    esac
done

# Interactive mode if parameters not provided
if [ -z "$API_URL" ] || [ -z "$API_KEY" ] || [ -z "$GIT_REPO" ]; then
    echo -e "${YELLOW}Enter deployment parameters:${NC}\n"

    if [ -z "$API_URL" ]; then
        read -p "OpenShift API URL (e.g., https://api.cluster.example.com:6443): " API_URL
    fi

    if [ -z "$API_KEY" ]; then
        read -sp "OpenShift API Token: " API_KEY
        echo
    fi

    if [ -z "$GIT_REPO" ]; then
        read -p "QuickCourse Git Repository URL: " GIT_REPO
    fi

    read -p "OpenShift Namespace (default: quickcourse): " NS_INPUT
    if [ -n "$NS_INPUT" ]; then
        NAMESPACE="$NS_INPUT"
    fi

    read -p "Custom attributes YAML file (leave blank to skip): " CUSTOM_ATTRIBUTES
fi

# Validate inputs
if [ -z "$API_URL" ] || [ -z "$API_KEY" ] || [ -z "$GIT_REPO" ]; then
    print_error "Missing required parameters"
    exit 1
fi

print_info "Configuration:"
echo "  API URL: $API_URL"
echo "  Namespace: $NAMESPACE"
echo "  Git Repo: $GIT_REPO"
echo "  Custom Attributes: ${CUSTOM_ATTRIBUTES:-None}"
echo ""

# Step 1: Clear collection cache
if [ "$CLEAR_CACHE" = true ]; then
    print_info "Clearing Ansible collection cache..."

    # Clear various cache locations
    for cache_dir in "/runner/requirements_collections/ansible_collections/pert" \
                     "/runner/requirements_collections/ansible_collections/pert/quickcourse" \
                     "$HOME/.ansible/collections/ansible_collections/pert" \
                     "$HOME/.ansible/collections/ansible_collections/pert/quickcourse"; do
        if [ -d "$cache_dir" ]; then
            rm -rf "$cache_dir"
            print_success "Cleared $cache_dir"
        fi
    done
fi

# Step 2: Install/Reinstall collection
print_info "Installing pert.quickcourse collection (v1.0.3)..."

if [ "$FORCE_INSTALL" = true ]; then
    ansible-galaxy collection install -f git+https://github.com/opentraining-labs-customizations/pert.git
else
    ansible-galaxy collection install git+https://github.com/opentraining-labs-customizations/pert.git
fi

if [ $? -eq 0 ]; then
    print_success "Collection installed successfully"
else
    print_error "Failed to install collection"
    exit 1
fi

# Verify installation
print_info "Verifying installation..."
INSTALLED_VERSION=$(ansible-galaxy collection list pert.quickcourse 2>/dev/null | grep "pert.quickcourse" | awk '{print $2}')

if [ -z "$INSTALLED_VERSION" ]; then
    print_warning "Could not verify version, but installation may still be successful"
else
    print_success "Installed version: $INSTALLED_VERSION"
fi

# Step 3: Find playbook
if [ -z "$PLAYBOOK_PATH" ]; then
    # Try to find the playbook
    if [ -f "./quickcourse/playbooks/deploy-quickcourse-ocp.yml" ]; then
        PLAYBOOK_PATH="./quickcourse/playbooks/deploy-quickcourse-ocp.yml"
    elif [ -f "quickcourse/playbooks/deploy-quickcourse-ocp.yml" ]; then
        PLAYBOOK_PATH="quickcourse/playbooks/deploy-quickcourse-ocp.yml"
    else
        print_error "Could not find playbook. Specify with -p/--playbook"
        exit 1
    fi
fi

if [ ! -f "$PLAYBOOK_PATH" ]; then
    print_error "Playbook not found at: $PLAYBOOK_PATH"
    exit 1
fi

print_success "Playbook found: $PLAYBOOK_PATH"

# Step 4: Build ansible-playbook command
print_info "Preparing deployment command...\n"

ANSIBLE_CMD="ansible-playbook $PLAYBOOK_PATH"
ANSIBLE_CMD="$ANSIBLE_CMD -e quickcourse_deployment_ocp=yes"
ANSIBLE_CMD="$ANSIBLE_CMD -e quickcourse_openshift_api_url='$API_URL'"
ANSIBLE_CMD="$ANSIBLE_CMD -e quickcourse_openshift_api_key='$API_KEY'"
ANSIBLE_CMD="$ANSIBLE_CMD -e quickcourse_ocp_namespace='$NAMESPACE'"
ANSIBLE_CMD="$ANSIBLE_CMD -e quickcourse_git_repo='$GIT_REPO'"

# Add custom attributes if provided
if [ -n "$CUSTOM_ATTRIBUTES" ] && [ -f "$CUSTOM_ATTRIBUTES" ]; then
    ANSIBLE_CMD="$ANSIBLE_CMD -e @'$CUSTOM_ATTRIBUTES'"
    print_info "Using custom attributes from: $CUSTOM_ATTRIBUTES"
fi

# Add verbosity
ANSIBLE_CMD="$ANSIBLE_CMD -vv"

echo -e "${YELLOW}Ready to execute deployment${NC}\n"
echo -e "${BLUE}Command:${NC}"
echo "$ANSIBLE_CMD"
echo ""

# Step 5: Confirm and execute
read -p "Proceed with deployment? (yes/no): " CONFIRM

if [ "$CONFIRM" != "yes" ] && [ "$CONFIRM" != "y" ]; then
    print_warning "Deployment cancelled"
    exit 0
fi

print_info "Starting deployment...\n"
echo -e "${BLUE}========================================${NC}\n"

# Execute the playbook
eval "$ANSIBLE_CMD"

DEPLOY_STATUS=$?

echo -e "\n${BLUE}========================================${NC}"

if [ $DEPLOY_STATUS -eq 0 ]; then
    print_success "Deployment completed successfully!"
    echo ""
    print_info "Next steps:"
    echo "  1. Check the deployment logs above"
    echo "  2. Access QuickCourse via the Route URL"
    echo "  3. Verify ConfigMaps were created:"
    echo "     kubectl get configmap -n $NAMESPACE | grep quickcourse-vars"
    echo "  4. Check pod status:"
    echo "     kubectl get pod quickcourse -n $NAMESPACE"
else
    print_error "Deployment failed with exit code $DEPLOY_STATUS"
    echo ""
    print_info "Troubleshooting:"
    echo "  1. Check the error message above"
    echo "  2. Verify OpenShift credentials"
    echo "  3. Check cluster connectivity: oc login $API_URL"
    echo "  4. Review collection installation:"
    echo "     ansible-galaxy collection list | grep pert"
    exit 1
fi
