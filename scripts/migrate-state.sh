#!/bin/bash
set -euo pipefail

# K3s Production Cluster - State Migration Script
# Safely migrates Terraform state between backends with backups and prompts

echo "🔄 Terraform State Migration Tool"
echo "================================="

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
BACKUP_DIR="./terraform-state-backups"
TIMESTAMP=$(date +%Y%m%d-%H%M%S)
BACKUP_FILE="$BACKUP_DIR/terraform.tfstate.backup-$TIMESTAMP"

# Function to create backup
create_backup() {
    echo -e "${BLUE}📦 Creating state backup...${NC}"
    mkdir -p "$BACKUP_DIR"
    
    if [[ -f "terraform/terraform.tfstate" ]]; then
        cp "terraform/terraform.tfstate" "$BACKUP_FILE"
        echo -e "${GREEN}✅ State backed up to: $BACKUP_FILE${NC}"
    else
        echo -e "${YELLOW}⚠️  No existing state file found${NC}"
    fi
}

# Function to show current state info
show_state_info() {
    echo -e "${BLUE}📊 Current State Information:${NC}"
    if [[ -f "terraform/terraform.tfstate" ]]; then
        echo "State file size: $(du -h terraform/terraform.tfstate | cut -f1)"
        echo "Last modified: $(stat -c %y terraform/terraform.tfstate)"
        echo "Resources in state: $(grep -c '"type":' terraform/terraform.tfstate || echo "0")"
    else
        echo "No state file found"
    fi
}

# Function to validate backend configuration
validate_backend() {
    local backend_type="$1"
    echo -e "${BLUE}🔍 Validating $backend_type backend configuration...${NC}"
    
    case "$backend_type" in
        "local")
            if [[ -z "${BACKEND_LOCAL_PATH:-}" ]]; then
                echo -e "${RED}❌ BACKEND_LOCAL_PATH is required for local backend${NC}"
                exit 1
            fi
            echo -e "${GREEN}✅ Local backend path: $BACKEND_LOCAL_PATH${NC}"
            ;;
        "s3")
            if [[ -z "${BACKEND_S3_BUCKET:-}" ]]; then
                echo -e "${RED}❌ BACKEND_S3_BUCKET is required for S3 backend${NC}"
                exit 1
            fi
            echo -e "${GREEN}✅ S3 bucket: $BACKEND_S3_BUCKET${NC}"
            echo -e "${GREEN}✅ S3 key: ${BACKEND_S3_KEY:-k3s-production-cluster/terraform.tfstate}${NC}"
            ;;
        "azurerm")
            if [[ -z "${BACKEND_AZURERM_RESOURCE_GROUP_NAME:-}" || -z "${BACKEND_AZURERM_STORAGE_ACCOUNT_NAME:-}" || -z "${BACKEND_AZURERM_CONTAINER_NAME:-}" ]]; then
                echo -e "${RED}❌ Azure backend requires resource group, storage account, and container name${NC}"
                exit 1
            fi
            echo -e "${GREEN}✅ Azure resource group: $BACKEND_AZURERM_RESOURCE_GROUP_NAME${NC}"
            echo -e "${GREEN}✅ Azure storage account: $BACKEND_AZURERM_STORAGE_ACCOUNT_NAME${NC}"
            echo -e "${GREEN}✅ Azure container: $BACKEND_AZURERM_CONTAINER_NAME${NC}"
            ;;
        "gcs")
            if [[ -z "${BACKEND_GCS_BUCKET:-}" ]]; then
                echo -e "${RED}❌ BACKEND_GCS_BUCKET is required for GCS backend${NC}"
                exit 1
            fi
            echo -e "${GREEN}✅ GCS bucket: $BACKEND_GCS_BUCKET${NC}"
            echo -e "${GREEN}✅ GCS prefix: ${BACKEND_GCS_PREFIX:-k3s-production-cluster/}${NC}"
            ;;
        *)
            echo -e "${RED}❌ Unsupported backend type: $backend_type${NC}"
            exit 1
            ;;
    esac
}

# Function to perform migration
migrate_state() {
    local backend_type="$1"
    echo -e "${BLUE}🚀 Starting state migration to $backend_type backend...${NC}"
    
    # Generate backend configuration
    ./scripts/generate-backend.sh
    
    # Change to terraform directory
    cd terraform
    
    # Initialize with migration
    echo -e "${BLUE}🔧 Running terraform init -migrate-state...${NC}"
    if terraform init -migrate-state; then
        echo -e "${GREEN}✅ State migration completed successfully${NC}"
    else
        echo -e "${RED}❌ State migration failed${NC}"
        echo -e "${YELLOW}💡 You may need to manually resolve conflicts or restore from backup${NC}"
        echo -e "${YELLOW}💡 Backup available at: $BACKUP_FILE${NC}"
        exit 1
    fi
    
    # Verify migration
    echo -e "${BLUE}🔍 Verifying migration...${NC}"
    if terraform plan -detailed-exitcode >/dev/null 2>&1; then
        echo -e "${GREEN}✅ Migration verified - no changes detected${NC}"
    else
        echo -e "${YELLOW}⚠️  Migration completed but plan shows changes - this may be normal${NC}"
    fi
    
    cd ..
}

