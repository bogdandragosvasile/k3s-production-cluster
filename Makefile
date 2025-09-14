# K3s Production Cluster - Makefile
# Provides convenient targets for common operations

.PHONY: help backend-local backend-s3 backend-azurerm backend-gcs migrate-state migrate-backup clean-backups validate-backend

# Default target
help:
	@echo "K3s Production Cluster - Available Targets"
	@echo "=========================================="
	@echo ""
	@echo "Backend Configuration:"
	@echo "  backend-local     - Configure local filesystem backend"
	@echo "  backend-s3        - Configure S3/MinIO backend"
	@echo "  backend-azurerm   - Configure Azure Blob Storage backend"
	@echo "  backend-gcs       - Configure Google Cloud Storage backend"
	@echo ""
	@echo "State Migration:"
	@echo "  migrate-state     - Migrate state to new backend (interactive)"
	@echo "  migrate-backup    - Migrate state with backup"
	@echo "  migrate-force     - Migrate state without prompts"
	@echo ""
	@echo "Utilities:"
	@echo "  validate-backend  - Validate current backend configuration"
	@echo "  clean-backups     - Clean up state backup files"
	@echo "  preflight         - Run preflight checks"
	@echo "  deploy            - Deploy cluster (local backend)"
	@echo "  deploy-s3         - Deploy cluster (S3 backend)"
	@echo "  deploy-azurerm    - Deploy cluster (Azure backend)"
	@echo "  deploy-gcs        - Deploy cluster (GCS backend)"
	@echo ""
	@echo "Environment Variables:"
	@echo "  BACKEND_TYPE                    - Backend type (local, s3, azurerm, gcs)"
	@echo "  BACKEND_LOCAL_PATH              - Local backend path"
	@echo "  BACKEND_S3_BUCKET               - S3 bucket name"
	@echo "  BACKEND_S3_KEY                  - S3 key path"
	@echo "  BACKEND_S3_REGION               - S3 region"
	@echo "  BACKEND_S3_ENDPOINT             - S3 endpoint (for MinIO)"
	@echo "  BACKEND_AZURERM_RESOURCE_GROUP_NAME  - Azure resource group"
	@echo "  BACKEND_AZURERM_STORAGE_ACCOUNT_NAME  - Azure storage account"
	@echo "  BACKEND_AZURERM_CONTAINER_NAME        - Azure container"
	@echo "  BACKEND_GCS_BUCKET              - GCS bucket name"
	@echo "  BACKEND_GCS_PREFIX              - GCS prefix"

# Backend configuration targets
backend-local:
	@echo "🔧 Configuring local filesystem backend..."
	@export BACKEND_TYPE=local && \
	export BACKEND_LOCAL_PATH=$${BACKEND_LOCAL_PATH:-/var/lib/libvirt/terraform/k3s-production-cluster/terraform.tfstate} && \
	./scripts/generate-backend.sh

backend-s3:
	@echo "🔧 Configuring S3/MinIO backend..."
	@if [ -z "$$BACKEND_S3_BUCKET" ]; then \
		echo "❌ BACKEND_S3_BUCKET is required"; \
		exit 1; \
	fi
	@export BACKEND_TYPE=s3 && \
	./scripts/generate-backend.sh

backend-azurerm:
	@echo "🔧 Configuring Azure Blob Storage backend..."
	@if [ -z "$$BACKEND_AZURERM_RESOURCE_GROUP_NAME" ] || [ -z "$$BACKEND_AZURERM_STORAGE_ACCOUNT_NAME" ] || [ -z "$$BACKEND_AZURERM_CONTAINER_NAME" ]; then \
		echo "❌ Azure backend requires BACKEND_AZURERM_RESOURCE_GROUP_NAME, BACKEND_AZURERM_STORAGE_ACCOUNT_NAME, and BACKEND_AZURERM_CONTAINER_NAME"; \
		exit 1; \
	fi
	@export BACKEND_TYPE=azurerm && \
	./scripts/generate-backend.sh

backend-gcs:
	@echo "🔧 Configuring Google Cloud Storage backend..."
	@if [ -z "$$BACKEND_GCS_BUCKET" ]; then \
		echo "❌ BACKEND_GCS_BUCKET is required"; \
		exit 1; \
	fi
	@export BACKEND_TYPE=gcs && \
	./scripts/generate-backend.sh

# State migration targets
migrate-state:
	@echo "🔄 Starting interactive state migration..."
	@./scripts/migrate-state.sh $$BACKEND_TYPE

