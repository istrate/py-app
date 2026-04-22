#!/bin/bash

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Function to print colored messages
print_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Check if user is logged into OpenShift cluster
print_info "Checking OpenShift cluster login status..."
if ! oc whoami &> /dev/null; then
    print_error "You are not logged into an OpenShift cluster."
    print_error "Please login using: oc login <cluster-url>"
    exit 1
fi

CURRENT_USER=$(oc whoami)
CURRENT_SERVER=$(oc whoami --show-server)
print_info "Logged in as: ${CURRENT_USER}"
print_info "Cluster: ${CURRENT_SERVER}"

# Check if PVC "image-registry-storage" exists
print_info "Checking for PVC 'image-registry-storage' in openshift-image-registry namespace..."
if oc get pvc image-registry-storage -n openshift-image-registry &> /dev/null; then
    print_info "PVC 'image-registry-storage' already exists."
else
    print_warning "PVC 'image-registry-storage' does not exist."

    # Check if OCP_RWM_STORAGE environment variable is set
    if [ -z "${OCP_RWM_STORAGE}" ]; then
        print_warning "Environment variable OCP_RWM_STORAGE is not set."
        echo -n "Please provide a ReadWriteMany (RWM) storage class name: "
        read STORAGE_CLASS

        if [ -z "${STORAGE_CLASS}" ]; then
            print_error "No storage class provided. Exiting."
            exit 1
        fi
    else
        STORAGE_CLASS="${OCP_RWM_STORAGE}"
        print_info "Using storage class from OCP_RWM_STORAGE: ${STORAGE_CLASS}"
    fi

    # Verify storage class exists
    if ! oc get storageclass "${STORAGE_CLASS}" &> /dev/null; then
        print_error "Storage class '${STORAGE_CLASS}' does not exist."
        exit 1
    fi

    # Create PVC
    print_info "Creating PVC 'image-registry-storage' with storage class '${STORAGE_CLASS}'..."
    cat <<EOF | oc apply -f -
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: image-registry-storage
  namespace: openshift-image-registry
spec:
  accessModes:
    - ReadWriteMany
  resources:
    requests:
      storage: 100Gi
  storageClassName: ${STORAGE_CLASS}
EOF

    if [ $? -eq 0 ]; then
        print_info "PVC 'image-registry-storage' created successfully."
    else
        print_error "Failed to create PVC."
        exit 1
    fi
fi

# Get current Registry CR configuration
print_info "Checking current image registry configuration..."
CURRENT_MGMT_STATE=$(oc get configs.imageregistry.operator.openshift.io/cluster -n openshift-image-registry -o jsonpath='{.spec.managementState}')
CURRENT_STORAGE=$(oc get configs.imageregistry.operator.openshift.io/cluster -n openshift-image-registry -o jsonpath='{.spec.storage}')

print_info "Current managementState: ${CURRENT_MGMT_STATE}"
print_info "Current storage config: ${CURRENT_STORAGE}"

# Prepare patch for managementState
NEEDS_MGMT_UPDATE=false
if [ "${CURRENT_MGMT_STATE}" == "Removed" ]; then
    print_info "Updating managementState from 'Removed' to 'Managed'..."
    NEEDS_MGMT_UPDATE=true
elif [ "${CURRENT_MGMT_STATE}" == "Managed" ]; then
    print_info "managementState is already 'Managed'. No change needed."
else
    print_warning "managementState is '${CURRENT_MGMT_STATE}'. Setting to 'Managed'..."
    NEEDS_MGMT_UPDATE=true
fi

# Prepare patch for storage
NEEDS_STORAGE_UPDATE=false
if [ "${CURRENT_STORAGE}" == "{}" ] || [ -z "${CURRENT_STORAGE}" ]; then
    print_info "Storage is empty. Configuring to use PVC 'image-registry-storage'..."
    NEEDS_STORAGE_UPDATE=true
else
    print_info "Storage is already configured. No change needed."
fi

# Apply patches if needed
if [ "${NEEDS_MGMT_UPDATE}" == "true" ] || [ "${NEEDS_STORAGE_UPDATE}" == "true" ]; then
    print_info "Applying configuration changes to image registry..."

    # Build the patch JSON
    PATCH_JSON='{"spec":{'

    if [ "${NEEDS_MGMT_UPDATE}" == "true" ]; then
        PATCH_JSON+='"managementState":"Managed"'
    fi

    if [ "${NEEDS_STORAGE_UPDATE}" == "true" ]; then
        if [ "${NEEDS_MGMT_UPDATE}" == "true" ]; then
            PATCH_JSON+=','
        fi
        PATCH_JSON+='"storage":{"pvc":{"claim":"image-registry-storage"}}'
    fi

    PATCH_JSON+='}}'

    print_info "Applying patch: ${PATCH_JSON}"

    if oc patch configs.imageregistry.operator.openshift.io/cluster -n openshift-image-registry \
        --type=merge --patch "${PATCH_JSON}"; then
        print_info "Configuration applied successfully."
    else
        print_error "Failed to apply configuration."
        exit 1
    fi

    # Wait for the image registry to become available
    print_info "Waiting for image registry to become available..."
    TIMEOUT=300
    ELAPSED=0
    INTERVAL=10

    while [ ${ELAPSED} -lt ${TIMEOUT} ]; do
        AVAILABLE=$(oc get configs.imageregistry.operator.openshift.io/cluster -n openshift-image-registry -o jsonpath='{.status.conditions[?(@.type=="Available")].status}')

        if [ "${AVAILABLE}" == "True" ]; then
            print_info "Image registry is now available!"
            break
        fi

        echo -n "."
        sleep ${INTERVAL}
        ELAPSED=$((ELAPSED + INTERVAL))
    done
    echo ""

    if [ ${ELAPSED} -ge ${TIMEOUT} ]; then
        print_warning "Timeout waiting for image registry to become available."
        print_warning "You may need to check the registry operator logs."
    fi
else
    print_info "No configuration changes needed."
fi

# Enable external route
print_info "Enabling external route for image registry..."
if oc -n openshift-image-registry patch configs.imageregistry.operator.openshift.io/cluster \
    --patch '{"spec":{"defaultRoute":true}}' --type=merge; then
    print_info "External route enabled successfully."

    # Wait a moment for route to be created
    sleep 5

    # Get the route
    REGISTRY_ROUTE=$(oc get route default-route -n openshift-image-registry -o jsonpath='{.spec.host}' 2>/dev/null || echo "")

    if [ -n "${REGISTRY_ROUTE}" ]; then
        print_info "Image registry is accessible at: ${REGISTRY_ROUTE}"
        print_info "You can now push images using: podman login ${REGISTRY_ROUTE}"
    else
        print_warning "Route is being created. Check with: oc get route -n openshift-image-registry"
    fi
else
    print_error "Failed to enable external route."
    exit 1
fi

print_info "OpenShift image registry configuration completed successfully!"

# Made with Bob
