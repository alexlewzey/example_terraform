# Use an official Python runtime as a parent image
FROM python:3.9-bullseye

# Install basic utilities and GnuPG for apt-key
RUN apt-get update && \
    apt-get install -y git curl unzip bash-completion software-properties-common gnupg

# Install linting and code quality tools
RUN apt-get install -y shellcheck && \
    pip install pre-commit

# Install Terraform
RUN wget -O- https://apt.releases.hashicorp.com/gpg | \
    gpg --dearmor | \
    tee /usr/share/keyrings/hashicorp-archive-keyring.gpg && \
    echo "deb [signed-by=/usr/share/keyrings/hashicorp-archive-keyring.gpg] \
    https://apt.releases.hashicorp.com $(lsb_release -cs) main" | \
    tee /etc/apt/sources.list.d/hashicorp.list && \
    apt update && \
    apt-get install terraform


# Install AWS CLI
RUN ARCH=$(uname -m) && \
    if [ "${ARCH}" = "x86_64" ]; then \
        curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"; \
    elif [ "${ARCH}" = "aarch64" ]; then \
        curl "https://awscli.amazonaws.com/awscli-exe-linux-aarch64.zip" -o "awscliv2.zip"; \
    else \
        echo "Unsupported architecture: ${ARCH}" && exit 1; \
    fi && \
    unzip awscliv2.zip && \
    ./aws/install


# Install tflint
RUN curl -s https://raw.githubusercontent.com/terraform-linters/tflint/master/install_linux.sh | bash

# Install tfsec
RUN curl -sLo tfsec https://github.com/aquasecurity/tfsec/releases/download/v0.39.21/tfsec-linux-amd64 && \
    chmod +x tfsec && \
    mv tfsec /usr/local/bin/

# Install terraform-docs
RUN curl -sLo terraform-docs.tar.gz https://github.com/terraform-docs/terraform-docs/releases/download/v0.15.0/terraform-docs-v0.15.0-linux-amd64.tar.gz && \
    tar -xzf terraform-docs.tar.gz && \
    chmod +x terraform-docs && \
    mv terraform-docs /usr/local/bin/

# Set the working directory
WORKDIR /workspace