migrate-backup:
	@echo "🔄 Starting state migration with backup..."
	@./scripts/migrate-state.sh --backup $$BACKEND_TYPE

migrate-force:
	@echo "🔄 Starting state migration (force mode)..."
	@./scripts/migrate-state.sh --force $$BACKEND_TYPE

# Utility targets
validate-backend:
	@echo "🔍 Validating backend configuration..."
	@if [ -f "terraform/backend.tf" ]; then \
		echo "Backend configuration:"; \
		cat terraform/backend.tf; \
	else \
		echo "❌ No backend configuration found"; \
		exit 1; \
	fi

clean-backups:
	@echo "🧹 Cleaning up state backup files..."
	@if [ -d "terraform-state-backups" ]; then \
		rm -rf terraform-state-backups; \
		echo "✅ Backup files cleaned up"; \
	else \
		echo "ℹ️  No backup files found"; \
	fi

preflight:
	@echo "🔍 Running preflight checks..."
	@./scripts/preflight-checks.sh

# Deployment targets
deploy:
	@echo "🚀 Deploying cluster with local backend..."
	@export BACKEND_TYPE=local && \
	gh workflow run deploy-hardened.yml

deploy-s3:
	@echo "🚀 Deploying cluster with S3 backend..."
	@if [ -z "$$BACKEND_S3_BUCKET" ]; then \
		echo "❌ BACKEND_S3_BUCKET is required"; \
		exit 1; \
	fi
	@export BACKEND_TYPE=s3 && \
	gh workflow run deploy-hardened.yml

deploy-azurerm:
	@echo "🚀 Deploying cluster with Azure backend..."
	@if [ -z "$$BACKEND_AZURERM_RESOURCE_GROUP_NAME" ] || [ -z "$$BACKEND_AZURERM_STORAGE_ACCOUNT_NAME" ] || [ -z "$$BACKEND_AZURERM_CONTAINER_NAME" ]; then \
		echo "❌ Azure backend requires BACKEND_AZURERM_RESOURCE_GROUP_NAME, BACKEND_AZURERM_STORAGE_ACCOUNT_NAME, and BACKEND_AZURERM_CONTAINER_NAME"; \
		exit 1; \
	fi
	@export BACKEND_TYPE=azurerm && \
	gh workflow run deploy-hardened.yml

deploy-gcs:
	@echo "🚀 Deploying cluster with GCS backend..."
	@if [ -z "$$BACKEND_GCS_BUCKET" ]; then \
		echo "❌ BACKEND_GCS_BUCKET is required"; \
		exit 1; \
	fi
	@export BACKEND_TYPE=gcs && \
	gh workflow run deploy-hardened.yml

# Examples
examples:
	@echo "📚 Backend Configuration Examples"
	@echo "================================="
	@echo ""
	@echo "Local Backend:"
	@echo "  make backend-local"
	@echo "  BACKEND_LOCAL_PATH=/custom/path make backend-local"
	@echo ""
	@echo "S3 Backend:"
	@echo "  BACKEND_S3_BUCKET=my-terraform-state make backend-s3"
	@echo "  BACKEND_S3_BUCKET=my-bucket BACKEND_S3_KEY=prod/terraform.tfstate make backend-s3"
	@echo ""
	@echo "MinIO Backend:"
	@echo "  BACKEND_S3_BUCKET=terraform BACKEND_S3_ENDPOINT=https://minio.example.com make backend-s3"
	@echo ""
	@echo "Azure Backend:"
	@echo "  BACKEND_AZURERM_RESOURCE_GROUP_NAME=terraform-rg \\"
	@echo "  BACKEND_AZURERM_STORAGE_ACCOUNT_NAME=terraformstorage \\"
	@echo "  BACKEND_AZURERM_CONTAINER_NAME=tfstate \\"
	@echo "  make backend-azurerm"
	@echo ""
	@echo "GCS Backend:"
	@echo "  BACKEND_GCS_BUCKET=my-terraform-state make backend-gcs"
	@echo "  BACKEND_GCS_BUCKET=my-bucket BACKEND_GCS_PREFIX=prod/ make backend-gcs"
	@echo ""
	@echo "State Migration:"
	@echo "  BACKEND_TYPE=s3 make migrate-state"
	@echo "  BACKEND_TYPE=azurerm make migrate-backup"
	@echo "  BACKEND_TYPE=gcs make migrate-force"
