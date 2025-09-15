# Jenkins CI/CD for K3s Production Cluster

This directory contains the Jenkins CI/CD setup for the K3s Production Cluster, replacing the problematic GitHub Actions workflows with a reliable Docker-based Jenkins solution.

## 🚀 Quick Start

### 1. Build and Start Jenkins

```bash
# Build the Jenkins agent image
./jenkins/scripts/manage-jenkins.sh build

# Start Jenkins services
./jenkins/scripts/manage-jenkins.sh start
```

### 2. Access Jenkins

- **URL**: http://localhost:8080
- **Initial Password**: Check container logs or run:
  ```bash
  docker exec jenkins-controller cat /var/jenkins_home/secrets/initialAdminPassword
  ```

### 3. Management Commands

```bash
# Check status
./jenkins/scripts/manage-jenkins.sh status

# View logs
./jenkins/scripts/manage-jenkins.sh logs

# Stop services
./jenkins/scripts/manage-jenkins.sh stop

# Restart services
./jenkins/scripts/manage-jenkins.sh restart

# Check health
./jenkins/scripts/manage-jenkins.sh health
```

## 🏗️ Architecture

- **Jenkins Controller**: Main Jenkins instance running in Docker
- **Jenkins Agent**: Custom agent with all required tools (Terraform, Ansible, kubectl, libvirt)
- **Docker Compose**: Orchestrates both services with proper volume mounts
- **Privileged Access**: Required for libvirt/KVM operations

## 📋 Next Steps

1. Start Jenkins with the management script
2. Complete the Jenkins setup wizard
3. Create pipeline jobs for:
   - K3s deployment
   - K3s cleanup
   - K3s scaling
4. Configure credentials for GitHub and SSH
5. Test the pipelines

## 🎯 Benefits over GitHub Actions

1. **Reliability**: No more job skipping or runner issues
2. **Control**: Full control over the execution environment
3. **Persistence**: State is maintained between runs
4. **Debugging**: Easy access to logs and debugging
5. **Cost**: No GitHub Actions minutes consumed
6. **Security**: All operations run in controlled environment
