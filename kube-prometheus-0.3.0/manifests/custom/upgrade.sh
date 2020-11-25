#!/bin/sh

# deploy kubernetes service
kubectl apply -f prometheus-kubeControllerManagerService.yaml
kubectl apply -f prometheus-kubeSchedulerService.yaml

# upgrade alertmanager configuration
kubectl create secret generic alertmanager-main --from-file=alertmanager.yaml -n monitoring --dry-run -oyaml > alertmanager-secret.yaml
kubectl apply -f alertmanager-secret.yaml

# upgrade scrape configs
kubectl create secret generic additional-scrape-configs --from-file=prometheus-additional.yaml -n monitoring --dry-run -oyaml > additional-scrape-configs.yaml
kubectl apply -f additional-scrape-configs.yaml

# upgrade prometheus rules
kubectl apply -f prometheus-additional-rules.yaml
kubectl apply -f prometheus-rules.yaml

# upgrade prometheus configuration
kubectl apply -f prometheus-prometheus.yaml

# upgrade grafana configuration
kubectl apply -f grafana-deployment.yaml