# Function to show help
show_help() {
    echo "Usage: $0 [OPTIONS] BACKEND_TYPE"
    echo ""
    echo "Migrate Terraform state to a new backend"
    echo ""
    echo "BACKEND_TYPE:"
    echo "  local    - Local filesystem backend"
    echo "  s3       - AWS S3 or MinIO backend"
    echo "  azurerm  - Azure Blob Storage backend"
    echo "  gcs      - Google Cloud Storage backend"
    echo ""
    echo "OPTIONS:"
    echo "  -h, --help     Show this help message"
    echo "  -f, --force    Skip confirmation prompts"
    echo "  -b, --backup   Create backup before migration"
    echo "  -v, --verbose  Enable verbose output"
    echo ""
    echo "Environment Variables:"
    echo "  BACKEND_TYPE                    - Backend type (required)"
    echo "  BACKEND_LOCAL_PATH              - Local backend path"
    echo "  BACKEND_S3_BUCKET               - S3 bucket name"
    echo "  BACKEND_S3_KEY                  - S3 key path"
    echo "  BACKEND_S3_REGION               - S3 region"
    echo "  BACKEND_S3_ENDPOINT             - S3 endpoint (for MinIO)"
    echo "  BACKEND_AZURERM_RESOURCE_GROUP_NAME  - Azure resource group"
    echo "  BACKEND_AZURERM_STORAGE_ACCOUNT_NAME  - Azure storage account"
    echo "  BACKEND_AZURERM_CONTAINER_NAME        - Azure container"
    echo "  BACKEND_GCS_BUCKET              - GCS bucket name"
    echo "  BACKEND_GCS_PREFIX              - GCS prefix"
    echo ""
    echo "Examples:"
    echo "  $0 local"
    echo "  BACKEND_TYPE=s3 BACKEND_S3_BUCKET=my-bucket $0 s3"
    echo "  $0 --backup --force azurerm"
}

# Parse command line arguments
FORCE=false
BACKUP=false
VERBOSE=false
BACKEND_TYPE=""

while [[ $# -gt 0 ]]; do
    case $1 in
        -h|--help)
            show_help
            exit 0
            ;;
        -f|--force)
            FORCE=true
            shift
            ;;
        -b|--backup)
            BACKUP=true
            shift
            ;;
        -v|--verbose)
            VERBOSE=true
            shift
            ;;
        local|s3|azurerm|gcs)
            BACKEND_TYPE="$1"
            shift
            ;;
        *)
            echo -e "${RED}❌ Unknown option: $1${NC}"
            show_help
            exit 1
            ;;
    esac
done

# Check if backend type is provided
if [[ -z "$BACKEND_TYPE" ]]; then
    echo -e "${RED}❌ Backend type is required${NC}"
    show_help
    exit 1
fi

# Set verbose mode
if [[ "$VERBOSE" == "true" ]]; then
    set -x
fi

# Main execution
echo -e "${BLUE}🎯 Target backend: $BACKEND_TYPE${NC}"

# Show current state info
show_state_info

# Create backup if requested
if [[ "$BACKUP" == "true" ]]; then
    create_backup
fi

# Validate backend configuration
validate_backend "$BACKEND_TYPE"

# Confirmation prompt
if [[ "$FORCE" != "true" ]]; then
    echo ""
    echo -e "${YELLOW}⚠️  WARNING: This will migrate your Terraform state to a new backend${NC}"
    echo -e "${YELLOW}⚠️  Make sure you have a backup and understand the implications${NC}"
    echo ""
    read -p "Are you sure you want to continue? (yes/no): " -r
    if [[ ! $REPLY =~ ^[Yy][Ee][Ss]$ ]]; then
        echo -e "${YELLOW}❌ Migration cancelled${NC}"
        exit 0
    fi
fi

# Perform migration
migrate_state "$BACKEND_TYPE"

echo -e "${GREEN}🎉 State migration completed successfully!${NC}"
echo -e "${BLUE}💡 Next steps:${NC}"
echo "  1. Verify your infrastructure with: terraform plan"
echo "  2. Test a small change to ensure the backend is working"
echo "  3. Update your CI/CD pipeline with the new backend configuration"
if [[ "$BACKUP" == "true" ]]; then
    echo "  4. Keep the backup file safe: $BACKUP_FILE"
fi
