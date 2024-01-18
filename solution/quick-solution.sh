#!/usr/bin/env bash

# It is assumed this script is invoked from repository root e.g. `./solution/quick-solution.sh`

# Build all microservices
./gradlew clean build
MICROSERVICES="back front reader"

# I guess there is a better way to do this, but I don't know it
APP_VERSION=$(grep '^version' build.gradle | cut -f3 -d' ' | tr -d '"')
for microservice in ${MICROSERVICES}; do
  docker buildx build -f "app/${microservice}/src/main/docker/Dockerfile" -t "${microservice}:${APP_VERSION}" "app/${microservice}/build/libs/"
done

# Bootstrap kind cluster
kind create cluster --config solution/kind-config.yaml
# Deploy Nginx Ingress Controller
kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/main/deploy/static/provider/kind/deploy.yaml
# Load images to kind cluster
for microservice in ${MICROSERVICES}; do
  kind load  docker-image "${microservice}:${APP_VERSION}"
done
# Deploy PostgreSQL, stick with default Helm chart values
helm install --create-namespace -n demo-postgres --atomic postgres oci://registry-1.docker.io/bitnamicharts/postgresql --values ./solution/helm/values/helm-values-postgres.yaml
# Deploy Kafka, stick with default Helm chart values
helm install --create-namespace -n demo-kafka --atomic kafka oci://registry-1.docker.io/bitnamicharts/kafka --values ./solution/helm/values/helm-values-kafka.yaml
# Deploy microservices
for microservice in ${MICROSERVICES}; do
  helm install --create-namespace -n demo-${microservice} --atomic ${microservice} ./solution/helm/charts/${microservice} --values ./solution/helm/values/helm-values-${microservice}.yaml
done

# Generate certificates for Ingress
openssl req -subj '/CN=hajnej/O=hajnej/C=CZ' -new -newkey rsa:4096 -sha512 -days 365 -nodes -x509 -keyout server.key -out server.crt
for ns in demo-front demo-reader; do
  kubectl create secret tls tls-cert --key server.key --cert server.crt -n ${ns}
done

# Cleanup
rm server.key server.crt

# Print some info message how to access the exposed API
printf "You can now access exposed APIs on https://front.127.0.0.1.nip.io/swagger-ui.html or https://reader.127.0.0.1.nip.io/swagger-ui.html. Please bear in mind self-signed certifiate is used for TLS termination."
