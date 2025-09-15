# Simple Jenkins Agent for K3s Production Cluster
FROM ubuntu:24.04

# Set environment variables
ENV DEBIAN_FRONTEND=noninteractive

# Install basic tools
RUN apt-get update && apt-get install -y \
    curl \
    wget \
    git \
    vim \
    htop \
    net-tools \
    dnsutils \
    jq \
    unzip \
    openssh-client \
    openjdk-17-jdk \
    ansible \
    tree \
    rsync \
    && rm -rf /var/lib/apt/lists/*

# Install Terraform
RUN wget https://releases.hashicorp.com/terraform/1.6.0/terraform_1.6.0_linux_amd64.zip \
    && unzip terraform_1.6.0_linux_amd64.zip \
    && mv terraform /usr/local/bin/ \
    && rm terraform_1.6.0_linux_amd64.zip

# Install kubectl
RUN curl -LO "https://dl.k8s.io/release/v1.33.4/bin/linux/amd64/kubectl" \
    && chmod +x kubectl \
    && mv kubectl /usr/local/bin/

# Create jenkins user
RUN useradd -m -s /bin/bash jenkins

# Create working directories
RUN mkdir -p /home/jenkins/workspace \
    && mkdir -p /home/jenkins/.ssh \
    && mkdir -p /home/jenkins/.kube \
    && mkdir -p /home/jenkins/scripts \
    && chown -R jenkins:jenkins /home/jenkins

# Set working directory
WORKDIR /home/jenkins/workspace

# Switch to jenkins user
USER jenkins

# Expose port for Jenkins agent
EXPOSE 50000

# Default command
CMD ["/bin/bash"]
