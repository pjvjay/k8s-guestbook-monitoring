// Copyright 2016-2025, Pulumi Corporation.  All rights reserved.

import * as k8s from "@pulumi/kubernetes";
import * as k8stypes from "@pulumi/kubernetes/types/input";
import * as pulumi from "@pulumi/pulumi";
import * as dashboardConfig from "./guestbook-dashboard.json";

/**
 * ServiceDeployment is an example abstraction that uses a class to fold together the common pattern of a
 * Kubernetes Deployment and its associated Service object, with built-in Prometheus monitoring support.
 */
export class ServiceDeployment extends pulumi.ComponentResource {
    public readonly deployment: k8s.apps.v1.Deployment;
    public readonly service: k8s.core.v1.Service;
    public readonly ipAddress?: pulumi.Output<string>;

    constructor(name: string, args: ServiceDeploymentArgs, opts?: pulumi.ComponentResourceOptions) {
        super("k8sjs:service:ServiceDeployment", name, {}, opts);

        const labels: { [key: string]: string } = { 
            app: args.app || name,
            tier: args.tier || "backend"
        };
        
        if (args.role) {
            labels.role = args.role;
        }

        // Build Prometheus annotations if monitoring is enabled
        const annotations: { [key: string]: string } = {};
        if (args.enableMonitoring) {
            annotations["prometheus.io/scrape"] = "true";
            // Use metrics port based on enabled exporter: Redis (9121), Apache (9117), or main port
            let metricsPort: string;
            if (args.enableRedisExporter) {
                metricsPort = "9121";
            } else if (args.enableApacheExporter) {
                metricsPort = "9117";  
            } else {
                metricsPort = (args.ports?.[0] || 80).toString();
            }
            annotations["prometheus.io/port"] = metricsPort;
            annotations["prometheus.io/path"] = args.metricsPath || "/metrics";
        }

        const container: k8stypes.core.v1.Container = {
            name: args.containerName || name,
            image: args.image,
            resources: args.resources || { requests: { cpu: "100m", memory: "100Mi" } },
            env: args.env || [{ name: "GET_HOSTS_FROM", value: "dns" }],
            ports: args.ports && args.ports.map(p => ({ containerPort: p })),
            command: args.command,
        };

        // Build containers array - main app + optional exporter sidecar
        const containers: k8stypes.core.v1.Container[] = [container];
        
        // Add Apache exporter sidecar if enabled
        if (args.enableApacheExporter) {
            containers.push({
                name: "apache-exporter",
                image: "solsson/prometheus-exporter-apache:latest",
                ports: [{ containerPort: 9117, name: "metrics" }],
                env: [
                    { name: "APACHE_STATUS_URL", value: "http://localhost/server-status?auto" },
                    { name: "LISTEN_ADDRESS", value: "0.0.0.0:9117" },
                ],
                resources: { requests: { cpu: "10m", memory: "20Mi" } },
            });
        }

        // Add Redis exporter sidecar if enabled
        if (args.enableRedisExporter) {
            containers.push({
                name: "redis-exporter",
                image: "oliver006/redis_exporter:latest",
                ports: [{ containerPort: 9121, name: "redis-metrics" }],
                env: [
                    { name: "REDIS_ADDR", value: "redis://localhost:6379" },
                    { name: "REDIS_EXPORTER_WEB_LISTEN_ADDRESS", value: "0.0.0.0:9121" },
                ],
                resources: { requests: { cpu: "10m", memory: "20Mi" } },
            });
        }

        this.deployment = new k8s.apps.v1.Deployment(name, {
            metadata: {
                name: name,
                namespace: args.namespace,
            },
            spec: {
                selector: { matchLabels: labels },
                replicas: args.replicas || 1,
                template: {
                    metadata: { 
                        labels: labels,
                        annotations: annotations,
                    },
                    spec: { containers: containers },
                },
            },
        }, { parent: this });

        this.service = new k8s.core.v1.Service(name, {
            metadata: {
                name: name,
                namespace: args.namespace,
                labels: labels,
                annotations: args.enableMonitoring ? annotations : undefined,
            },
            spec: {
                ports: args.ports && args.ports.map((p, index) => ({
                    name: index === 0 ? "web" : `port-${p}`,
                    port: p, 
                    targetPort: p
                })).concat(
                    args.enableApacheExporter ? [{
                        name: "metrics",
                        port: 9117,
                        targetPort: 9117
                    }] : []
                ).concat(
                    args.enableRedisExporter ? [{
                        name: "redis-metrics",
                        port: 9121,
                        targetPort: 9121
                    }] : []
                ),
                selector: labels,
                type: "LoadBalancer",
            },
        }, { parent: this });

        if (args.allocateIpAddress) {
            this.ipAddress = args.isMinikube ?
                this.service.spec.clusterIP :
                this.service.status.loadBalancer.ingress[0].ip;
        }

    }
}

