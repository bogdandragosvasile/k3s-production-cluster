#!/bin/bash
set -euo pipefail

# K3s Production Cluster - Backend Configuration Generator
# Generates terraform backend configuration at runtime from environment variables

echo "🔧 Generating Terraform backend configuration..."

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# Default values
BACKEND_TYPE="${BACKEND_TYPE:-local}"
BACKEND_FILE="terraform/backend.tf"

# Function to generate local backend
generate_local_backend() {
    local path="${BACKEND_LOCAL_PATH:-/var/lib/libvirt/terraform/k3s-production-cluster/terraform.tfstate}"
    cat > "$BACKEND_FILE" << BACKEND_EOF
# K3s Production Cluster - Local Backend Configuration
# Generated at $(date)

terraform {
  backend "local" {
    path = "$path"
  }
}
BACKEND_EOF
    echo -e "${GREEN}✅ Generated local backend configuration${NC}"
}

# Function to generate S3 backend
generate_s3_backend() {
    local bucket="${BACKEND_S3_BUCKET}"
    local key="${BACKEND_S3_KEY:-k3s-production-cluster/terraform.tfstate}"
    local region="${BACKEND_S3_REGION:-us-west-2}"
    local endpoint="${BACKEND_S3_ENDPOINT:-}"
    local skip_creds="${BACKEND_S3_SKIP_CREDENTIALS_VALIDATION:-false}"
    local skip_metadata="${BACKEND_S3_SKIP_METADATA_API_CHECK:-false}"
    local force_path_style="${BACKEND_S3_FORCE_PATH_STYLE:-false}"
    
    if [[ -z "$bucket" ]]; then
        echo -e "${RED}❌ BACKEND_S3_BUCKET is required for S3 backend${NC}"
        exit 1
    fi
    
    cat > "$BACKEND_FILE" << BACKEND_EOF
# K3s Production Cluster - S3 Backend Configuration
# Generated at $(date)

terraform {
  backend "s3" {
    bucket = "$bucket"
    key    = "$key"
    region = "$region"
BACKEND_EOF

    if [[ -n "$endpoint" ]]; then
        echo "    endpoint = \"$endpoint\"" >> "$BACKEND_FILE"
    fi
    
    if [[ "$skip_creds" == "true" ]]; then
        echo "    skip_credentials_validation = true" >> "$BACKEND_FILE"
    fi
    
    if [[ "$skip_metadata" == "true" ]]; then
        echo "    skip_metadata_api_check = true" >> "$BACKEND_FILE"
    fi
    
    if [[ "$force_path_style" == "true" ]]; then
        echo "    force_path_style = true" >> "$BACKEND_FILE"
    fi
    
    cat >> "$BACKEND_FILE" << BACKEND_EOF
  }
}
BACKEND_EOF
    echo -e "${GREEN}✅ Generated S3 backend configuration${NC}"
}

# Function to generate Azure backend
generate_azurerm_backend() {
    local resource_group="${BACKEND_AZURERM_RESOURCE_GROUP_NAME}"
    local storage_account="${BACKEND_AZURERM_STORAGE_ACCOUNT_NAME}"
    local container="${BACKEND_AZURERM_CONTAINER_NAME}"
    local key="${BACKEND_AZURERM_KEY:-k3s-production-cluster/terraform.tfstate}"
    
    if [[ -z "$resource_group" || -z "$storage_account" || -z "$container" ]]; then
        echo -e "${RED}❌ Azure backend requires BACKEND_AZURERM_RESOURCE_GROUP_NAME, BACKEND_AZURERM_STORAGE_ACCOUNT_NAME, and BACKEND_AZURERM_CONTAINER_NAME${NC}"
        exit 1
    fi
    
    cat > "$BACKEND_FILE" << BACKEND_EOF
# K3s Production Cluster - Azure Backend Configuration
# Generated at $(date)

terraform {
  backend "azurerm" {
    resource_group_name  = "$resource_group"
    storage_account_name = "$storage_account"
    container_name       = "$container"
    key                  = "$key"
  }
}
BACKEND_EOF
    echo -e "${GREEN}✅ Generated Azure backend configuration${NC}"
}

# Function to generate GCS backend
generate_gcs_backend() {
    local bucket="${BACKEND_GCS_BUCKET}"
    local prefix="${BACKEND_GCS_PREFIX:-k3s-production-cluster/}"
    
    if [[ -z "$bucket" ]]; then
        echo -e "${RED}❌ BACKEND_GCS_BUCKET is required for GCS backend${NC}"
        exit 1
    fi
    
    cat > "$BACKEND_FILE" << BACKEND_EOF
# K3s Production Cluster - GCS Backend Configuration
# Generated at $(date)

terraform {
  backend "gcs" {
    bucket = "$bucket"
    prefix = "$prefix"
  }
}
BACKEND_EOF
    echo -e "${GREEN}✅ Generated GCS backend configuration${NC}"
}

# Main logic
echo "Backend type: $BACKEND_TYPE"

case "$BACKEND_TYPE" in
    "local")
        generate_local_backend
        ;;
    "s3")
        generate_s3_backend
        ;;
    "azurerm")
        generate_azurerm_backend
        ;;
    "gcs")
        generate_gcs_backend
        ;;
    *)
        echo -e "${RED}❌ Unsupported backend type: $BACKEND_TYPE${NC}"
        echo "Supported types: local, s3, azurerm, gcs"
        exit 1
        ;;
esac

echo -e "${GREEN}✅ Backend configuration generated: $BACKEND_FILE${NC}"
echo "Backend configuration:"
cat "$BACKEND_FILE"
