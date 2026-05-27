#!/bin/bash

# Run script for Guestbook Monitoring Demo
# Starts minikube, deploys the monitoring stack, and provides access information

set -e

echo "=� Guestbook Monitoring Demo"
echo "============================"
echo

# Function to check if command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Function to check prerequisites
check_prerequisites() {
    echo "= Checking prerequisites..."
    
    local missing_deps=()
    
    if ! command_exists minikube; then
        missing_deps+=("minikube")
    fi
    
    if ! command_exists kubectl; then
        missing_deps+=("kubectl") 
    fi
    
    if ! command_exists pulumi; then
        missing_deps+=("pulumi")
    fi
    
    if ! command_exists npm; then
        missing_deps+=("npm/node")
    fi
    
    if [ ${#missing_deps[@]} -ne 0 ]; then
        echo "L Missing dependencies: ${missing_deps[*]}"
        echo "=� Run './setup.sh' to install dependencies"
        exit 1
    fi
    
    echo " All dependencies found"
}

# Function to start minikube
start_minikube() {
    echo
    echo "<� Setting up minikube..."
    
    if ! minikube status &>/dev/null; then
        echo "=� Starting minikube cluster..."
        minikube start --memory=4096 --cpus=2
    else
        echo " Minikube already running"
    fi
    
    # Set kubectl context
    kubectl config use-context minikube
    echo " kubectl configured for minikube"
}

# Function to start minikube tunnel
start_tunnel() {
    echo
    echo "< Setting up LoadBalancer support..."
    echo
    echo "�  IMPORTANT: You need to start minikube tunnel for LoadBalancer services!"
    echo
    echo "=� In a SEPARATE terminal, run:"
    echo "   minikube tunnel"
    echo
    echo "   Keep it running throughout the demo."
    echo
    
    read -p "= Have you started 'minikube tunnel' in another terminal? (y/N): " -n 1 -r
    echo
    
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo "L Please start 'minikube tunnel' in a separate terminal first."
        echo "=� Then run this script again."
        exit 1
    fi
    
    echo " Proceeding with tunnel assumed running..."
}

# Function to deploy with Pulumi
deploy_stack() {
    echo
    echo "=� Installing npm dependencies..."
    npm install
    
    echo
    echo "=� Deploying monitoring stack..."
    
    # Initialize Pulumi stack if needed
    if ! pulumi stack ls 2>/dev/null | grep -q "dev"; then
        echo "<� Creating Pulumi stack..."
        pulumi stack init dev
    fi
    
    # Configure for minikube
    pulumi config set isMinikube true
    
    # Deploy everything
    echo "<� Running pulumi up..."
    pulumi up --yes
}

# Function to show access information
show_access_info() {
    echo
    echo "<� Deployment Complete!"
    echo "======================="
    echo
    
    # Get service information
    echo "=� Service Status:"
    kubectl get svc -n guestbook
    kubectl get svc -n monitoring | grep grafana
    echo
    
    # Show Pulumi outputs
    echo "= Access Information:"
    pulumi stack output
    echo
    
    echo "< Quick Access (if minikube tunnel is running):"
    echo "   =� Guestbook:  Check EXTERNAL-IP from services above"
    echo "   =� Grafana:    Check EXTERNAL-IP from services above (admin/admin123)"
    echo "   = Prometheus: ClusterIP only (internal)"
    echo
    
    echo "<� Recommended - Port Forwarding (Local Dev & Demo):"
    echo "   # Option 1: Use convenience script (recommended)"
    echo "   ./port-forward.sh"
    echo "   # Option 2: Manual commands (run in separate tabs)"
    echo "   kubectl port-forward service/frontend -n guestbook 8080:80"
    echo "   kubectl port-forward svc/\$(kubectl get svc -n monitoring | grep grafana | awk '{print \$1}') -n monitoring 3000:80"
    echo
    
    echo "=� Verification Commands:"
    echo "   kubectl get pods -n guestbook"
    echo "   kubectl get pods -n monitoring"
    echo
}

# Function to wait for services
wait_for_services() {
    echo "� Waiting for services to be ready..."
    
    # Wait for guestbook pods
    kubectl wait --for=condition=ready pod -l app=guestbook -n guestbook --timeout=300s
    
    # Wait for monitoring pods
    kubectl wait --for=condition=ready pod -l app.kubernetes.io/name=grafana -n monitoring --timeout=300s
    
    echo " All services ready!"
}

# Main function
main() {
    check_prerequisites
    start_minikube
    start_tunnel
    deploy_stack
    wait_for_services
    show_access_info
    
    echo "<� Demo ready! Enjoy exploring the monitoring stack!"
}

main "$@"