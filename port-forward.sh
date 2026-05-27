#!/bin/bash

# Port Forward Script for Guestbook Monitoring Demo
# Starts port forwards for all services in background

echo "=€ Starting Port Forwards for Demo..."

# Function to start port forward in background
start_port_forward() {
    local service=$1
    local namespace=$2
    local local_port=$3
    local remote_port=$4
    local name=$5
    
    echo "= Starting $name ’ http://localhost:$local_port"
    kubectl port-forward "$service" -n "$namespace" "$local_port:$remote_port" > /dev/null 2>&1 &
    local pid=$!
    echo "   PID: $pid"
    return $pid
}

# Start port forwards
echo
echo "=á Starting services..."

# Guestbook
start_port_forward "service/frontend" "guestbook" "8080" "80" "Guestbook"

# Grafana (dynamic service name)
GRAFANA_SVC=$(kubectl get svc -n monitoring | grep grafana | awk '{print $1}' | head -1)
if [[ -n "$GRAFANA_SVC" ]]; then
    start_port_forward "svc/$GRAFANA_SVC" "monitoring" "3000" "80" "Grafana"
else
    echo "L Grafana service not found"
fi

# Optional: Prometheus (for advanced users)
if [[ "$1" == "--with-prometheus" ]]; then
    PROMETHEUS_SVC=$(kubectl get svc -n monitoring | grep prometheus | grep -v "node-exporter" | awk '{print $1}' | head -1)
    if [[ -n "$PROMETHEUS_SVC" ]]; then
        start_port_forward "svc/$PROMETHEUS_SVC" "monitoring" "9090" "9090" "Prometheus"
    fi
fi

echo
echo " Port forwards started!"
echo
echo "=Ë Access URLs:"
echo "  < Guestbook:  http://localhost:8080"
echo "  =Ê Grafana:    http://localhost:3000 (admin/admin123)"
if [[ "$1" == "--with-prometheus" ]]; then
    echo "  = Prometheus: http://localhost:9090"
fi
echo
echo "=¡ To stop all port forwards: pkill -f 'kubectl port-forward'"
echo "=Ì Keep this terminal open or run in background"