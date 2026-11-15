// Copyright 2016-2025, Pulumi Corporation.  All rights reserved.

import * as k8sjs from "./k8sjs";
import * as k8s from "@pulumi/kubernetes";
import * as pulumi from "@pulumi/pulumi";

const config = new pulumi.Config();
const useLoadBalancer = config.getBoolean("useLoadBalancer");

// Create namespaces
const guestbookNamespace = new k8s.core.v1.Namespace("guestbook", {
    metadata: {
        name: "guestbook",
        labels: { name: "guestbook" }
    }
});

const monitoringNamespace = new k8s.core.v1.Namespace("monitoring", {
    metadata: {
        name: "monitoring",
        labels: { name: "monitoring" }
    }
});

// Redis Leader - Standard Redis with Redis exporter sidecar
const redisLeader = new k8sjs.ServiceDeployment("redis-leader", {
    image: "redis:6.0",
    app: "redis",
    role: "leader", 
    tier: "backend",
    containerName: "leader",
    ports: [6379],
    namespace: guestbookNamespace.metadata.name,
    enableMonitoring: true,         // Enable Prometheus metrics scraping from Redis exporter
    enableRedisExporter: true,      // Add Redis exporter sidecar
    metricsPath: "/metrics",        // Redis exporter exposes metrics at /metrics
});

// Redis Replica - Standard Redis with Redis exporter sidecar
const redisReplica = new k8sjs.ServiceDeployment("redis-replica", {
    image: "pulumi/guestbook-redis-replica",
    app: "redis",
    role: "replica",
    tier: "backend", 
    containerName: "replica",
    ports: [6379],
    replicas: 2,
    namespace: guestbookNamespace.metadata.name,
    enableMonitoring: true,         // Enable Prometheus metrics scraping from Redis exporter
    enableRedisExporter: true,      // Add Redis exporter sidecar
    metricsPath: "/metrics",        // Redis exporter exposes metrics at /metrics
});

// Frontend - Using Pulumi image with Apache exporter for metrics
const frontend = new k8sjs.ServiceDeployment("frontend", {
    image: "pulumi/guestbook-php-redis", 
    app: "guestbook",
    tier: "frontend",
    containerName: "php-redis",
    replicas: 3,
    ports: [80],
    namespace: guestbookNamespace.metadata.name,
    allocateIpAddress: true,
    isMinikube: config.getBoolean("isMinikube") || true,
    enableMonitoring: true,          // Enable annotations for Prometheus scraping
    enableApacheExporter: true,      // Enable Apache exporter sidecar
    metricsPath: "/metrics",
});

// Monitoring Stack - kube-prometheus-stack with custom scraping for our sidecars
const monitoring = new k8sjs.MonitoringStack("monitoring", {
    namespace: monitoringNamespace.metadata.name,
    adminPassword: "temptestpass"
});

// Exports
export const frontendIp = frontend.ipAddress;

export const guestbookUrl = frontend.ipAddress 
    ? frontend.ipAddress.apply(ip => `http://${ip}`)
    : pulumi.output("Use port-forward: kubectl port-forward service/frontend -n guestbook 8080:80");

export const grafanaUrl = pulumi.output("http://localhost:3000");

export const grafanaCredentials = {
    username: "admin",
    password: "temptestpass"
};

export const namespaces = {
    guestbook: guestbookNamespace.metadata.name,
    monitoring: monitoringNamespace.metadata.name
};
