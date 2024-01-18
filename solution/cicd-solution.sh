#!/usr/bin/env bash

# It is assumed this script is invoked from repository root e.g. `./solution/cicd-solution.sh`

# Microservices code is build through GitHub Actions and container images are pushed to Docker Hub

# Bootstrap kind cluster
kind create cluster --config solution/kind-config.yaml
# Deploy Nginx Ingress Controller
kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/main/deploy/static/provider/kind/deploy.yaml

# Deploy ArgoCD
helm repo add argo https://argoproj.github.io/argo-helm
helm install --create-namespace --namespace argocd  argpcd argo/argo-cd --atomic --values <(cat <<EOF
configs:
  cm:
    resource.customizations: |
      argoproj.io/Application:
        health.lua: |
          hs = {}
          hs.status = "Progressing"
          hs.message = ""
          if obj.status ~= nil then
            if obj.status.health ~= nil then
              hs.status = obj.status.health.status
              if obj.status.health.message ~= nil then
                hs.message = obj.status.health.message
              end
            end
          end
          return hs
EOF
)
# Sleep for a while to start port forwarding and login to WebUI
sleep 30
# Deploy the Application Stack via ArgoCD
kubectl apply -f ./solution/root.yaml
