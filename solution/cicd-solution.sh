#!/usr/bin/env bash

# It is assumed this script is invoked from repository root e.g. `./solution/cicd-solution.sh`

# Microservices code is build through GitHub Actions and container images are pushed to Docker Hub

# Bootstrap kind cluster
kind create cluster --config solution/kind-config.yaml
# Deploy Nginx Ingress Controller
kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/main/deploy/static/provider/kind/deploy.yaml

# Deploy ArgoCD
helm repo add argo https://argoproj.github.io/argo-helm
helm install --create-namespace --namespace argocd argo/argo-cd
