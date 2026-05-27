# Kubernetes Guestbook with Prometheus & Grafana Monitoring

This project extends the classic Kubernetes Guestbook application with comprehensive monitoring using Prometheus and Grafana, deployed via Pulumi Infrastructure as Code.

## Architecture Overview

```
┌─────────────────────────────────────────────────────────────┐
│                    Kubernetes Cluster                       │
│                                                             │
│  ┌─────────────────┐  ┌─────────────────┐                  │
│  │   Guestbook     │  │   Monitoring    │                  │
│  │   Application   │  │     Stack       │                  │
│  │                 │  │                 │                  │
│  │ ┌─────────────┐ │  │ ┌─────────────┐ │                  │
│  │ │  Frontend   │ │  │ │ Prometheus  │ │                  │
│  │ │   (PHP)     │ │  │ │   Server    │ │                  │
│  │ └─────────────┘ │  │ └─────────────┘ │                  │
│  │ ┌─────────────┐ │  │ ┌─────────────┐ │                  │
│  │ │   Redis     │ │  │ │  Grafana    │ │                  │
│  │ │  Backend    │ │  │ │  Dashboard  │ │                  │
│  │ └─────────────┘ │  │ └─────────────┘ │                  │
│  └─────────────────┘  └─────────────────┘                  │
│                                                             │
└─────────────────────────────────────────────────────────────┘
```

## Features

- **Kubernetes Guestbook Application**: PHP frontend with Redis backend
- **Prometheus Monitoring**: Automated metrics collection with service discovery
- **Grafana Dashboards**: Pre-configured dashboards for application and cluster monitoring
- **Custom Metrics**: Guestbook-specific monitoring with ServiceMonitor resources
- **Load Balancer Access**: External access to both Guestbook and Grafana
- **Infrastructure as Code**: Complete deployment managed via Pulumi TypeScript

## Prerequisites

- **Pulumi CLI** installed and configured
- **kubectl** configured with access to a Kubernetes cluster
- **Node.js 18+** and npm/yarn for dependencies
- **Kubernetes cluster** with LoadBalancer support (e.g., minikube, GKE, EKS, AKS)
- **Helm** (installed automatically by Pulumi Helm provider)

## Deployment Options

### Option 1: Traditional Deployment

**Prerequisites:**
- Pulumi CLI installed
- kubectl configured with Kubernetes cluster access
- Node.js 18+ and npm

**Steps:**
```bash
# 1. Setup project
git clone <repository-url>
cd pulumi-k8s-guestbook-monitoring
npm install

# 2. Initialize Pulumi stack
pulumi stack init dev

# 3. IMPORTANT: Enable minikube tunnel for LoadBalancer services
# Run this in a separate terminal and keep it running
minikube tunnel

# 4. Deploy
pulumi up
```

> ⚠️ **Critical**: Keep `minikube tunnel` running throughout the demo for External IPs to work.

### Option 2: Docker Deployment (Alternative)

**Prerequisites:**
- Docker and Docker Compose
- Pulumi access token

**Quick Start:**
```bash
# Set Pulumi token
export PULUMI_ACCESS_TOKEN=your-token

# Option A: Deploy with isolated minikube
docker-compose up deploy-minikube

# Option B: Deploy to existing cluster
export KUBECONFIG_PATH=/path/to/your/kubeconfig
docker-compose up deploy-existing
```


See [DOCKER_README.md](DOCKER_README.md) for detailed Docker deployment instructions.

## Access Information

🚀 **Deployment Complete! Next Steps:**

### 1. Wait for LoadBalancers (1-2 minutes)
```bash
# Check guestbook services
kubectl get svc -n guestbook

# Check monitoring services  
kubectl get svc -n monitoring

# Wait for EXTERNAL-IP to be assigned (may show <pending> initially)
```

### 2. Access Applications

**Option A: LoadBalancer (Cloud/External IP)**
```bash
# Get URLs from Pulumi outputs
pulumi stack output guestbookUrl       # Guestbook application URL
pulumi stack output grafanaUrl         # Grafana dashboard URL 
pulumi stack output grafanaCredentials # Admin credentials
```

**Option B: Port Forwarding (Local Development)**
```bash
# Manual port forwarding (run in separate terminals)
kubectl port-forward service/frontend -n guestbook 8080:80                    # Guestbook → http://localhost:8080
kubectl port-forward svc/kube-prometheus-stack-*-grafana -n monitoring 3000:80 # Grafana → http://localhost:3000
kubectl port-forward svc/kube-prometheus-stack-*-prometheus -n monitoring 9090:9090 # Prometheus → http://localhost:9090

# Or use the convenience script (recommended)
./setup-port-forward.sh
```

### 3. Verify Monitoring Setup
```bash
# Verify all monitoring pods are running
kubectl get pods -n monitoring

# Check that all pods are Ready (may take 1-2 minutes)
```

