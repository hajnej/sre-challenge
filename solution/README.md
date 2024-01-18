# sre-challenege solution



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

### Use GitHub Actions to build the jars, container images and push them to dockerhub (

GitHub Actions workflow is stored in `.github/workflows/build.yml`

### Bootstrap kind cluster, deploy ArgoCD to deploy application declaratively

