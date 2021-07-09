#!/bin/bash

echo "============================== Deploy prometheus monitoring =============================="
if [ -f kube-prometheus-images.tgz ]; then
  echo ">>> Loading prometheus images"
  docker load -i kube-prometheus-images.tgz
fi

echo ">>> Add label app=prometheus"
kubectl label node $(kubectl get nodes | grep master | awk '{print $1}') app=prometheus
mkdir -p /data/grafana && chmod 777 /data/grafana
mkdir -p /data/prometheus && chmod 777 /data/prometheus

echo ">>> Applying prometheus yaml"
kubectl apply -f manifests/setup
until kubectl get servicemonitors -A; do
  echo "waiting prometheus-operator ready..." && sleep 5
done
kubectl apply -f manifests

echo ">>> Check pod status..."
while kubectl -n monitoring get pod | grep -vE 'STATUS|Running'; do
  echo "waiting pod ready..." && sleep 5
done
echo "Prometheus deployed successfully!"