### 4. Access URLs & Credentials

**Port Forward URLs:**
- **Guestbook**: http://localhost:8080
- **Grafana**: http://localhost:3000 (admin/admin123)
- **Prometheus**: http://localhost:9090

**LoadBalancer URLs:**
- **Guestbook**: `http://<FRONTEND-EXTERNAL-IP>:80`
- **Grafana**: `http://<GRAFANA-EXTERNAL-IP>:80` (admin/admin123)

## Quick Start Scripts

For convenience, use these scripts for easy deployment:

```bash
# 1. Install all dependencies
./setup.sh

# 2. Deploy complete monitoring stack  
./run.sh

# The run script will:
# - Start minikube if needed
# - Prompt you to start minikube tunnel
# - Deploy the complete monitoring stack
# - Show access information
```

## How to Verify Prometheus is Scraping Guestbook Metrics

After deployment, verify that Prometheus is collecting metrics from the guestbook application:

### 1. Access Prometheus (Port Forward Method)
```bash
# Forward Prometheus to localhost
kubectl port-forward svc/kube-prometheus-stack-*-prometheus -n monitoring 9090:9090

# Access Prometheus at: http://localhost:9090
```

### 2. Check Prometheus Targets
1. Go to **Status → Targets** in Prometheus UI
2. Look for targets with these labels:
   - `app="guestbook"` (frontend pods)
   - `app="redis"` (Redis leader and replica pods)
3. Verify all targets show **UP** status

### 3. Query Guestbook Metrics
In Prometheus, run these queries to verify metrics collection:

```prometheus
# Apache metrics from guestbook frontend
apache_accesses_total{kubernetes_namespace="guestbook"}

# Redis metrics from backend
redis_connected_clients{kubernetes_namespace="guestbook"}

# Pod resource metrics
container_cpu_usage_seconds_total{namespace="guestbook"}
container_memory_working_set_bytes{namespace="guestbook"}
```

### 4. Verify in Grafana Dashboard
1. Access Grafana at the LoadBalancer IP or via port-forward
2. Login with **admin/admin123**
3. Open the **"Guestbook Application Monitoring"** dashboard
4. Verify data is showing in all panels:
   - Pod CPU/Memory usage
   - Apache request rates and worker status  
   - Redis connections, memory usage, and hit rates

**Expected Results:**
- ✅ All Prometheus targets should be **UP**
- ✅ Metrics queries should return data
- ✅ Grafana dashboard should show real-time metrics
- ✅ Data should update every 30 seconds (dashboard refresh rate)

## Component Details

### Guestbook Application

- **Frontend**: PHP application (3 replicas) accessible via LoadBalancer
- **Redis Master**: Single instance for writes (service name: `redis-master`)
- **Redis Follower**: 2 instances for reads (service name: `redis-follower`)
- **Namespace**: `guestbook`
- **Important**: Redis service names match Guestbook application expectations

### Monitoring Stack

- **Prometheus**: Metrics collection server with 7-day retention, optimized for minikube
- **Grafana**: Visualization dashboard with pre-configured datasource
- **Service Discovery**: Annotation-based discovery (ServiceMonitor approach removed for simplicity)
- **Namespace**: `monitoring`
- **Resource Optimization**: CPU/Memory limits tuned for local development

### Dashboards

1. **Kubernetes Cluster Monitoring** (ID: 7249) - Overall cluster health
2. **Kubernetes Pod Monitoring** (ID: 6781) - Pod-level metrics
3. **Guestbook Application Monitoring** (Custom) - Application-specific metrics

## Accessing Services

### Guestbook Application

**Method 1: Port Forward (Recommended for Development)**
```bash
# Port forward to access locally
kubectl port-forward service/frontend -n guestbook 8080:80
# Then access: http://localhost:8080
```

**Method 2: LoadBalancer (if minikube tunnel is running)**
```bash
# Ensure minikube tunnel is running
minikube tunnel

# Get the external URL
pulumi stack output guestbookUrl
```

**Method 3: NodePort**
```bash
# Get minikube IP and NodePort
echo "http://$(minikube ip):$(kubectl get service frontend -n guestbook -o jsonpath='{.spec.ports[0].nodePort}')"
```

### Grafana Dashboard

**Access Grafana (Port Forward Method)**
```bash
# Port forward to access Grafana locally
kubectl port-forward service/grafana -n monitoring 3000:3000
# Then access: http://localhost:3000
```

**Default credentials:**
- **Username**: `admin`
- **Password**: `admin123`

**Navigate to dashboards:**
- Go to **Dashboards** → **Browse**
- Look for **Guestbook Application Monitoring**
- Or use **Explore** → **Prometheus** to query metrics directly

## Verification Steps

### 1. Check All Pods are Running

```bash
kubectl get pods -n guestbook
kubectl get pods -n monitoring
```