export interface ServiceDeploymentArgs {
    image: string;
    app?: string;
    role?: string;
    tier?: string;
    containerName?: string;
    resources?: k8stypes.core.v1.ResourceRequirements;
    replicas?: number;
    ports?: number[];
    env?: k8stypes.core.v1.EnvVar[];
    command?: string[];
    namespace?: pulumi.Input<string>;
    allocateIpAddress?: boolean;
    isMinikube?: boolean;
    enableMonitoring?: boolean;
    metricsPath?: string;
    enableApacheExporter?: boolean;
    enableRedisExporter?: boolean;
}

/**
 * MonitoringStack creates a complete Prometheus and Grafana monitoring setup
 */
export class MonitoringStack extends pulumi.ComponentResource {
    public readonly kubePrometheusStack: k8s.helm.v3.Release;

    constructor(name: string, args: MonitoringStackArgs, opts?: pulumi.ComponentResourceOptions) {
        super("k8sjs:monitoring:MonitoringStack", name, {}, opts);

        // Deploy kube-prometheus-stack with custom configuration for our sidecars
        this.kubePrometheusStack = new k8s.helm.v3.Release("kube-prometheus-stack", {
            chart: "kube-prometheus-stack",
            version: "67.2.0",
            repositoryOpts: {
                repo: "https://prometheus-community.github.io/helm-charts",
            },
            namespace: args.namespace,
            values: {
                // Prometheus configuration
                prometheus: {
                    prometheusSpec: {
                        // Add custom scrape config to preserve our existing sidecar metrics
                        additionalScrapeConfigs: [
                            {
                                job_name: "kubernetes-pods",
                                kubernetes_sd_configs: [{ role: "pod" }],
                                relabel_configs: [
                                    {
                                        source_labels: ["__meta_kubernetes_pod_annotation_prometheus_io_scrape"],
                                        action: "keep",
                                        regex: true
                                    },
                                    {
                                        source_labels: ["__meta_kubernetes_pod_annotation_prometheus_io_path"],
                                        action: "replace",
                                        target_label: "__metrics_path__",
                                        regex: "(.+)"
                                    },
                                    {
                                        source_labels: ["__address__", "__meta_kubernetes_pod_annotation_prometheus_io_port"],
                                        action: "replace",
                                        regex: "([^:]+)(?::\\d+)?;(\\d+)",
                                        replacement: "$1:$2",
                                        target_label: "__address__"
                                    },
                                    {
                                        action: "labelmap",
                                        regex: "__meta_kubernetes_pod_label_(.+)"
                                    },
                                    {
                                        source_labels: ["__meta_kubernetes_namespace"],
                                        action: "replace",
                                        target_label: "kubernetes_namespace"
                                    },
                                    {
                                        source_labels: ["__meta_kubernetes_pod_name"],
                                        action: "replace",
                                        target_label: "kubernetes_pod_name"
                                    }
                                ]
                            }
                        ]
                    }
                },
                // Grafana configuration
                grafana: {
                    adminPassword: args.adminPassword || "admin123",
                    service: {
                        type: "LoadBalancer",
                        port: 80
                    },
                    dashboardProviders: {
                        "dashboardproviders.yaml": {
                            apiVersion: 1,
                            providers: [
                                {
                                    name: "guestbook",
                                    orgId: 1,
                                    folder: "Guestbook",
                                    type: "file",
                                    disableDeletion: false,
                                    editable: true,
                                    options: {
                                        path: "/var/lib/grafana/dashboards/guestbook"
                                    }
                                }
                            ]
                        }
                    },
                    dashboards: {
                        guestbook: {
                            "guestbook-dashboard": {
                                json: JSON.stringify(dashboardConfig)
                            }
                        }
                    }
                }
            }
        }, { parent: this });
    }
}

export interface MonitoringStackArgs {
    namespace?: pulumi.Input<string>;
    adminPassword?: string;
}
