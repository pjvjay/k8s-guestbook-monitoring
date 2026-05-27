#!/bin/bash

# Setup script for Guestbook Monitoring Demo
# Installs required dependencies for minikube deployment

set -e

echo "🚀 Guestbook Monitoring Setup"
echo "============================="

# Function to check if command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

echo -e "${BLUE}🔍 Checking prerequisites...${NC}"

# Check for Homebrew on macOS
if [[ "$OSTYPE" == "darwin"* ]]; then
    if ! command_exists brew; then
        echo -e "${YELLOW}📦 Installing Homebrew...${NC}"
        /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
    else
        echo -e "${GREEN}✅ Homebrew found${NC}"
    fi
fi

# Check Docker
if ! command_exists docker; then
    echo -e "${YELLOW}❌ Docker not found. Please install Docker Desktop first:${NC}"
    if [[ "$OSTYPE" == "darwin"* ]]; then
        echo "   brew install --cask docker"
    else
        echo "   https://docs.docker.com/get-docker/"
    fi
    exit 1
else
    echo -e "${GREEN}✅ Docker found${NC}"
fi

# Check if Docker is running
if ! docker ps >/dev/null 2>&1; then
    echo -e "${YELLOW}⚠️  Docker daemon not running. Please start Docker Desktop.${NC}"
    exit 1
else
    echo -e "${GREEN}✅ Docker running${NC}"
fi

echo -e "${BLUE}📦 Installing tools...${NC}"

# Install kubectl
if ! command_exists kubectl; then
    echo -e "${YELLOW}🔧 Installing kubectl...${NC}"
    if [[ "$OSTYPE" == "darwin"* ]]; then
        brew install kubectl
    else
        curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
        chmod +x kubectl
        sudo mv kubectl /usr/local/bin/
    fi
else
    echo -e "${GREEN}✅ kubectl found${NC}"
fi

# Install minikube
if ! command_exists minikube; then
    echo -e "${YELLOW}🎡 Installing minikube...${NC}"
    if [[ "$OSTYPE" == "darwin"* ]]; then
        brew install minikube
    else
        curl -LO https://storage.googleapis.com/minikube/releases/latest/minikube-linux-amd64
        sudo install minikube-linux-amd64 /usr/local/bin/minikube
        rm minikube-linux-amd64
    fi
else
    echo -e "${GREEN}✅ minikube found${NC}"
fi

# Install Pulumi
if ! command_exists pulumi; then
    echo -e "${YELLOW}⚡ Installing Pulumi...${NC}"
    if [[ "$OSTYPE" == "darwin"* ]]; then
        brew install pulumi
    else
        curl -fsSL https://get.pulumi.com | sh
        export PATH=$PATH:$HOME/.pulumi/bin
    fi
else
    echo -e "${GREEN}✅ Pulumi found${NC}"
fi

# Install Node.js (for Pulumi TypeScript)
if ! command_exists node; then
    echo -e "${YELLOW}📦 Installing Node.js...${NC}"
    if [[ "$OSTYPE" == "darwin"* ]]; then
        brew install node
    else
        curl -fsSL https://deb.nodesource.com/setup_lts.x | sudo -E bash -
        sudo apt-get install -y nodejs
    fi
else
    echo -e "${GREEN}✅ Node.js found ($(node --version))${NC}"
fi

# Install npm packages
if [ -f "package.json" ]; then
    echo -e "${YELLOW}📦 Installing npm dependencies...${NC}"
    npm install
else
    echo -e "${YELLOW}📦 Initializing npm project...${NC}"
    npm init -y
    npm install @pulumi/pulumi @pulumi/kubernetes
fi

echo -e "${BLUE}🎡 Setting up minikube...${NC}"

# Start minikube if not running
if ! minikube status >/dev/null 2>&1; then
    echo -e "${YELLOW}🚀 Starting minikube cluster...${NC}"
    minikube start --driver=docker --memory=4096 --cpus=2
    
    # Enable ingress addon (useful for services)
    minikube addons enable ingress
else
    echo -e "${GREEN}✅ minikube cluster running${NC}"
fi

echo -e "${BLUE}⚙️  Configuring environment...${NC}"

# Set up kubectl context
kubectl config use-context minikube

# Check if required environment variables are set
if [ -z "$PULUMI_ACCESS_TOKEN" ]; then
    echo -e "${YELLOW}⚠️  PULUMI_ACCESS_TOKEN not set. Please set your Pulumi access token:${NC}"
    echo -e "   export PULUMI_ACCESS_TOKEN=your-pulumi-token"
    echo -e "   Or get one from: https://app.pulumi.com/account/tokens"
    exit 1
fi

# Create or update environment file (only if variables are set)
if [ -n "$ANTHROPIC_API_KEY" ] && [ -n "$PULUMI_ACCESS_TOKEN" ]; then
    cat > .env << EOF
ANTHROPIC_API_KEY=${ANTHROPIC_API_KEY}
PULUMI_ACCESS_TOKEN=${PULUMI_ACCESS_TOKEN}
EOF
    echo -e "${GREEN}✅ Environment file created${NC}"
fi

echo -e "${GREEN}✅ Environment configured${NC}"

echo -e "${BLUE}🔧 Setting up Pulumi project...${NC}"

# Initialize Pulumi project if not exists
if [ ! -f "Pulumi.yaml" ]; then
    echo -e "${YELLOW}🎯 Creating Pulumi project...${NC}"
    pulumi new kubernetes-typescript --force --yes --name sre-guestbook-monitoring --description "SRE Guestbook with Prometheus and Grafana monitoring"
fi

# Set Pulumi config for local development
pulumi config set useLoadBalancer false  # Use ClusterIP for local minikube
pulumi config set kubernetes:context minikube

echo ""
echo -e "${GREEN}🎉 Setup Complete!${NC}"
echo -e "${BLUE}================================${NC}"
echo -e "🎯 Tools installed:"
echo -e "  • kubectl: ${GREEN}$(kubectl version --client --short)${NC}"
echo -e "  • minikube: ${GREEN}$(minikube version --short)${NC}"
echo -e "  • Pulumi: ${GREEN}$(pulumi version)${NC}"
echo -e "  • Node.js: ${GREEN}$(node --version)${NC}"
echo ""
echo -e "${BLUE}🚀 Quick Start:${NC}"
echo -e "  1. Deploy: ${YELLOW}pulumi up${NC}"
echo -e "  2. Access services: ${YELLOW}./access-services.sh${NC}"
echo -e "  3. Clean up: ${YELLOW}pulumi destroy && minikube delete${NC}"
echo ""
echo -e "${BLUE}📊 Cluster Info:${NC}"
echo -e "  • Context: ${GREEN}$(kubectl config current-context)${NC}"
echo -e "  • Nodes: ${GREEN}$(kubectl get nodes --no-headers | wc -l) ready${NC}"
echo ""
echo -e "${GREEN}Ready to deploy your SRE monitoring stack! 🎯${NC}"