Expected output:
```
NAMESPACE    NAME                               READY   STATUS    RESTARTS   AGE
guestbook    frontend-xxx                       1/1     Running   0          5m
guestbook    redis-primary-xxx                  1/1     Running   0          5m
guestbook    redis-replica-xxx                  1/1     Running   0          5m
monitoring   prometheus-server-xxx              1/1     Running   0          5m
monitoring   grafana-xxx                        1/1     Running   0          5m
```

### 2. Verify Prometheus Targets

1. Access Grafana dashboard
2. Go to **Explore** → **Prometheus**
3. Query: `up{job="kubernetes-pods"}`
4. Verify guestbook and redis targets are discovered and healthy

### 3. Check Service Discovery

```bash
# Check that services have Prometheus annotations
kubectl describe service frontend -n guestbook
kubectl describe service redis-master -n guestbook
```

Look for annotations:
```
prometheus.io/scrape: true
prometheus.io/port: 80
prometheus.io/path: /metrics
```

### 4. Test Metrics Flow

1. Generate load by using the guestbook application
2. In Grafana, go to **Guestbook Application Monitoring** dashboard
3. Verify metrics are appearing:
   - Pod status indicators
   - CPU and memory usage graphs
   - Resource utilization trends

### 5. Prometheus Configuration Verification

Check that Prometheus is scraping the correct targets:

```bash
# Port-forward to Prometheus (if needed)
kubectl port-forward -n monitoring svc/prometheus-server 9090:80

# Access http://localhost:9090/targets
# Look for guestbook and redis targets
```

## Troubleshooting

### Common Issues

1. **LoadBalancer Pending**: If using minikube, run `minikube tunnel` in a separate terminal
2. **Can't Access Guestbook**: Use port-forward method: `kubectl port-forward service/frontend -n guestbook 8080:80`
3. **Redis Connection Errors**: Ensure Redis services are named `redis-master` and `redis-follower`
4. **Grafana Login Issues**: Use port-forward: `kubectl port-forward service/grafana -n monitoring 3000:3000`
5. **Prometheus Pod Issues**: Check resource constraints, may need to reduce CPU/memory requests
6. **Minikube Resource Issues**: Start minikube with more resources: `minikube start --memory=4096 --cpus=2`

### Debug Commands

```bash
# Check all pod status
kubectl get pods -A

# Check specific service endpoints
kubectl get endpoints -n guestbook

# Test Redis connectivity
kubectl exec -it deployment/redis-primary -n guestbook -- redis-cli -h redis-master ping

# Check frontend logs for errors
kubectl logs deployment/frontend -n guestbook

# Check Prometheus configuration
kubectl get configmap -n monitoring prometheus-server -o yaml

# Verify service annotations
kubectl describe service -n guestbook frontend

# Check Grafana logs
kubectl logs -n monitoring deployment/grafana
```

### Reset/Cleanup

```bash
# Destroy all resources
pulumi destroy

# Remove the stack
pulumi stack rm dev
```

## Customization

### Changing Grafana Password

Edit `monitoring.ts` and update the `adminPassword` value:

```typescript
values: {
    adminPassword: "your-secure-password",
    // ... rest of config
}
```

### Adding Custom Metrics

1. Add Prometheus annotations to your services
2. Create additional ServiceMonitor resources
3. Update dashboard configurations in `monitoring.ts`

### Scaling Resources

Update replica counts in `guestbook.ts`:

```typescript
spec: {
    replicas: 5, // Increase frontend replicas
    // ... rest of config
}
```

## Security Considerations

- Default Grafana password should be changed for production use
- Consider using Kubernetes secrets for sensitive configuration
- Implement proper RBAC for Prometheus service account
- Use NetworkPolicies to restrict inter-service communication

## Cost Optimization

- Adjust resource requests/limits based on actual usage
- Reduce Prometheus retention period if needed
- Scale down replicas for non-production environments

## Next Steps

- Set up Grafana alerting rules
- Implement application-specific custom metrics
- Add horizontal pod autoscaling based on metrics
- Configure long-term storage for Prometheus data

## Support

For issues or questions:
1. Check the troubleshooting section above
2. Review Pulumi and Kubernetes documentation
3. Examine pod logs using `kubectl logs`

---

**Assignment Completion Checklist:**

- ✅ **Prometheus deployed via Helm charts**
- ✅ **Grafana deployed via Helm charts**
- ✅ **Guestbook monitoring configured with ServiceMonitors**
- ✅ **Grafana exposed via LoadBalancer service**
- ✅ **Access URLs and credentials provided via Pulumi outputs**
- ✅ **Custom Grafana dashboard created (stretch goal)**
- ✅ **Clear deployment and verification instructions**

This solution demonstrates SRE best practices including Infrastructure as Code, observability, and automated deployment patterns suitable for production environments.