# sre-challenege solution

solution directory layout:

```
solution/
├── README.md
├── argocd-apps          # Directory with ArgoCD Application manifests
│   ├── back-app.yaml
│   ├── front-app.yaml
│   ├── kafka-app.yaml
│   ├── postgres-app.yaml
│   └── reader-app.yaml
├── cicd-solution.sh     # Bash script that bootstraps kind cluster and deploy ArgoCD to deploy sre-challenge apps and its dependencies declaratively
├── helm                 # Directory with Helm related files and directories
│   ├── charts           # Directory with Helm Charts for back, front and reader microservice 
│   │   ├── back
│   │   │   ├── Chart.yaml
│   │   │   ├── templates
│   │   │   │   ├── NOTES.txt
│   │   │   │   ├── _helpers.tpl
│   │   │   │   ├── deployment.yaml
│   │   │   │   ├── hpa.yaml
│   │   │   │   ├── ingress.yaml
│   │   │   │   ├── service.yaml
│   │   │   │   └── serviceaccount.yaml
│   │   │   └── values.yaml
│   │   ├── front
│   │   │   ├── Chart.yaml
│   │   │   ├── templates
│   │   │   │   ├── NOTES.txt
│   │   │   │   ├── _helpers.tpl
│   │   │   │   ├── deployment.yaml
│   │   │   │   ├── hpa.yaml
│   │   │   │   ├── ingress.yaml
│   │   │   │   ├── service.yaml
│   │   │   │   └── serviceaccount.yaml
│   │   │   └── values.yaml
│   │   └── reader
│   │       ├── Chart.yaml
│   │       ├── templates
│   │       │   ├── NOTES.txt
│   │       │   ├── _helpers.tpl
│   │       │   ├── deployment.yaml
│   │       │   ├── hpa.yaml
│   │       │   ├── ingress.yaml
│   │       │   ├── service.yaml
│   │       │   └── serviceaccount.yaml
│   │       └── values.yaml
│   └── values                             # Helm Chart values for sre-challenge microservices + Kafka and PostgreSQL
│       ├── helm-values-back.yaml
│       ├── helm-values-front.yaml
│       ├── helm-values-kafka.yaml
│       ├── helm-values-postgres.yaml
│       └── helm-values-reader.yaml
├── kind-config.yaml                       # Configuration for KIND cluster, necessary for Nginx Ingress Controller 
├── quick-solution.sh                      # Bash script that bootstraps kind cluster and deploy sre-challenge apps and its dependencies imperatively
└── root.yaml                              # A root ArgoCD Application that creates sre-challenge ArgoCD applications to use app-of-apps pattern
```

## Code Build & Docker build

It is assumed that all these commands are run from the root of the project.

```bash
./gradlew clean build
MICROSERVICES="back front reader"

# I guess there is a better way to do this, but I don't know it
APP_VERSION=$(grep '^version' build.gradle | cut -f3 -d' ' | tr -d '"')
for microservice in ${MICROSERVICES}; do
  docker buildx build -f "app/${microservice}/src/main/docker/Dockerfile" -t "${microservice}:${APP_VERSION}" "app/${microservice}/build/libs/"
done
```

## Helm Charts

Creating the Helm charts skelet is pretty easy via `helm create`

```bash
MICROSERVICES="back front reader"
mkdir -p solution/helm/charts
for microservice in ${MICROSERVICES}; do
  helm create "helm/${microservice}"
done
```

*Notable changes to default Helm Charts skelet files:*

* `deployment.yaml`

Add block to support passing environment variables from Helm values, add http-health port, change the livenessProbe, readinessProbe to match application health check API endpoint

```yaml
...
    env:
      {{- toYaml .Values.extraEnv | nindent 12 }}
    {{- end }}
    ports:
      - name: http
        containerPort: {{ .Values.service.port }}
        protocol: TCP
      - name: http-health
        containerPort: 8081
        protocol: TCP
    livenessProbe:
      httpGet:
        path: /health
        port: http-health
    readinessProbe:
      httpGet:
        path: /health
        port: http-health
...
```

* `values.yaml`

Add default value for `extraEnv` Helm value.

```yaml
...
extraEnv: []
...
```

*Helm values*

`solution/helm/values` directory contains all Helm values files that are used to configure the sre-challenge microservices as well as it dependencies => Kafka, PostgreSQL. I decided to use environment variables
to configure the sre-challenge microservices because I follow [12factor app](https://12factor.net) methodology, especially [Store config in the environment](https://12factor.net/config)

## Quick solution => script to build code, container image, boostrap kind cluster and deploy the application including the dependencies

Invoke `solution/quick-solution.sh` to build jars, container images, bootstrap [kind](https://kind.sigs.k8s.io/) cluster and deploy applications

## CICD solution

### Use GitHub Actions to build the jars, container images and push them to dockerhub

GitHub Actions workflow is stored in `.github/workflows/build.yml`, it builds the code, build multiplatform image for linux/amd64 and linux/arm64 and push it into dockerhub.

### Bootstrap kind cluster, deploy ArgoCD to deploy application declaratively

Run `./solution/cicd-solution.sh` to bootstrap ArgoCD and create a 'root' ArgoCD application that in turn creates ArgoCD applications for front, back, reader, kafka and postgres.
Due app-of-apps pattern and sync-waves the dependencies are created first and the sre-challenge microservices are deployed after kafka and postgres applications are ready.

## Cleanup

The simplest way how to cleanup the stuff deployed on KIND cluster is to tear it down.

```bash
kind delete cluster
```

## Further ideas

* Kafka can be deployed via [Strimzi Kubernetes Operator](https://strimzi.io/) Kubernetes Operator
* PostgreSQL can be deployed via [Crunchy PosgreSQL Operator](https://access.crunchydata.com/documentation/postgres-operator/latest)
* Secret Management is not addresses one simple solution could be [Sealed Secrets](https://github.com/bitnami-labs/sealed-secrets)
* Certificate for Ingress can be created either via `openssl` or even better use [cert-manager](https://cert-manager.io/) Kubernetes addon
* Helm Charts can be packaged and pushed to Helm Chart repository leveraging e.g. GitHub
